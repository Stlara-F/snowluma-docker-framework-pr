# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-bookworm-slim

ARG TARGETARCH=amd64

ENV DEBIAN_FRONTEND=noninteractive \
    VNC_PASSWD=vncpasswd \
    TZ=Asia/Shanghai \
    SNOWLUMA_HOME=/app/snowluma \
    SNOWLUMA_DATA=/app/snowluma-data \
    SNOWLUMA_WEBUI_PORT=8080 \
    SNOWLUMA_UID=1000 \
    SNOWLUMA_GID=1000 \
    SNOWLUMA_LOG_LEVEL=info \
    DISPLAY=:1

RUN rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      aria2 \
      ca-certificates \
      curl \
      dbus-user-session \
      ffmpeg \
      fluxbox \
      fonts-wqy-zenhei \
      git \
      gnutls-bin \
      libasound2 \
      libatspi2.0-0 \
      libgbm1 \
      libgtk-3-0 \
      libnotify4 \
      libnss3 \
      libsecret-1-0 \
      openbox \
      procps \
      supervisor \
      tzdata \
      unzip \
      x11vnc \
      xdg-utils \
      xorg \
      xvfb && \
    echo "${TZ}" > /etc/timezone && \
    ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
    cd /opt && git clone --depth=1 https://github.com/novnc/noVNC.git && \
    cd /opt/noVNC/utils && git clone --depth=1 https://github.com/novnc/websockify.git && \
    cp /opt/noVNC/vnc.html /opt/noVNC/index.html && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    if [ "${TARGETARCH}" != "amd64" ]; then \
      echo "SnowLuma Docker framework currently packages linux/amd64 only. Missing hook native binaries for ${TARGETARCH}."; \
      exit 1; \
    fi && \
    apt-get update && \
    aria2c --check-certificate=false -x16 -s16 -o /tmp/linuxqq.deb "https://dldir1.qq.com/qqfile/qq/QQNT/8015ff90/linuxqq_3.2.21-42086_amd64.deb" && \
    (dpkg -i /tmp/linuxqq.deb || apt-get -f install -y --no-install-recommends) && \
    rm -f /tmp/linuxqq.deb && \
    chmod 777 /opt/QQ && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY SnowLuma.Framework.tar.gz /tmp/SnowLuma.Framework.tar.gz
COPY supervisord.conf /etc/supervisord.conf
COPY start.sh /root/start.sh

RUN chmod +x /root/start.sh && \
    groupadd --gid 1001 snowluma && \
    useradd --no-log-init --uid 1001 --gid 1001 --home-dir /app --shell /bin/bash snowluma && \
    mkdir -p "${SNOWLUMA_HOME}" "${SNOWLUMA_DATA}" /app/.cache /app/.config /app/.local/share && \
    tar -xzf /tmp/SnowLuma.Framework.tar.gz -C "${SNOWLUMA_HOME}" && \
    test -f "${SNOWLUMA_HOME}/index.mjs" && \
    test -f "${SNOWLUMA_HOME}/native/snowluma-linux-x64.node" && \
    test -f "${SNOWLUMA_HOME}/native/snowluma-linux-x64.so" && \
    test -f "${SNOWLUMA_HOME}/native/websocket-linux-x64.node" && \
    rm -f /tmp/SnowLuma.Framework.tar.gz && \
    chown -R snowluma:snowluma /app /opt/QQ

WORKDIR /app/snowluma-data

EXPOSE 5900 6081 8080 3000 3001

VOLUME ["/app/snowluma-data", "/app/.config", "/app/.local/share"]

CMD ["/root/start.sh"]
