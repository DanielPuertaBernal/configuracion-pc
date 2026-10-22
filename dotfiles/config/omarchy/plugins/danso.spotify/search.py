#!/usr/bin/env python3
"""Keyless Spotify search helper for the danso.spotify panel.

  search.py search <query>                       -> JSON array of {id, title, artist, cover}
  search.py play <deezer-id> <title> <artist>    -> plays that track in the running Spotify app
  search.py restore <state-json>                 -> internal: undo Spotify's window activation

Listings come from Deezer's public API. To play, the exact Spotify track id is resolved
without API keys, in order:
  1. Deezer ISRC -> MusicBrainz recording -> its Spotify track link, or a Spotify album
     link on one of its releases -> that album's embed track list
  2. a public web search (Brave), checked against each candidate's Spotify embed page
If nothing matches, Spotify's own search opens for "title artist".
The Spotify window's self-activation on OpenUri is undone, so focus stays where it was.
`play` prints "track" or "search".
"""
import concurrent.futures
import json
import os
import re
import subprocess
import sys
import time
import unicodedata
import urllib.parse

LIMIT = 6
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
MB_UA = "danso-spotify-panel/1.0 (omarchy shell plugin)"
TRACK_RE = re.compile(r"open\.spotify\.com/track/([A-Za-z0-9]{22})")
ALBUM_RE = re.compile(r"open\.spotify\.com/album/([A-Za-z0-9]{22})")
NEXT_DATA_RE = re.compile(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', re.S)


def fetch(url, timeout=8, ua=UA):
    # curl instead of urllib: Brave answers urllib's request fingerprint with HTTP 429.
    result = subprocess.run(
        ["curl", "-sSL", "--compressed", "-m", str(timeout), "-A", ua, url],
        capture_output=True, text=True,
    )
    return result.stdout if result.returncode == 0 else ""


def fetch_json(url, ua=UA):
    try:
        return json.loads(fetch(url, ua=ua))
    except ValueError:
        return {}


def normalize(text):
    text = unicodedata.normalize("NFKD", text.lower())
    return " ".join("".join(c if c.isalnum() else " " for c in text if not unicodedata.combining(c)).split())


def search(query):
    rows = fetch_json("https://api.deezer.com/search?limit=%d&q=%s" % (LIMIT * 2, urllib.parse.quote(query))).get("data", [])
    items, seen = [], set()
    for row in rows:
        item = {
            "id": str(row.get("id", "")),
            "title": row.get("title", ""),
            "artist": row.get("artist", {}).get("name", ""),
            "cover": row.get("album", {}).get("cover_small", ""),
        }
        key = (normalize(item["title"]), normalize(item["artist"]))
        if item["title"] and key not in seen:
            seen.add(key)
            items.append(item)
    return items[:LIMIT]


EXACT, PARTIAL = 2, 1


def matches(want_title, want_artist, title, artists, playable=True):
    """EXACT for the same title and artist, PARTIAL when one title extends the other
    (e.g. "Obsesion" vs "Obsesion - Live"), 0 otherwise or when the track is unplayable."""
    if playable is False or not any(want_artist and want_artist in normalize(a) for a in artists):
        return 0
    title = normalize(title)
    if title == want_title:
        return EXACT
    return PARTIAL if title.startswith(want_title) or want_title.startswith(title) else 0


def entity_match(want_title, want_artist, entity):
    if not entity:
        return 0
    return matches(want_title, want_artist, entity.get("name") or entity.get("title") or "",
                   [a.get("name", "") for a in entity.get("artists", [])], entity.get("isPlayable"))


def embed_entity(kind, sid):
    try:
        data = json.loads(NEXT_DATA_RE.search(fetch(f"https://open.spotify.com/embed/{kind}/{sid}")).group(1))
        return data["props"]["pageProps"]["state"]["data"]["entity"]
    except Exception:
        return None


def resolve_via_musicbrainz(deezer_id, want_title, want_artist):
    isrc = fetch_json(f"https://api.deezer.com/track/{deezer_id}").get("isrc") if deezer_id else None
    if not isrc:
        return None
    mb = "https://musicbrainz.org/ws/2/"
    recordings = fetch_json(f"{mb}isrc/{isrc}?inc=url-rels&fmt=json", ua=MB_UA).get("recordings", [])
    for rec in recordings:
        for rel in rec.get("relations", []):
            found = TRACK_RE.search(rel.get("url", {}).get("resource", ""))
            if found and entity_match(want_title, want_artist, embed_entity("track", found.group(1))):
                return found.group(1)
    # Release links are a slower, lower-yield path; MusicBrainz allows one request per second.
    for rec in recordings[:1]:
        time.sleep(1)
        releases = fetch_json(f"{mb}recording/{rec['id']}?inc=releases&fmt=json", ua=MB_UA).get("releases", [])
        for release in releases[:2]:
            time.sleep(1)
            rels = fetch_json(f"{mb}release/{release['id']}?inc=url-rels&fmt=json", ua=MB_UA).get("relations", [])
            for rel in rels:
                album = ALBUM_RE.search(rel.get("url", {}).get("resource", ""))
                entity = embed_entity("album", album.group(1)) if album else None
                for track in (entity or {}).get("trackList", []):
                    if matches(want_title, want_artist, track.get("title", ""), [track.get("subtitle", "")],
                               track.get("isPlayable")):
                        return track.get("uri", "").rsplit(":", 1)[-1] or None
    return None


def resolve_via_web(want_title, want_artist, title, artist):
    html = fetch("https://search.brave.com/search?q=" + urllib.parse.quote_plus(f"open.spotify.com track {title} {artist}"))
    ids = list(dict.fromkeys(TRACK_RE.findall(html)))[:8]
    pool = concurrent.futures.ThreadPoolExecutor(max_workers=8)
    futures = {pool.submit(embed_entity, "track", tid): tid for tid in ids}
    partial = None
    try:
        # Return on the first exact match instead of waiting for slow stragglers; a partial
        # match (another version of the song) is only used when no exact one turns up.
        for future in concurrent.futures.as_completed(futures):
            score = entity_match(want_title, want_artist, future.result())
            if score == EXACT:
                return futures[future]
            if score == PARTIAL and partial is None:
                partial = futures[future]
    finally:
        pool.shutdown(wait=False, cancel_futures=True)
    return partial


CACHE_PATH = os.path.expanduser("~/.local/state/danso.spotify/track-ids.json")


def load_cache():
    try:
        with open(CACHE_PATH) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_cache(cache):
    try:
        os.makedirs(os.path.dirname(CACHE_PATH), exist_ok=True)
        with open(CACHE_PATH, "w") as f:
            json.dump(cache, f)
    except OSError:
        pass


def resolve(deezer_id, title, artist, timeout=8.0):
    want_title, want_artist = normalize(title), normalize(artist)
    key = f"{want_title}|{want_artist}"
    cache = load_cache()
    if key in cache:
        return cache[key]
    # Race both resolvers and take the first hit.
    pool = concurrent.futures.ThreadPoolExecutor(max_workers=2)
    futures = [
        pool.submit(resolve_via_musicbrainz, deezer_id, want_title, want_artist),
        pool.submit(resolve_via_web, want_title, want_artist, title, artist),
    ]
    tid = None
    try:
        for future in concurrent.futures.as_completed(futures, timeout=timeout):
            tid = future.result()
            if tid:
                break
    except concurrent.futures.TimeoutError:
        pass
    finally:
        pool.shutdown(wait=False, cancel_futures=True)
    if tid:
        cache[key] = tid
        save_cache(cache)
    return tid


def open_uri(uri):
    return subprocess.run(
        ["dbus-send", "--print-reply", "--session", "--dest=org.mpris.MediaPlayer2.spotify",
         "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player.OpenUri", "string:" + uri],
        capture_output=True,
    ).returncode == 0


def hypr_json(what):
    try:
        return json.loads(subprocess.run(["hyprctl", what, "-j"], capture_output=True, text=True).stdout)
    except ValueError:
        return {}


def hypr_dispatch(lua):
    subprocess.run(["hyprctl", "dispatch", lua], capture_output=True)


def desktop_state():
    active = hypr_json("activewindow") or {}
    specials = {m.get("name"): m.get("specialWorkspace", {}).get("name", "") for m in hypr_json("monitors") or []}
    return active.get("address", ""), specials


def restore_desktop(before, watch_seconds=4.0):
    """Undo the window activation Spotify requests when it receives OpenUri.

    Spotify raises itself (showing its special workspace or switching to its workspace)
    shortly after OpenUri, and sometimes more than once, so keep watching for a moment
    and put back the previously focused window and the special workspaces that were shown.
    """
    prev_address, prev_specials = before
    deadline = time.monotonic() + watch_seconds
    while time.monotonic() < deadline:
        address, specials = desktop_state()
        for monitor, name in specials.items():
            if name and name != prev_specials.get(monitor, ""):
                hypr_dispatch('hl.dsp.workspace.toggle_special("%s")' % name.removeprefix("special:"))
        if prev_address and address != prev_address:
            hypr_dispatch('hl.dsp.focus({ window = "address:%s" })' % prev_address)
        time.sleep(0.05)


def play(deezer_id, title, artist):
    tid = resolve(deezer_id, title, artist)
    before = desktop_state()
    if tid and open_uri("spotify:track:" + tid):
        print("track", flush=True)
        # Detach the focus restore so the caller sees the result now; a fresh process keeps
        # undoing Spotify's self-activation for a few seconds in the background.
        subprocess.Popen(
            [sys.executable, "-I", os.path.abspath(__file__), "restore", json.dumps(before)],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        os._exit(0)
    # Fallback: Spotify's search needs the user to pick a result, so let its window show.
    if open_uri("spotify:search:" + urllib.parse.quote(f"{title} {artist}".strip())):
        print("search", flush=True)
        os._exit(0)
    return 1


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "search":
        print(json.dumps(search(" ".join(sys.argv[2:]).strip()), ensure_ascii=False))
        return 0
    if len(sys.argv) == 3 and sys.argv[1] == "restore":
        restore_desktop(json.loads(sys.argv[2]))
        return 0
    if len(sys.argv) >= 4 and sys.argv[1] == "play":
        return play(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "")
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
