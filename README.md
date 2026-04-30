# C++ Development Environment

A Docker-based C++ development environment built on Ubuntu 24.04, with the host repository mounted inside the container.

## Contents

| File | Purpose |
|---|---|
| `Dockerfile` | Ubuntu 24.04 image with full C++ toolchain |
| `docker-compose.yml` | Mounts `$HOME/repo` → `~/repo` inside the container |
| `run.sh` | Convenience wrapper script |

## Included Tools

| Category | Tools |
|---|---|
| Compilers | `gcc`, `g++`, `clang`, `clang++` |
| LLVM toolchain | `clang-format`, `clang-tidy`, `lldb`, `lld` |
| Build systems | `cmake`, `make`, `ninja`, `autoconf`, `automake`, `libtool` |
| Debugging & profiling | `gdb`, `valgrind`, `strace`, `ltrace` |
| Libraries | `libboost-all-dev`, `libssl-dev`, `libcurl4-openssl-dev`, `zlib1g-dev` |
| Build acceleration | `ccache` |
| Version control | `git`, `git-lfs` |
| Scripting | `python3`, `pip` |
| Utilities | `vim`, `nano`, `curl`, `wget`, `jq`, `pkg-config` |
| Editor | `neovim` with `LazyVim` (plugins download on first launch) |
| Shell | `zsh` |
| Docker | `docker` CLI (via host socket) |

---

## Prerequisites

Either **Docker Desktop** or **Podman** must be installed on the host. `run.sh` auto-detects whichever is available, preferring Docker if both are present.

### Option A — Docker Desktop

Download and install Docker Desktop from `docker.com/products/docker-desktop`, then launch it and wait for the whale icon to appear in the menu bar.

### Option B — Podman (no Docker Desktop required)

```bash
brew install podman podman-compose
podman machine init      # one-time setup
podman machine start     # starts the VM (run.sh does this automatically on subsequent boots)
```

> After the first `podman machine init`, you never need to run it again. `run.sh` will automatically start the Podman VM on subsequent runs if it is not already running.

---

## First-time Setup

### 1. Add the `devel` alias to your shell

Add the following line to `~/.zshrc` so the `devel` command is available from any directory:

```bash
alias devel="$HOME/repo/devel/run.sh"
```

Then reload your shell:

```bash
source ~/.zshrc
```

### 2. Build the container image

```bash
devel build
```

This only needs to be done once (or again if you change the `Dockerfile`).

---

## Daily Usage

Simply type `devel` from anywhere to drop into the container:

```bash
devel
```

`run.sh` will automatically:
- Detect whether Docker or Podman is available
- Start the Podman VM if it is not running (macOS only)
- Build the image if it does not exist yet
- Mount `$HOME/repo` to `/repo` inside the container
- Open an interactive bash shell

### All commands

```bash
devel            # open an interactive shell (default)
devel shell      # same as above
devel build      # (re)build the container image
devel up         # start the container in the background
devel down       # stop and remove the container
```

---

## Prompt

Once inside the container the prompt looks like:

```
devel:/repo$
```

`devel` is shown in green and the current path in blue.

---

## Volume Mount

The host directory `$HOME/repo` is mounted to `~/repo` (`/home/devel/repo`) inside the container. Files created or modified inside the container are immediately reflected on the host, and vice versa.

---

## File Permissions

The container runs as a non-root user (`devel`) whose UID and GID are matched to your host user at build time. Files created inside the container have the correct ownership on the host.

---

## Building Docker Images from Inside the Container (DooD)

The host Docker socket (`/var/run/docker.sock`) is mounted into the container and the `devel` user is added to the `docker` group. You can run `docker build` and `docker run` normally from inside the container — images are built on the host daemon and visible on the host.

```bash
# Inside the container
docker build -t my-image .
docker run --rm my-image
```

> Containers launched from inside this environment are siblings on the host, not nested children.
