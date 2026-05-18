FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core build tools
    build-essential \
    gcc \
    g++ \
    # Clang toolchain
    clang \
    clang-format \
    clang-tidy \
    clang-tools \
    lldb \
    lld \
    # Build systems
    cmake \
    make \
    ninja-build \
    autoconf \
    automake \
    libtool \
    pkg-config \
    # Debugging & profiling
    gdb \
    valgrind \
    strace \
    ltrace \
    linux-tools-generic \
    # Version control
    git \
    git-lfs \
    # Editors
    vim \
    nano \
    # LazyVim dependencies
    ripgrep \
    fd-find \
    # Network & download tools
    curl \
    wget \
    ca-certificates \
    # Compression
    zip \
    unzip \
    tar \
    xz-utils \
    # Node.js (required for markdown-preview.nvim and prettier)
    nodejs \
    npm \
    # Python (for build scripts)
    python3 \
    python3-pip \
    # Libraries commonly needed for C++ dev
    libssl-dev \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libboost-all-dev \
    # Misc utilities
    file \
    less \
    man-db \
    ccache \
    jq \
    zsh \
    # Docker CLI (for Docker-out-of-Docker via host socket)
    docker.io \
    docker-compose-v2 \
    # sudo (rm is restricted to root; engineer invokes it via sudo)
    sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up the engineer user (matches host UID/GID to avoid permission issues)
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN getent group ${HOST_GID} || groupadd -g ${HOST_GID} engineer && \
    useradd -m -u ${HOST_UID} -g ${HOST_GID} -s /bin/zsh engineer && \
    echo 'engineer:engineer' | chpasswd && \
    usermod -aG docker,sudo engineer

# Configure prompt, ccache, local bin path, and rm-via-sudo alias in zsh
RUN echo 'export PROMPT="%F{green}engineer%f:%F{blue}%~%f%# "' >> /home/engineer/.zshrc && \
    echo 'export PROMPT="%F{green}engineer%f:%F{blue}%~%f%# "' >> /root/.zshrc && \
    echo 'export PATH="/usr/lib/ccache:$HOME/.local/bin:$PATH"' >> /home/engineer/.zshrc && \
    echo "alias rm='sudo -k /bin/rm'" >> /home/engineer/.zshrc

# Banner shown on interactive shell start
RUN <<'EOF' cat >> /home/engineer/.zshrc
print -rP '%F{green}     _                 _ %f'
print -rP '%F{green}  __| | _____   _____| |%f'
print -rP '%F{green} / _` |/ _ \ \ / / _ \ |%f'
print -rP '%F{green}| (_| |  __/\ V /  __/ |%f'
print -rP '%F{green} \__,_|\___| \_/ \___|_|%f'
EOF
RUN chown ${HOST_UID}:${HOST_GID} /home/engineer/.zshrc

# Install latest Neovim from official GitHub release (apt version is outdated)
RUN ARCH=$(uname -m) && \
    [ "$ARCH" = "aarch64" ] && NVIM_ARCH="arm64" || NVIM_ARCH="x86_64" && \
    curl -fLo /tmp/nvim.tar.gz \
        "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" && \
    tar -xzf /tmp/nvim.tar.gz -C /opt && \
    ln -sf /opt/nvim-linux-${NVIM_ARCH}/bin/nvim /usr/local/bin/nvim && \
    rm /tmp/nvim.tar.gz


WORKDIR /home/engineer/repo

USER engineer

# Set up LazyVim starter config
# Plugins are downloaded on first launch by lazy.nvim
RUN git clone --depth 1 https://github.com/LazyVim/starter /home/engineer/.config/nvim \
    && rm -rf /home/engineer/.config/nvim/.git \
    # fd is installed as fdfind on Ubuntu — symlink to fd for LazyVim/telescope
    && mkdir -p /home/engineer/.local/bin \
    && ln -sf /usr/bin/fdfind /home/engineer/.local/bin/fd

USER root
COPY nvim/lua/plugins/ /home/engineer/.config/nvim/lua/plugins/
RUN chown -R ${HOST_UID}:${HOST_GID} /home/engineer/.config/nvim/lua/plugins/

# Restrict /bin/rm to root only — engineer must use `sudo rm` (aliased in .zshrc).
# Done last so earlier RUN steps can still use rm.
RUN chmod 700 /bin/rm

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
