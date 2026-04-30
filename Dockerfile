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
    neovim \
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up a non-root user matching common host UID to avoid permission issues
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN getent group ${HOST_GID} || groupadd -g ${HOST_GID} devel && \
    useradd -m -u ${HOST_UID} -g ${HOST_GID} -s /bin/zsh devel && \
    # Add devel user to the docker group so it can use the host Docker socket
    usermod -aG docker devel

# Configure prompt and ccache in zsh
RUN echo 'export PROMPT="%F{green}devel%f:%F{blue}%~%f%# "' >> /home/devel/.zshrc && \
    echo 'export PROMPT="%F{green}devel%f:%F{blue}%~%f%# "' >> /root/.zshrc && \
    echo 'export PATH="/usr/lib/ccache:$PATH"' >> /home/devel/.zshrc

WORKDIR /home/devel/repo

USER devel

# Set up LazyVim starter config
# Plugins are downloaded on first launch by lazy.nvim
RUN git clone --depth 1 https://github.com/LazyVim/starter /home/devel/.config/nvim \
    && rm -rf /home/devel/.config/nvim/.git \
    # fd is installed as fdfind on Ubuntu — symlink to fd for LazyVim/telescope
    && mkdir -p /home/devel/.local/bin \
    && ln -sf /usr/bin/fdfind /home/devel/.local/bin/fd \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/devel/.zshrc

# Copy custom plugin configs (cpp, completion, debugging)
COPY --chown=devel:devel nvim/lua/plugins/ /home/devel/.config/nvim/lua/plugins/

CMD ["/bin/zsh"]
