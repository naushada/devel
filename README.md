# C++ Development Environment

A Docker-based C++ development environment built on Ubuntu 24.04, with the host repository mounted inside the container.

## Contents

| File | Purpose |
|---|---|
| `Dockerfile` | Ubuntu 24.04 image with full C++ toolchain |
| `docker-compose.yml` | Mounts `$REPO` (defaults to `$HOME`) → `~/repo` inside the container |
| `install.sh` | One-time setup: ensures an engine, installs the `devel` alias, launches the container |
| `run.sh` | Convenience wrapper invoked by the `devel` alias (build/up/down/shell, tmux wrapping) |
| `entrypoint.sh` | Container entrypoint: wires up the docker socket group and drops to the `engineer` user |
| `nvim/lua/plugins/` | LazyVim plugin specs copied into the image (C++, completion, markdown, etc.) |

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

From the cloned repo directory, run `install.sh`. It works **two ways**:

```bash
source ./install.sh    # recommended — also activates `devel` in the current shell
./install.sh           # executes normally — `devel` is ready in new shells only
```

`install.sh` will:
- ensure a container engine is available (prefer `podman`, then `docker`; install `docker` if neither is found)
- detect your shell (`$SHELL`, then existing rc files, then platform default)
- add `alias devel="<absolute path>/run.sh"` to your `~/.zshrc` or `~/.bashrc` (idempotent — safe to re-run; updates the path if you moved the repo)
- launch the container (which builds the image on first run)

**Why two ways?** A script run as `./install.sh` is a child process — it can write the alias to your rc file but cannot add it to the shell that started it. **Sourcing** runs in your current shell, so `devel` works immediately. If you used `./install.sh`, open a new shell or run `source ~/.zshrc` (or `~/.bashrc`) afterwards to use `devel`.

---

## Running on a Remote Linux Server

The environment is well suited to a remote VM reached over SSH. On Linux, `install.sh` will install Docker for you if it is missing (via `get.docker.com`) and add your user to the `docker` group.

End-to-end from a fresh server:

```bash
# 1. (Optional) create a dedicated login user with sudo access.
sudo useradd -m -s /bin/bash engineer
echo 'engineer:engineer' | sudo chpasswd      # change this password!
sudo usermod -aG sudo engineer                 # 'wheel' on RHEL/Fedora
# then log in as that user: ssh engineer@<host>  (or: su -l engineer)

# 2. Clone and install. Installs Docker if absent and adds you to the docker group.
git clone https://github.com/naushada/devel.git
cd devel
./install.sh

# 3. If you were just added to the 'docker' group, log out and back in once so
#    the new group takes effect (see Troubleshooting), then launch:
devel
```

Notes for remote use:

