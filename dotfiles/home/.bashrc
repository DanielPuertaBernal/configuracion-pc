# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

# open: with no arguments, open the current directory in the file manager
open() {
  (xdg-open "${@:-.}" >/dev/null 2>&1 &)
}

# Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH="$HOME/.local/bin:$PATH"
. "$HOME/.cargo/env"

# Herdr TEAM layout: repaint orchestrator/operator pane backgrounds whenever a
# shell starts inside herdr (new panes, herdr restart). Runs in the background.
if [ "${HERDR_ENV:-}" = 1 ] && [ -x "$HOME/.local/bin/TEAM" ]; then
  ( sleep 1; "$HOME/.local/bin/TEAM" --colors ) >/dev/null 2>&1 &
  disown 2>/dev/null
fi

# OpenClaw Completion
[ -f '/home/danso/.openclaw/completions/openclaw.bash' ] && source '/home/danso/.openclaw/completions/openclaw.bash'
