#!/usr/bin/env bash
# Restore configs and packages on a fresh Omarchy install.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
DOT="$REPO/dotfiles"
PKG="$REPO/packages"

echo "==> Packages (pacman + AUR)"
sudo pacman -S --needed - < "$PKG/pacman.txt" || echo "Some pacman packages failed; review manually"
command -v yay >/dev/null && yay -S --needed - < "$PKG/aur.txt" || echo "Install AUR packages from $PKG/aur.txt manually"

echo "==> Dotfiles"
rsync -a "$DOT/config/" "$HOME/.config/"
rsync -a "$DOT/home/" "$HOME/"
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.claude"
rsync -a "$DOT/local/bin/" "$HOME/.local/bin/"
rsync -a "$DOT/local/share/applications/" "$HOME/.local/share/applications/"
rsync -a "$DOT/claude/" "$HOME/.claude/"
[[ -d "$DOT/etc/keyd" ]] && sudo rsync -a "$DOT/etc/keyd/" /etc/keyd/

echo "==> Extra package managers"
command -v mise >/dev/null && mise install || true
[[ -s "$PKG/flatpak.txt" ]] && command -v flatpak >/dev/null && xargs -r flatpak install -y flathub < "$PKG/flatpak.txt" || true
[[ -s "$PKG/brew.txt" ]] && command -v brew >/dev/null && xargs -r brew install < "$PKG/brew.txt" || true
[[ -s "$PKG/vscode-extensions.txt" ]] && command -v code >/dev/null && xargs -rn1 code --install-extension < "$PKG/vscode-extensions.txt" || true
[[ -s "$PKG/npm-global.txt" ]] && command -v npm >/dev/null && xargs -r npm i -g < "$PKG/npm-global.txt" || true

echo "==> User services"
systemctl --user daemon-reload
xargs -r systemctl --user enable < "$PKG/systemd-user-enabled.txt" 2>/dev/null || true

echo "Restore done. Re-login, then log into gh, browsers and re-create SSH keys."
