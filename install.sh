#!/usr/bin/env bash
# Install the 'devel' alias in your shell rc and launch the container.
# Idempotent: safe to re-run; updates the alias if the path changed.
#
# Two ways to run it:
#   ./install.sh          executes normally; the alias is ready in new shells
#   source ./install.sh   also activates the 'devel' alias in the CURRENT shell
#
# A script run normally is a child process and cannot add an alias to the
# shell that started it. Sourcing runs in the current shell, so the alias
# takes effect immediately with no need to open a new terminal.

# --- detect whether this script was sourced or executed -------------------
_devel_sourced=0
if [ -n "${BASH_VERSION:-}" ]; then
    [ "${BASH_SOURCE[0]}" != "$0" ] && _devel_sourced=1
    _devel_src="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
    case "${ZSH_EVAL_CONTEXT:-}" in *:file*) _devel_sourced=1 ;; esac
    _devel_src="$0"
else
    _devel_src="$0"
fi

# errexit is safe only when executed in a child process. Enabling it while
# sourced would abort (and leak into) the caller's interactive shell, so when
# sourced we rely on explicit error checks instead.
if [ "$_devel_sourced" -eq 0 ]; then set -e; fi

_devel_err()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; }
_devel_info() { printf '\033[32m==>\033[0m %s\n' "$*"; }

# Pick the rc file. Prefer the file matching $SHELL; otherwise use whichever
# rc file exists; otherwise default by platform.
_devel_pick_rc() {
    case "$(basename "${SHELL:-}")" in
        zsh)  echo "$HOME/.zshrc"  ; return ;;
        bash) echo "$HOME/.bashrc" ; return ;;
    esac
    [ -f "$HOME/.zshrc" ]  && { echo "$HOME/.zshrc"  ; return; }
    [ -f "$HOME/.bashrc" ] && { echo "$HOME/.bashrc" ; return; }
    [ "$(uname)" = "Darwin" ] && echo "$HOME/.zshrc" || echo "$HOME/.bashrc"
}

_devel_install_docker() {
    local os sudo_cmd
    os="$(uname)"
    if [ "$os" = "Darwin" ]; then
        if ! command -v brew >/dev/null 2>&1; then
            _devel_err "Homebrew not found. Install it from https://brew.sh or install Docker Desktop manually: https://docs.docker.com/desktop/install/mac-install/"
            return 1
        fi
        _devel_info "installing Docker Desktop via Homebrew..."
        brew install --cask docker || { _devel_err "brew install failed"; return 1; }
    elif [ "$os" = "Linux" ]; then
        if ! command -v curl >/dev/null 2>&1; then
            _devel_err "curl is required to install docker. Install curl and re-run."
            return 1
        fi
        _devel_info "installing docker via get.docker.com..."
        sudo_cmd=""
        [ "$(id -u)" -ne 0 ] && sudo_cmd="sudo"
        curl -fsSL https://get.docker.com | $sudo_cmd sh \
            || { _devel_err "docker install script failed"; return 1; }
        if [ -n "$sudo_cmd" ] && getent group docker >/dev/null 2>&1; then
            _devel_info "adding $USER to the 'docker' group (log out/in to take effect)"
            $sudo_cmd usermod -aG docker "$USER" || true
        fi
    else
        _devel_err "unsupported OS '$os'. Install docker or podman manually and re-run."
        return 1
    fi
    return 0
}

_devel_main() {
    local SCRIPT_DIR RUN_PATH ALIAS_NAME ALIAS_LINE RC existing tmp

    SCRIPT_DIR="$(cd "$(dirname "$_devel_src")" && pwd)" || return 1
    RUN_PATH="$SCRIPT_DIR/run.sh"
    ALIAS_NAME="devel"
    ALIAS_LINE="alias ${ALIAS_NAME}=\"${RUN_PATH}\""

    # 1. Verify run.sh exists; make it executable if needed.
    if [ ! -f "$RUN_PATH" ]; then
        _devel_err "run.sh not found next to install.sh ($RUN_PATH)"
        return 1
    fi
    [ -x "$RUN_PATH" ] || chmod +x "$RUN_PATH"

    # 2. Ensure a container engine is available: prefer podman, then docker.
    #    If neither is found, install docker.
    if command -v podman >/dev/null 2>&1; then
        _devel_info "found podman: $(command -v podman)"
    elif command -v docker >/dev/null 2>&1; then
        _devel_info "found docker: $(command -v docker)"
    else
        _devel_info "neither podman nor docker found — installing docker"
        _devel_install_docker || return 1
        if ! command -v docker >/dev/null 2>&1; then
            _devel_err "docker installation did not complete successfully."
            return 1
        fi
        _devel_info "docker installed: $(command -v docker)"
    fi

    # 3. Pick the rc file.
    RC="$(_devel_pick_rc)"
    if [ ! -e "$RC" ]; then
        _devel_info "creating $RC"
        : > "$RC" || { _devel_err "could not create $RC"; return 1; }
    fi

    # 4. Install or update the alias idempotently.
    if grep -Eq "^alias[[:space:]]+${ALIAS_NAME}=" "$RC"; then
        existing="$(grep -E "^alias[[:space:]]+${ALIAS_NAME}=" "$RC" | head -1)"
        if [ "$existing" = "$ALIAS_LINE" ]; then
            _devel_info "alias '${ALIAS_NAME}' already up-to-date in $RC"
        else
            _devel_info "updating '${ALIAS_NAME}' alias in $RC"
            tmp="$(mktemp "${RC}.XXXXXX")" || { _devel_err "mktemp failed"; return 1; }
            grep -Ev "^alias[[:space:]]+${ALIAS_NAME}=" "$RC" > "$tmp" || true
            printf '%s\n' "$ALIAS_LINE" >> "$tmp"
            mv "$tmp" "$RC" || { _devel_err "could not update $RC"; return 1; }
        fi
    else
        printf '\n%s\n' "$ALIAS_LINE" >> "$RC"
        _devel_info "added '${ALIAS_NAME}' alias to $RC"
    fi

    # 5. If sourced, activate the alias in the current shell right now.
    if [ "$_devel_sourced" -eq 1 ]; then
        eval "$ALIAS_LINE"
        _devel_info "alias '${ALIAS_NAME}' is now active in this shell"
    else
        _devel_info "alias ready — open a new shell, or 'source $RC', to use '${ALIAS_NAME}'"
    fi

    # 6. Launch the container. When executed, replace this process with run.sh;
    #    when sourced, run it as a child so the caller's shell survives.
    _devel_info "launching container..."
    if [ "$_devel_sourced" -eq 1 ]; then
        "$RUN_PATH" "$@"
    else
        exec "$RUN_PATH" "$@"
    fi
}

_devel_main "$@"
_devel_ret=$?

if [ "$_devel_sourced" -eq 1 ]; then
    unset -f _devel_main _devel_pick_rc _devel_install_docker _devel_err _devel_info 2>/dev/null
    unset _devel_src _devel_sourced 2>/dev/null
    return "$_devel_ret" 2>/dev/null
fi
exit "$_devel_ret"
