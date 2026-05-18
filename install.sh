#!/usr/bin/env bash
# Install the 'devel' alias in your shell rc and launch the container.
# Idempotent: safe to re-run; updates the alias if the path changed.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_PATH="$SCRIPT_DIR/run.sh"
ALIAS_NAME="devel"
ALIAS_LINE="alias ${ALIAS_NAME}=\"${RUN_PATH}\""

err()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; }
info() { printf '\033[32m==>\033[0m %s\n' "$*"; }

# 1. Verify run.sh exists; make it executable if needed.
if [ ! -f "$RUN_PATH" ]; then
    err "run.sh not found next to install.sh ($RUN_PATH)"
    exit 1
fi
[ -x "$RUN_PATH" ] || chmod +x "$RUN_PATH"

# 2. Pick the rc file. Prefer the file matching $SHELL; otherwise use
#    whichever rc file exists; otherwise default by platform.
pick_rc() {
    case "$(basename "${SHELL:-}")" in
        zsh)  echo "$HOME/.zshrc"  ; return ;;
        bash) echo "$HOME/.bashrc" ; return ;;
    esac
    [ -f "$HOME/.zshrc" ]  && { echo "$HOME/.zshrc"  ; return; }
    [ -f "$HOME/.bashrc" ] && { echo "$HOME/.bashrc" ; return; }
    [ "$(uname)" = "Darwin" ] && echo "$HOME/.zshrc" || echo "$HOME/.bashrc"
}

RC="$(pick_rc)"
[ -e "$RC" ] || { info "creating $RC" ; : > "$RC"; }

# 3. Install or update the alias idempotently.
if grep -Eq "^alias[[:space:]]+${ALIAS_NAME}=" "$RC"; then
    existing="$(grep -E "^alias[[:space:]]+${ALIAS_NAME}=" "$RC" | head -1)"
    if [ "$existing" = "$ALIAS_LINE" ]; then
        info "alias '${ALIAS_NAME}' already up-to-date in $RC"
    else
        info "updating '${ALIAS_NAME}' alias in $RC"
        tmp="$(mktemp "${RC}.XXXXXX")"
        grep -Ev "^alias[[:space:]]+${ALIAS_NAME}=" "$RC" > "$tmp"
        printf '%s\n' "$ALIAS_LINE" >> "$tmp"
        mv "$tmp" "$RC"
    fi
else
    printf '\n%s\n' "$ALIAS_LINE" >> "$RC"
    info "added '${ALIAS_NAME}' alias to $RC"
fi

info "to use '${ALIAS_NAME}' in your current shell now: source $RC"
info "launching container..."
exec "$RUN_PATH" "$@"
