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

# 2. Ensure a container engine is available: prefer podman, then docker.
#    If neither is found, install docker.
install_docker() {
    local os="$(uname)"
    if [ "$os" = "Darwin" ]; then
        if command -v brew >/dev/null 2>&1; then
            info "installing Docker Desktop via Homebrew..."
            brew install --cask docker
        else
            err "Homebrew not found. Install it from https://brew.sh or install Docker Desktop manually: https://docs.docker.com/desktop/install/mac-install/"
            exit 1
        fi
    elif [ "$os" = "Linux" ]; then
        info "installing docker via get.docker.com..."
        if ! command -v curl >/dev/null 2>&1; then
            err "curl is required to install docker. Install curl and re-run."
            exit 1
        fi
        local sudo_cmd=""
        [ "$(id -u)" -ne 0 ] && sudo_cmd="sudo"
        curl -fsSL https://get.docker.com | $sudo_cmd sh
        if [ -n "$sudo_cmd" ] && getent group docker >/dev/null 2>&1; then
            info "adding $USER to the 'docker' group (log out/in to take effect)"
            $sudo_cmd usermod -aG docker "$USER" || true
        fi
    else
        err "unsupported OS '$os'. Install docker or podman manually and re-run."
        exit 1
    fi
}

if command -v podman >/dev/null 2>&1; then
    info "found podman: $(command -v podman)"
elif command -v docker >/dev/null 2>&1; then
    info "found docker: $(command -v docker)"
else
    info "neither podman nor docker found — installing docker"
    install_docker
    if ! command -v docker >/dev/null 2>&1; then
        err "docker installation did not complete successfully."
        exit 1
    fi
    info "docker installed: $(command -v docker)"
fi

# 3. Pick the rc file. Prefer the file matching $SHELL; otherwise use
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

# 4. Install or update the alias idempotently.
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
