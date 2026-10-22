# configuracion-pc

Omarchy backup: dotfiles, package lists and preferences.

## Before formatting

```bash
./backup.sh && git add -A && git commit -m "chore: update snapshot" && git push
```

## After a fresh Omarchy install

```bash
git clone https://github.com/DanielPuertaBernal/configuracion-pc.git
cd configuracion-pc && ./restore.sh
```

## Not included (do these manually)

- Browser profiles (Zen, Chromium, Brave): use the browser's own sync.
- Secrets: SSH keys, `gh auth login`, `.git-credentials`, Deskflow TLS certs, API keys.
- Binaries in `~/.local/bin` (claude, codex, opencode, etc.): reinstalled via mise/installers.
- Node via nvm: reinstall versions with `nvm install`.

## Layout

- `dotfiles/config` → `~/.config`
- `dotfiles/home` → `~`
- `dotfiles/local` → `~/.local`
- `dotfiles/claude` → `~/.claude`
- `dotfiles/etc` → `/etc`
- `packages/` → pacman, AUR, brew, VS Code, npm, systemd units
