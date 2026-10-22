#!/usr/bin/env bash
# Snapshot configs, package lists and preferences into this repo.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
DOT="$REPO/dotfiles"
PKG="$REPO/packages"
mkdir -p "$DOT/config" "$DOT/home" "$DOT/local/bin" "$DOT/local/share/applications" "$DOT/claude" "$PKG"

RSYNC=(rsync -a --delete
  --exclude='*.bak*' --exclude='*.log' --exclude='*.tmp*'
  --exclude='Cache*' --exclude='cache*' --exclude='*Cache' --exclude='logs'
  --exclude='node_modules' --exclude='session-snapshots' --exclude='session.json'
  --exclude='hosts.yml' --exclude='*credentials*' --exclude='*token*')

# ~/.config dirs worth keeping (browser profiles, nvm, Code state and app caches excluded)
CONFIG_DIRS=(
  aether alacritty autostart btop cava environment.d fcitx5 foot gga ghostty git
  gtk-3.0 gtk-4.0 herdr hypr imv keyd kitty lazygit mise nautilus nvim omarchy
  opencode Pinta spicetify systemd tea tmux voxtype waynergy wireplumber xournalpp
  Deskflow obsidian
)
CONFIG_FILES=(
  chromium-flags.conf spotify-flags.conf mimeapps.list starship.toml
  user-dirs.dirs xdg-terminals.list
)

for d in "${CONFIG_DIRS[@]}"; do
  [[ -d "$HOME/.config/$d" ]] && "${RSYNC[@]}" "$HOME/.config/$d/" "$DOT/config/$d/"
done
for f in "${CONFIG_FILES[@]}"; do
  [[ -f "$HOME/.config/$f" ]] && cp "$HOME/.config/$f" "$DOT/config/$f"
done

# VS Code user settings only
mkdir -p "$DOT/config/Code/User"
for f in settings.json keybindings.json; do
  [[ -f "$HOME/.config/Code/User/$f" ]] && cp "$HOME/.config/Code/User/$f" "$DOT/config/Code/User/$f"
done
[[ -d "$HOME/.config/Code/User/snippets" ]] && "${RSYNC[@]}" "$HOME/.config/Code/User/snippets/" "$DOT/config/Code/User/snippets/"

# Home dotfiles
for f in .bashrc .bash_profile .bash_logout .profile .XCompose .tnsnames.ora; do
  [[ -f "$HOME/$f" ]] && cp "$HOME/$f" "$DOT/home/$f"
done

# ~/.local/bin: text scripts only (skip binaries and symlinks)
rm -rf "$DOT/local/bin" && mkdir -p "$DOT/local/bin"
for f in "$HOME"/.local/bin/*; do
  [[ -f "$f" && ! -L "$f" ]] || continue
  file -b --mime-type "$f" | rg -q '^text/' && cp -p "$f" "$DOT/local/bin/"
done
"${RSYNC[@]}" "$HOME/.local/share/applications/" "$DOT/local/share/applications/"

# Claude Code: instructions, settings, agents, skills (no sessions or credentials)
for p in CLAUDE.md settings.json keybindings.json agents skills commands output-styles hooks; do
  [[ -e "$HOME/.claude/$p" ]] && "${RSYNC[@]}" "$HOME/.claude/$p" "$DOT/claude/"
done

# Package lists
pacman -Qqen > "$PKG/pacman.txt"
pacman -Qqem > "$PKG/aur.txt"
command -v flatpak >/dev/null && flatpak list --app --columns=application > "$PKG/flatpak.txt" || true
command -v brew >/dev/null && brew leaves > "$PKG/brew.txt" || true
command -v code >/dev/null && code --list-extensions > "$PKG/vscode-extensions.txt" || true
command -v npm >/dev/null && npm ls -g --depth=0 --parseable 2>/dev/null | tail -n +2 | xargs -rn1 basename > "$PKG/npm-global.txt" || true
systemctl --user list-unit-files --state=enabled --no-legend | awk '{print $1}' > "$PKG/systemd-user-enabled.txt"
systemctl list-unit-files --state=enabled --no-legend | awk '{print $1}' > "$PKG/systemd-system-enabled.txt"
[[ -d /etc/keyd ]] && mkdir -p "$DOT/etc/keyd" && cp -r /etc/keyd/. "$DOT/etc/keyd/" 2>/dev/null || true

echo "Backup done: $REPO"