- **Persistent sessions.** `devel` runs inside tmux, so you can detach (`Ctrl-b d`), drop your SSH connection, reconnect later, and run `devel` again to resume exactly where you left off. See [Persistent Sessions (tmux)](#persistent-sessions-tmux).
- **Running as `root`.** If your server logs you in as `root` (UID/GID 0), the build still works — the `engineer` user is created sharing UID/GID 0 via `useradd -o`. No separate user is required.
- **UID/GID matching.** `run.sh` passes your host `HOST_UID`/`HOST_GID` into the build so files under `~/repo` keep the right ownership on the host.

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
- Mount `$REPO` (defaults to `$HOME`) to `~/repo` inside the container
- Wrap the interactive shell in a persistent **tmux** session (see below)
- Open an interactive zsh shell

### All commands

```bash
devel            # open an interactive shell (default)
devel shell      # same as above
devel build      # (re)build the container image
devel up         # start the container in the background
devel down       # stop and remove the container
```

---

## Persistent Sessions (tmux)

The interactive shell (`devel` / `devel shell`) is launched inside a tmux
session named `devel`, so the container survives SSH disconnects — handy on a
remote VM. Start work, detach, lose your connection, reconnect, and run `devel`
again to drop straight back into the running session.

```bash
devel                 # creates/attaches the 'devel' tmux session
# Ctrl-b d            # detach — the container keeps running
# ...reconnect over SSH...
devel                 # re-attaches to the same live session
```

`run.sh` re-execs itself with `tmux new-session -A`, which **attaches** to the
session if it already exists and **creates** it otherwise. tmux is skipped
automatically when it is not relevant:

- tmux is not installed
- you are already inside a tmux session (no nesting)
- stdin is not a terminal (e.g. piped/CI use)

| Variable | Effect |
|---|---|
| `DEVEL_NO_TMUX=1` | Disable the tmux wrapper; run the shell directly |
| `DEVEL_TMUX_SESSION=name` | Use a different session name (default `devel`) |

**Colors / truecolor.** tmux is launched with `-2` to force 256-color support
(plain tmux otherwise advertises only the 8-color `screen` terminal), and a
`terminal-overrides ",xterm-256color:RGB"` entry is set so 24-bit truecolor
output from the container (e.g. Neovim/LazyVim themes) passes through
correctly. The container itself always runs with `TERM=xterm-256color`. If
colors still look wrong, confirm your **outer** terminal/SSH client advertises
`TERM=xterm-256color` (`echo $TERM`), since the override keys off that.

---

## Prompt

Once inside the container the prompt looks like:

```
engineer:~/repo%
```

`engineer` is shown in green and the current path in blue (`%` is the zsh prompt character).

---

## Markdown Preview

Neovim ships with `markdown-preview.nvim`. Open a markdown file and use:

```
:MarkdownPreview        " start the live preview
:MarkdownPreviewStop    " stop it
:MarkdownPreviewToggle  " toggle
```

The preview is served by a small HTTP server **inside the container**, and the container has no browser of its own — nor does `docker-compose.yml` publish any ports. So to view the preview you reach that server's port from a machine that *does* have a browser (your laptop).

On a remote VM, pin the port and bind it to all interfaces by adding to your Neovim config, then tunnel it over SSH:

```lua
-- e.g. in ~/.config/nvim/lua/config/ or the markdown-preview spec
vim.g.mkdp_port = "8080"
vim.g.mkdp_open_to_the_world = 1   -- listen on 0.0.0.0 so the tunnel reaches it
vim.g.mkdp_auto_start = 0
```

```bash
# Run the container with the port published (host -> container)...
#   add `ports: ["8080:8080"]` to the devel service in docker-compose.yml
# ...then from your laptop, tunnel the VM's published port:
ssh -L 8080:localhost:8080 engineer@<host>
# open http://localhost:8080 in your local browser, then :MarkdownPreview in nvim
```

> For purely local in-buffer rendering (no browser needed), the environment also includes `render-markdown.nvim`, which styles headings, code blocks, tables, and checkboxes directly inside Neovim.

---

## Volume Mount (`REPO`)

The host directory `$REPO` is mounted to `~/repo` (`/home/engineer/repo`) inside the container. Files created or modified inside the container are immediately reflected on the host, and vice versa.

`REPO` defaults to `$HOME`. To mount a specific project instead, export it before launching:

```bash
export REPO="$HOME/projects/myapp"
devel
```

- Use an **absolute path** — bind mounts require it (`$(pwd)` or `$HOME/...` is fine; `./myapp` is not).
- The directory must already exist on the host.
- **macOS:** `REPO` must be inside your home directory — the Podman/Docker Desktop VM only shares `$HOME` by default, so a path outside it would mount as empty.

---

## File Permissions

The container runs as a non-root user (`engineer`) whose UID and GID are matched to your host user at build time (`run.sh` passes `HOST_UID`/`HOST_GID`). Files created inside the container have the correct ownership on the host.

On Linux your host user is typically UID/GID 1000 — the same UID/GID as the default `ubuntu` user shipped in the `ubuntu:24.04` base image. The Dockerfile removes that default user before creating `engineer`, so the build does not fail with `useradd: UID 1000 is not unique`.

---

## `rm` is restricted to root

To protect the bind-mounted host directory from accidental deletes, `/bin/rm` is mode `700` (root only). The `engineer` user gets an alias `rm='sudo -k /bin/rm'` so each `rm` invocation prompts for `engineer`'s password (default: `engineer`). This is a speed bump, not strong security — `find -delete`, scripts that call `unlink`, and similar paths still bypass the prompt.

---

## Building Docker Images from Inside the Container (DooD)

The host Docker socket (`/var/run/docker.sock`) is mounted into the container and the `engineer` user is added to the `docker` group. You can run `docker build` and `docker run` normally from inside the container — images are built on the host daemon and visible on the host.

```bash
# Inside the container
docker build -t my-image .
docker run --rm my-image
```

> Containers launched from inside this environment are siblings on the host, not nested children.

---

## Troubleshooting

### `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`

Seen when running `./install.sh` / `./run.sh` as a host user that is not in the host's `docker` group. The Docker socket is owned by `root:docker`, so only root or `docker` group members can talk to the daemon. (Note: the `usermod -aG docker engineer` inside the Dockerfile applies to the `engineer` user *in the image*, not to your user on the host VM.)

Add your host user to the `docker` group, then start a **fresh login session** — group membership is only re-read at login, so the current shell keeps its old groups:

```bash
sudo usermod -aG docker "$USER"   # add to the docker group
# then log out and back in (e.g. exit your SSH session and reconnect)
```

Verify:

```bash
id            # 'docker' now appears in the groups list
docker ps     # runs without 'permission denied'
```

If `getent group docker` returns nothing, create the group first with `sudo groupadd docker`, then re-run the `usermod`.
