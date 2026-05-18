#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export HOST_UID=$(id -u)
export HOST_GID=$(id -g)

# Detect container engine: prefer docker, fall back to podman
if command -v docker &>/dev/null; then
    ENGINE=docker
    COMPOSE="docker compose"
elif command -v podman &>/dev/null; then
    ENGINE=podman
    COMPOSE="podman compose"
else
    echo "Error: neither docker nor podman found. Install one and try again."
    exit 1
fi

COMPOSE_FILES="-f $SCRIPT_DIR/docker-compose.yml"
if [ "$ENGINE" = "docker" ] && [[ "$(uname)" != "Darwin" ]]; then
    COMPOSE_FILES="$COMPOSE_FILES -f $SCRIPT_DIR/docker-compose.sock.yml"
fi

# For Podman on macOS, ensure the VM is initialised and running
if [ "$ENGINE" = "podman" ] && [[ "$(uname)" == "Darwin" ]]; then
    if ! podman machine list 2>/dev/null | grep -q "podman-machine-default"; then
        echo "Podman machine not found — initialising..."
        if [[ "$(uname -m)" == "arm64" ]]; then
            if podman machine init --help 2>&1 | grep -q "vm-type"; then
                podman machine init --vm-type=applehv
            else
                echo "Warning: Podman version does not support --vm-type. Upgrade to Podman 5+ to avoid Rosetta."
                podman machine init
            fi
        else
            podman machine init
        fi
    fi
    if ! podman machine list 2>/dev/null | grep -qi "running"; then
        echo "Podman machine not running — starting it..."
        podman machine start
    fi
    # Rootful mode: socket is at /run/podman/podman.sock inside the VM
    # Rootless mode: socket is at /run/user/<uid>/podman/podman.sock (user namespace issues)
    ROOTFUL=$(podman machine inspect --format '{{.Rootful}}' 2>/dev/null || echo "false")
    if [ "$ROOTFUL" = "true" ]; then
        PODMAN_SOCK="/run/podman/podman.sock"
    else
        echo "Warning: Podman machine is running in rootless mode."
        echo "Docker socket access may fail. Switch to rootful for reliable docker-in-container:"
        echo "  podman machine stop && podman machine set --rootful && podman machine start"
        PODMAN_SOCK="/run/user/${HOST_UID}/podman/podman.sock"
        podman machine ssh "chmod 666 ${PODMAN_SOCK}" 2>/dev/null || true
    fi
fi

podman_run() {
    podman run --rm -it \
        --hostname devel \
        --security-opt label=disable \
        -v "${REPO:-$HOME}:/home/devel/repo" \
        -v "${PODMAN_SOCK}:/var/run/docker.sock" \
        -e TERM=xterm-256color \
        -e HOME=/home/devel \
        -e DOCKER_HOST=unix:///var/run/docker.sock \
        devel-cpp:latest
}

case "${1:-}" in
  help|--help|-h)
    cat <<EOF
Usage: devel [command]

Commands:
  shell        Open an interactive zsh shell in the container (default)
  build        Build (or rebuild) the container image
  up           Start the container in the background
  down         Stop and remove the container
  help         Show this help message

Environment:
  Host dir     \${REPO:-\$HOME}  →  ~/repo  inside the container
  Engine       Auto-detected: docker (preferred) or podman
  Prompt       devel:~/repo%

Examples:
  devel              # open a shell
  devel build        # rebuild after Dockerfile changes
  devel up           # run in background
  devel down         # stop
EOF
    ;;
  build)
    $COMPOSE $COMPOSE_FILES build
    ;;
  up)
    $COMPOSE $COMPOSE_FILES up -d
    ;;
  down)
    set +e
    $COMPOSE $COMPOSE_FILES down 2>&1 | grep -v "no container with"
    set -e
    ;;
  shell|"")
    if ! $ENGINE image inspect devel-cpp:latest &>/dev/null; then
      echo "Image not found — building first..."
      $COMPOSE $COMPOSE_FILES build
    fi
    if [ "$ENGINE" = "podman" ] && [[ "$(uname)" == "Darwin" ]]; then
        podman_run
    else
        $COMPOSE $COMPOSE_FILES run --rm devel
    fi
    ;;
  *)
    echo "Error: unknown command '${1}'"
    echo "Run 'devel --help' for usage."
    exit 1
    ;;
esac
