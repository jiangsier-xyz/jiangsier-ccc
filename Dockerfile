ARG BASE_IMAGE=node:bookworm
FROM ${BASE_IMAGE}

USER root

ENV DEBIAN_FRONTEND=noninteractive

# base tools
RUN apt-get update && \
    apt-get -y --no-install-recommends install apt-transport-https apt-utils sudo bash ssh openssl ca-certificates curl wget telnet net-tools iproute2 inetutils-ping locales nfs-common rsync

# common tools
RUN apt-get update && \
    apt-get -y --no-install-recommends install make gcc jq vim zip unzip git ffmpeg

# python3
ARG PYTHON_VERSION=3.15.2
RUN apt-get install -y --no-install-recommends build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev llvm \
    libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev \
    liblzma-dev
# download
RUN curl -fsSLo /tmp/Python-${PYTHON_VERSION}.tgz https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
    tar -xf /tmp/Python-${PYTHON_VERSION}.tgz -C /tmp
# build
RUN cd /tmp/Python-${PYTHON_VERSION} && \
    ./configure --enable-optimizations --prefix=/usr/local && \
    make -j $(nproc) && \
    make install && \
    rm -rf /tmp/Python-${PYTHON_VERSION} /tmp/Python-${PYTHON_VERSION}.tgz
# config
RUN update-alternatives --install /usr/bin/python python /usr/local/bin/python3 1
# pip
RUN bash -eo pipefail -c 'curl -sSLf https://bootstrap.pypa.io/get-pip.py | python3 - --break-system-packages'
# pip mirror — build-time overridable:
#   docker build --build-arg PIP_INDEX_URL=https://pypi.org/simple/ ...
# The `--global` file-option (writing /etc/pip.conf) is required, not optional:
# this step runs as root while the image runs as `node`, and pip's default level
# is `user` — that would land in /root/.config/pip/pip.conf and never be read by
# the user that actually runs pip. Note the doubled word: `--global` selects the
# config file, the `global.` prefix selects the [global] ini section.
ARG PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/
RUN pip config set --global global.index-url ${PIP_INDEX_URL}

# jdk
ARG JDK_VERSION=25
RUN apt-get install -y --no-install-recommends gpg
RUN mkdir -p /usr/share/keyrings && \
    bash -eo pipefail -c 'curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg' && \
    echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" > /etc/apt/sources.list.d/adoptium.list
RUN apt-get update && \
    apt-get -y --no-install-recommends install temurin-${JDK_VERSION}-jdk maven

# golang
ARG TARGETARCH
ARG GO_VERSION=1.27.3
RUN curl -fsSLo /tmp/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz && \
    tar -xzf /tmp/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz -C /usr/local && \
    rm -f /tmp/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz

# npm packages
RUN npm install -g npm ccstatusline clawhub

# locale & timezone
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen en_US.UTF-8

ARG TZ=UTC
ENV TZ=${TZ}
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

# switch user
USER node

# configure bash
RUN echo "export LC_ALL=en_US.UTF-8" >> /home/node/.bashrc && \
    echo "export LANG=en_US.UTF-8" >> /home/node/.bashrc && \
    echo "export LANGUAGE=en_US:en" >> /home/node/.bashrc

# gh
ARG GH_VERSION=2.103.3
RUN curl -sL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${TARGETARCH}.tar.gz" -o /tmp/gh.tar.gz && \
    mkdir -p /home/node/.local/bin && \
    tar -xzf /tmp/gh.tar.gz -C /tmp && \
    cp "/tmp/gh_${GH_VERSION}_linux_${TARGETARCH}/bin/gh" /home/node/.local/bin/gh && \
    chmod +x /home/node/.local/bin/gh

# claude code
ARG CC_VERSION=2.1.325
RUN bash -eo pipefail -c "curl -fsSLk https://claude.ai/install.sh | bash -s -- '${CC_VERSION}'"

WORKDIR /home/node
