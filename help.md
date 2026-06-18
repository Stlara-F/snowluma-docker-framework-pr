## 食用指北
### Docker环境部署
[Docker CE](https://mirrors.ustc.edu.cn/help/docker-ce.html)
```
curl -fsSL https://get.docker.com -o get-docker.sh
sudo DOWNLOAD_URL=https://mirrors.ustc.edu.cn/docker-ce sh get-docker.sh
```
### 容器管理
[Portainer-ce](https://hub.docker.com/r/6053537/portainer-ce)
```
docker run -d --restart=always --name="portainer" -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock docker.simon.us.kg/6053537/portainer-ce
```
```
docker restart portainer
```
```
http://<server-ip>:9000/
```
```
http://<server-ip>:9000/#!/3/docker/templates/custom/new

```
### All In One
```
version: '3.8'

# ============================================================
# Shipyard Neo + AstrBot + Napcat + Snowluma 联合部署模板
# 持久化路径：/opt/astrbot
# 容器网络：astrbot_network
# 使用方式：
#   1. 修改环境变量中的 BAY_API_KEY（使用 openssl rand -hex 32 生成）和 VNC_PASSWD
#   2. 确保 /opt/astrbot 目录存在且权限正确
#   3. 在 Portainer 中粘贴此内容并部署
# ============================================================

services:
  # ---------- Napcat QQ 客户端 ----------
  napcat:
    image: docker.1ms.run/mlikiowa/napcat-docker:latest
    container_name: napcat
    restart: always
    environment:
      - NAPCAT_UID=${NAPCAT_UID:-1000}
      - NAPCAT_GID=${NAPCAT_GID:-1000}
      - MODE=astrbot
    ports:
      - "6099:6099"
    volumes:
      - /opt/astrbot/data:/AstrBot/data
      - /opt/astrbot/napcat/config:/app/napcat/config
      - /opt/astrbot/ntqq:/app/.config/QQ
    networks:
      - astrbot_network

  # ---------- Snowluma 客户端 ----------
  snowluma:
    image: docker.1ms.run/motricseven7/snowluma:latest
    container_name: snowluma
    restart: unless-stopped
    shm_size: 2gb
    cap_add:
      - SYS_PTRACE
    security_opt:
      - seccomp=unconfined
    environment:
      VNC_PASSWD: vncpasswd
      SNOWLUMA_UID: 1000
      SNOWLUMA_GID: 1000
      SNOWLUMA_WEBUI_PORT: 5099
      SNOWLUMA_LOG_LEVEL: debug
      SNOWLUMA_SCREEN: 1920x1080x16
      SNOWLUMA_HOOK_AUTOLOAD: 1
      SNOWLUMA_EXTRA_QQ_HOMES: ""
      SNOWLUMA_QQ_FLAGS: "--disable-gpu --disable-software-rasterizer --disable-gpu-compositing"
    ports:
      - "6081:6081"
      - "5099:5099"
    volumes:
      - /opt/astrbot/data:/AstrBot/data
      - /opt/snowluma/data:/app/snowluma-data
      - /opt/snowluma/qq-config:/app/.config
      - /opt/snowluma/qq-data:/app/.local/share
    networks:
      - astrbot_network

  snowluma-dev:
    image: docker.1ms.run/dockeruserstlara/snowluma:latest
    container_name: snowluma-dev
    restart: unless-stopped
    shm_size: 2gb
    cap_add:
      - SYS_PTRACE
    security_opt:
      - seccomp=unconfined
    environment:
      VNC_PASSWD: vncpasswd
      SNOWLUMA_UID: 1000
      SNOWLUMA_GID: 1000
      SNOWLUMA_WEBUI_PORT: 5099
      SNOWLUMA_LOG_LEVEL: debug
      SNOWLUMA_SCREEN: 1920x1080x16
      SNOWLUMA_HOOK_AUTOLOAD: 1
      SNOWLUMA_EXTRA_QQ_HOMES: /app/qq-acct2,/app/qq-acct3
      SNOWLUMA_QQ_FLAGS: "--disable-gpu --disable-software-rasterizer --disable-gpu-compositing"
    ports:
      - "16081:6081"
      - "15099:5099"
    volumes:
      - /opt/astrbot/data:/AstrBot/data
      - /opt/snowluma_dev/data:/app/snowluma-data
      - /opt/snowluma_dev/qq-config:/app/.config
      - /opt/snowluma_dev/qq-data:/app/.local/share
      - /opt/snowluma_dev/qq-acct2:/app/qq-acct2
      - /opt/snowluma_dev/qq-acct3:/app/qq-acct3
    networks:
      - astrbot_network

  # ---------- AstrBot 主程序 ----------
  astrbot:
    image: docker.1ms.run/soulter/astrbot:latest
    container_name: astrbot
    restart: always
    ports:
      - "6185:6185"
    volumes:
      - /opt/astrbot/data:/AstrBot/data
      - /etc/localtime:/etc/localtime:ro
      # 挂载 Bay 的数据卷以自动发现 API Key (使用宿主机目录)
      - /opt/astrbot/bay/data:/bay-data:ro
    environment:
      - TZ=Asia/Shanghai
      - BAY_DATA_DIR=/bay-data   # 让 AstrBot 自动读取 credentials.json
    depends_on:
      bay:
        condition: service_healthy
    networks:
      - astrbot_network

  # ---------- 共享浏览器服务 (Gull) ----------
  # 为 browser-python profile 提供共享 Chromium，可减少资源占用
  # 如果不需要浏览器能力，可以注释掉整个服务
  gull-service:
    image: ghcr.io/astrbotdevs/shipyard-neo-gull:latest
    container_name: bay-gull
    restart: unless-stopped
    environment:
      - GULL_MODE=shared
      - GULL_CDP_PORT=9222
      - AGENT_BROWSER_IDLE_TIMEOUT_MS=600000
    volumes:
      - /opt/astrbot/bay/cargos:/cargos:ro
    networks:
      - astrbot_network

  # ---------- Shipyard Neo Bay ----------
  bay:
    image: ghcr.io/astrbotdevs/shipyard-neo-bay:latest
    container_name: bay
    restart: unless-stopped
    ports:
      - "8114:8114"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock   # 动态创建 sandbox 容器
      - /opt/astrbot/bay/data:/app/data              # SQLite 数据库持久化
      - /opt/astrbot/bay/cargos:/var/lib/bay/cargos  # Cargo 工作区持久化
    environment:
      # ----- 请务必修改此项为强随机密钥 -----
      - BAY_API_KEY=CHANGE_ME_TO_A_RANDOM_SECRET_KEY
      - BAY_CONFIG_FILE=/app/config.yaml
    configs:
      - source: bay_config
        target: /app/config.yaml
    networks:
      - astrbot_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8114/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 15s

# 内嵌 Bay 配置文件（满足“配置文件写入 compose”）
configs:
  bay_config:
    content: |
      server:
        host: "0.0.0.0"
        port: 8114

      database:
        url: "sqlite+aiosqlite:///./data/bay.db"
        echo: false

      driver:
        type: docker
        image_pull_policy: always
        docker:
          socket: "unix:///var/run/docker.sock"
          connect_mode: container_network
          network: "astrbot_network"
          publish_ports: false

      cargo:
        root_path: "/var/lib/bay/cargos"
        default_size_limit_mb: 1024
        mount_path: "/workspace"

      security:
        api_key: "${BAY_API_KEY}"
        allow_anonymous: false

      browser_service:
        enabled: true
        endpoint: "http://gull-service:8115"

      proxy:
        enabled: false

      warm_pool:
        enabled: true
        warmup_queue_workers: 2
        warmup_queue_max_size: 256
        interval_seconds: 30
        run_on_startup: true

      profiles:
        - id: python-default
          description: "Standard Python sandbox"
          image: "ghcr.io/astrbotdevs/shipyard-neo-ship:latest"
          runtime_type: ship
          runtime_port: 8123
          resources:
            cpus: 1.0
            memory: "1g"
          capabilities:
            - filesystem
            - shell
            - python
          idle_timeout: 1800
          warm_pool_size: 1
          env: {}

        - id: python-data
          description: "Data science sandbox"
          image: "ghcr.io/astrbotdevs/shipyard-neo-ship:latest"
          runtime_type: ship
          runtime_port: 8123
          resources:
            cpus: 2.0
            memory: "4g"
          capabilities:
            - filesystem
            - shell
            - python
          idle_timeout: 1800
          warm_pool_size: 1
          env: {}

        - id: browser-python
          description: "Browser automation with shared Chromium"
          browser: shared
          containers:
            - name: ship
              image: "ghcr.io/astrbotdevs/shipyard-neo-ship:latest"
              runtime_type: ship
              runtime_port: 8123
              resources:
                cpus: 1.0
                memory: "1g"
              capabilities:
                - python
                - shell
                - filesystem
                - browser
              env: {}
          idle_timeout: 1800
          warm_pool_size: 1

      gc:
        enabled: true
        run_on_startup: true
        interval_seconds: 300
        instance_id: "bay-prod"
        idle_session:
          enabled: true
        expired_sandbox:
          enabled: true
        orphan_cargo:
          enabled: true
        orphan_container:
          enabled: true

networks:
  astrbot_network:
    name: astrbot_network
    driver: bridge
