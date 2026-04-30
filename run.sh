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
    # Use podman-compose if available, otherwise podman compose
    if command -v podman-compose &>/dev/null; then
        COMPOSE="podman-compose"
    else
        COMPOSE="podman compose"
    fi
else
    echo "Error: neither docker nor podman found. Install one and try again."
    exit 1
fi

echo "Using: $ENGINE"

# Socket override: only Docker on Linux can mount the host socket into containers.
# Podman on macOS does not support mounting the macOS-side socket into the Linux VM.
if [ "$ENGINE" = "docker" ] && [[ "$(uname)" != "Darwin" ]]; then
    COMPOSE_FILES="-f $SCRIPT_DIR/docker-compose.yml -f $SCRIPT_DIR/docker-compose.sock.yml"
else
    COMPOSE_FILES="-f $SCRIPT_DIR/docker-compose.yml"
fi

# For Podman on macOS, ensure the VM is initialised and running
if [ "$ENGINE" = "podman" ] && [[ "$(uname)" == "Darwin" ]]; then
    if ! podman machine list 2>/dev/null | grep -q "podman-machine-default"; then
        echo "Podman machine not found — initialising..."
        # On Apple Silicon, prefer Apple Hypervisor Framework (Podman 5+) over QEMU to avoid Rosetta.
        # Fall back to plain init if --vm-type is not supported by this version.
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
fi

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
  Host dir     \$HOME/repo  →  ~/repo  inside the container
  Engine       Auto-detected: docker (preferred) or podman
  Prompt       devel:~/repo\$

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
    $COMPOSE $COMPOSE_FILES run --rm devel /bin/zsh
    ;;
  *)
    echo "Error: unknown command '${1}'"
    echo "Run 'devel --help' for usage."
    exit 1
    ;;
esac
