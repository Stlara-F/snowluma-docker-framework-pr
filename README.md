# 食用指北
## Docker环境部署
[Docker CE](https://mirrors.ustc.edu.cn/help/docker-ce.html)
```
curl -fsSL https://get.docker.com -o get-docker.sh
sudo DOWNLOAD_URL=https://mirrors.ustc.edu.cn/docker-ce sh get-docker.sh
```
## 容器管理
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
## All In One
```
version: '3.8'

# ============================================================
# Shipyard Neo + AstrBot + Napcat + Snowluma 联合部署模板
# 持久化路径：/opt/astrbot 和 /opt/snowluma 、/opt/snowluma_dev
# 容器：napcat、snowluma、snowluma(dev)、astrbot、shipyard-neo-gull、shipyard-neo-bay
# 容器网络：astrbot_network
# 使用方式：
#   1. 修改环境变量中的 BAY_API_KEY（使用 openssl rand -hex 32 生成）和 VNC_PASSWD
#   2. 确保 /opt/astrbot、/opt/snowluma 、/opt/snowluma_dev 目录存在且权限正确
#   3. 在 Portainer 中粘贴此内容并部署
#   4. 可按需删减compose部署
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
      SNOWLUMA_SCREEN: 1920x1080x24
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
    image: docker.1ms.run/motricseven7/snowluma:dev
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
      SNOWLUMA_SCREEN: 1920x1080x24
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
```

## 容器自动更新 **bash & cron**

#### 使用方法
 1. 安装依赖：`apt install jq`
 2. 保存脚本，`chmod +x`
 3. 配置 `COMPOSE_DIR`，可选 `LOG_FILE`
 4. 测试：`./update-compose.sh --dry-run`
 5. 加入 crontab：`*/45 * * * * /path/to/update-compose.sh`
#
```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

COMPOSE_DIR="/opt/composes"                          # compose文件路径
SERVICE_NAME="snowluma-dev"                          # 更新容器名 （空=全部）
LOG_FILE="/opt/composes/update.log"                  # 保存日志路径 （空=仅终端）
MAX_RETRIES=10                                       # Pull 重试次数
BASE_DELAY=5                                         # 基础延迟（秒），指数增长
HEALTH_TIMEOUT=3000                                  # 健康检查超时（秒）
HEALTH_INTERVAL=30                                   # 检查间隔（秒）
PULL_TIMEOUT=1800                                    # 单次 pull 超时（秒）
LOCK_FILE="/run/lock/update-compose.lock"            # 并发锁
CACHE_DIR="/tmp/compose-update-cache"                # 缓存目录
DRY_RUN=false

if [[ -t 1 ]]; then
    COLOR_RED='\033[0;31m'; COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[0;33m'; COLOR_RESET='\033[0m'
else
    COLOR_RED=''; COLOR_GREEN=''; COLOR_YELLOW=''; COLOR_RESET=''
fi

log() {
    local level="${2:-INFO}"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    case "$level" in
        ERROR)   echo -e "${COLOR_RED}[$ts] [$level] $1${COLOR_RESET}" >&2 ;;
        WARN)    echo -e "${COLOR_YELLOW}[$ts] [$level] $1${COLOR_RESET}" >&2 ;;
        SUCCESS) echo -e "${COLOR_GREEN}[$ts] [$level] $1${COLOR_RESET}" >&2 ;;
        *)       echo "[$ts] [$level] $1" ;;
    esac
}

if [[ -n "${LOG_FILE:-}" ]]; then
    exec >> "$LOG_FILE" 2>&1
fi

check_docker_daemon() {
    docker info >/dev/null 2>&1 || { log "Docker daemon not running" ERROR; return 1; }
    log "Docker daemon OK"
}
check_compose_plugin() {
    docker compose version >/dev/null 2>&1 || { log "docker compose plugin not available" ERROR; return 1; }
    log "docker compose plugin available ($(docker compose version --short))"
}
check_jq() {
    command -v jq >/dev/null 2>&1 || { log "jq not installed (apt install jq)" ERROR; return 1; }
    log "jq installed"
}

acquire_lock() {
    mkdir -p "$(dirname "$LOCK_FILE")"
    exec 9>"$LOCK_FILE"
    flock -n 9 || { log "Another instance is running, exit" WARN; exit 0; }
    log "Lock acquired"
}
release_lock() { flock -u 9 2>/dev/null || true; exec 9>&-; }

get_compose_json() {
    local compose_file
    compose_file=$(ls -1 "$COMPOSE_DIR"/{docker-compose.yml,docker-compose.yaml,compose.yml,compose.yaml} 2>/dev/null | head -1)
    [[ -z "$compose_file" ]] && { log "No compose file found" ERROR; return 1; }
    mkdir -p "$CACHE_DIR"
    local cache_file="$CACHE_DIR/compose.json"
    local mtime_file="$CACHE_DIR/compose.mtime"
    if [[ -f "$cache_file" && -f "$mtime_file" ]]; then
        local cached_mtime current_mtime
        cached_mtime=$(cat "$mtime_file")
        current_mtime=$(stat -c %Y "$compose_file" 2>/dev/null || echo "0")
        if [[ "$cached_mtime" == "$current_mtime" ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    local json
    json=$(docker compose config --format json) || { log "docker compose config failed" ERROR; return 1; }
    echo "$json" > "$cache_file"
    stat -c %Y "$compose_file" > "$mtime_file" 2>/dev/null || echo "0" > "$mtime_file"
    echo "$json"
}

parse_services() {
    local json
    json=$(get_compose_json) || return 1
    local tsv
    tsv=$(jq -r '
        .services | to_entries[] |
        [
            .key,
            (.value.image // "skip")
        ] | @tsv
    ' <<<"$json") || { log "jq parse failed" ERROR; return 1; }
    SERVICE_NAMES=(); IMAGE_NAMES=()
    while IFS=$'\t' read -r svc img; do
        SERVICE_NAMES+=("$svc")
        IMAGE_NAMES+=("$img")
    done <<<"$tsv"
    [[ ${#SERVICE_NAMES[@]} -eq 0 ]] && { log "No services found" ERROR; return 1; }
    log "Parsed ${#SERVICE_NAMES[@]} services"
    return 0
}

filter_service() {
    [[ -z "$SERVICE_NAME" ]] && return 0
    local idx=-1
    for i in "${!SERVICE_NAMES[@]}"; do
        if [[ "${SERVICE_NAMES[$i]}" == "$SERVICE_NAME" ]]; then
            idx=$i; break
        fi
    done
    [[ $idx -eq -1 ]] && { log "Service $SERVICE_NAME does not exist" ERROR; return 1; }
    if [[ "${IMAGE_NAMES[$idx]}" == "skip" ]]; then
        log "Service $SERVICE_NAME has no image (maybe build), skip" WARN
        return 1
    fi
    SERVICE_NAMES=("${SERVICE_NAMES[$idx]}")
    IMAGE_NAMES=("${IMAGE_NAMES[$idx]}")
    log "Only processing service: $SERVICE_NAME"
    return 0
}

get_image_digest() {
    local image="$1"
    local digest
    digest=$(docker image inspect "$image" --format '{{index .RepoDigests 0}}' 2>/dev/null || echo "")
    [[ -z "$digest" ]] && digest=$(docker image inspect "$image" --format '{{.Id}}' 2>/dev/null || echo "")
    echo "$digest"
}

get_container_digest() {
    local service="$1"
    local cid
    cid=$(docker compose ps -q "$service" 2>/dev/null | head -1)
    if [[ -z "$cid" ]]; then
        echo ""
        return 0
    fi
    local digest
    digest=$(docker inspect "$cid" --format '{{index .Config.Image}}' 2>/dev/null | xargs -I {} sh -c "docker image inspect {} --format '{{index .RepoDigests 0}}' 2>/dev/null || docker image inspect {} --format '{{.Id}}' 2>/dev/null")
    echo "$digest"
}

pull_services() {
    local targets=()
    [[ -n "$SERVICE_NAME" ]] && targets=("$SERVICE_NAME")
    local retry=0
    local delay=$BASE_DELAY
    while [[ $retry -lt $MAX_RETRIES ]]; do
        log "Pull attempt #$((retry+1))/$MAX_RETRIES..."
        if timeout -k 30 "$PULL_TIMEOUT" docker compose pull --quiet "${targets[@]}"; then
            log "Pull successful"
            return 0
        else
            retry=$((retry+1))
            if [[ $retry -lt $MAX_RETRIES ]]; then
                delay=$((BASE_DELAY * (2 ** (retry-1))))
                log "Pull failed, waiting ${delay}s before retry" WARN
                sleep "$delay"
            else
                log "Pull failed, max retries reached" ERROR
                return 1
            fi
        fi
    done
}

update_services() {
    local services=("$@")
    [[ ${#services[@]} -eq 0 ]] && return 0
    log "Updating services: ${services[*]}"
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would execute: stop & remove containers, then up -d ${services[*]}"
        return 0
    fi

    # Remove containers by name directly (regardless of project)
    for svc in "${services[@]}"; do
        local cid
        # Exact match of container name (may or may not have project prefix)
        cid=$(docker ps -a --filter "name=/${svc}$" -q)
        if [[ -n "$cid" ]]; then
            log "Removing existing container $cid ($svc)"
            docker stop "$cid" >/dev/null 2>&1 || true
            docker rm -f "$cid" >/dev/null 2>&1 || true
        fi
    done

    # Also attempt compose stop/rm for containers belonging to this project (in case they exist)
    docker compose stop "${services[@]}" 2>/dev/null || true
    docker compose rm -f "${services[@]}" 2>/dev/null || true

    # Recreate and start
    docker compose up -d "${services[@]}" || { log "Update failed" ERROR; return 1; }
    log "Update completed"
}

wait_for_healthy() {
    local services=("$@")
    [[ ${#services[@]} -eq 0 || "$DRY_RUN" == true ]] && return 0
    local elapsed=0
    while [[ $elapsed -lt $HEALTH_TIMEOUT ]]; do
        local all_healthy=true
        for svc in "${services[@]}"; do
            local cid
            cid=$(docker compose ps -q "$svc" 2>/dev/null | head -1)
            if [[ -z "$cid" ]]; then
                all_healthy=false
                break
            fi
            local status
            status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}running{{end}}' "$cid" 2>/dev/null || echo "unknown")
            if [[ "$status" != "healthy" && "$status" != "running" ]]; then
                all_healthy=false
                break
            fi
        done
        if [[ "$all_healthy" == true ]]; then
            log "All services healthy (or running)"
            return 0
        fi
        sleep "$HEALTH_INTERVAL"
        elapsed=$((elapsed + HEALTH_INTERVAL))
        log "Waiting for health check ($elapsed/${HEALTH_TIMEOUT}s)..."
    done
    log "Health check timeout, but containers are up (maybe no healthcheck defined)" WARN
    return 0
}

CLEANUP_NEEDED=false
cleanup() {
    if [[ "$CLEANUP_NEEDED" == true ]]; then
        log "Cleaning up dangling images"
        docker image prune -f >/dev/null 2>&1 || log "Cleanup failed, ignore" WARN
    fi
    release_lock
}
trap_cleanup() { log "Script exiting, cleanup" WARN; cleanup; }
trap trap_cleanup EXIT
trap_err() { log "Error at line $1, exit code $2" ERROR; exit "$2"; }
trap 'trap_err $LINENO $?' ERR

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) DRY_RUN=true; shift ;;
            --help)    echo "Usage: $0 [--dry-run]"; exit 0 ;;
            *)         log "Unknown option: $1" ERROR; exit 1 ;;
        esac
    done

    log "========== Auto update task started =========="
    [[ "$DRY_RUN" == true ]] && log "DRY-RUN mode, no actual changes"

    check_docker_daemon
    check_compose_plugin
    check_jq
    cd "$COMPOSE_DIR" || { log "Cannot enter $COMPOSE_DIR" ERROR; exit 1; }

    acquire_lock

    parse_services || { release_lock; exit 1; }
    filter_service || { release_lock; exit 1; }

    declare -A CURRENT_DIGESTS
    for i in "${!SERVICE_NAMES[@]}"; do
        local svc="${SERVICE_NAMES[$i]}"
        local img="${IMAGE_NAMES[$i]}"
        if [[ "$img" == "skip" ]]; then
            CURRENT_DIGESTS["$svc"]="skip"
            continue
        fi
        local cid_digest
        cid_digest=$(get_container_digest "$svc")
        CURRENT_DIGESTS["$svc"]="$cid_digest"
    done
    log "Current container digests recorded"

    pull_services || { release_lock; exit 1; }

    declare -A NEW_DIGESTS
    for i in "${!SERVICE_NAMES[@]}"; do
        local svc="${SERVICE_NAMES[$i]}"
        local img="${IMAGE_NAMES[$i]}"
        if [[ "$img" == "skip" ]]; then
            NEW_DIGESTS["$svc"]="skip"
            continue
        fi
        local new_digest
        new_digest=$(get_image_digest "$img")
        NEW_DIGESTS["$svc"]="$new_digest"
    done

    local changed=()
    for svc in "${!NEW_DIGESTS[@]}"; do
        if [[ "${NEW_DIGESTS[$svc]}" == "skip" ]]; then
            continue
        fi
        local current="${CURRENT_DIGESTS[$svc]:-}"
        local new="${NEW_DIGESTS[$svc]}"
        if [[ -z "$current" || "$current" != "$new" ]]; then
            changed+=("$svc")
        fi
    done

    if [[ ${#changed[@]} -eq 0 ]]; then
        log "All containers already use the latest image, skip update"
        release_lock
        exit 0
    fi

    log "Services needing update: ${changed[*]}"
    update_services "${changed[@]}" || { release_lock; exit 1; }
    wait_for_healthy "${changed[@]}"
    CLEANUP_NEEDED=true

    log "========== Update completed ==========" SUCCESS
    exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

# 使用第三方Snowluma仓库分支构建

你可以 fork 本仓库，使用 GitHub Actions 功能实现一键生成所需环境并推送到Dockerhub

## 预编译产物

此框架**不编译 SnowLuma 源码**，而是在构建镜像前准备好 `lite` tarball（已包含 `index.mjs` 和原生 `.node`/`.so` 插件）：

| 文件 | 说明 |
|------|------|
| `SnowLuma.Framework.linux-x64.tar.gz` | amd64 / dev 同步产物 |
| `SnowLuma.Framework.linux-arm64.tar.gz` | arm64 / dev 同步产物 |
| `SnowLuma.Framework.tar.gz` | 默认别名（指向 x64，供 Dockerfile `COPY`） |

镜像基础为 `node:22-bookworm-slim`，故使用 lite 包即可。

**默认路径**：使用仓库根目录已提交的 tarball。`scripts/resolve-framework-tarball.sh` 按平台选取对应文件并生成 `SnowLuma.Framework.tar.gz`。

**可选路径**：设置 `SNOWLUMA_TAG=vX.Y.Z` 时，从 `SnowLuma/SnowLuma` 的 GitHub Release 下载（需 [`gh` CLI](https://cli.github.com/)）。

## 同步 SnowLuma dev 预编译包

工作流 [sync-snowluma-dev.yml](.github/workflows/sync-snowluma-dev.yml) 监测 [SnowLuma/SnowLuma](https://github.com/SnowLuma/SnowLuma/tree/dev) 的 `dev` 分支，拉取最新 Dev Build 产物并提交到本仓库。

## GitHub Actions 配置

在仓库 Settings → Secrets and variables → Actions 中配置以下项：

### sync-snowluma-dev 工作流所需

| 类型 | 名称 | 用途 |
|------|------|------|
| Secret | `GH_PAT` | git push 和 gh CLI 认证（优先使用） |
| Secret | `SNOWLUMA_GH_TOKEN` | `GH_PAT` 的第一级回退（可选） |
| Secret | `SNOWLUMA_GITHUB_TOKEN` | 第二级回退(可选) |
| Variable | `DOCKER_IMAGE` | 构建和推送的镜像名称（如 `motricseven7/snowluma`） |

`SnowLuma/SnowLuma` 仓库需要分配 **Actions: Read** 权限。

### docker-image 工作流所需

| 类型 | 名称 | 用途 |
|------|------|------|
| Secret | `DOCKERHUB_USERNAME` | Docker Hub 登录用户名 |
| Secret | `DOCKERHUB_TOKEN` | Docker Hub 访问令牌 |
| Variable | `DOCKER_IMAGE` | 构建和推送的镜像名称（如 `motricseven7/snowluma`） |

### cronjob任务配置(可选)
> **定时同步**
同步后自动触发推送工作流的相关代码已删除，若需要自动推送可以补全代码
- 网址
```
https://api.github.com/repos/<github_username>/SnowLuma.Docker.Framework/actions/workflows/sync-snowluma-dev.yml/dispatches
```
- 标头

| 键 | 值 |
|------|------|
| Accept | `application/vnd.github.v3+json` |
| Authorization | `Bearer <ghp_key>`[tokens (classic)](https://github.com/settings/tokens)— repo, workflow |
| Content-Type | `application/json` |
- 请求体
```
{"ref": "main"}
```
- [x] 将带有 HTTP 3xx 状态代码的重定向视为成功 ( 视情况是否勾选返回 307 or 204 状态码，看工作流是否被触发，时区选最底部 UTC )

