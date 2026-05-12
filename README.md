# SnowLuma.Docker.Framework

SnowLuma 的 Linux Docker 运行框架，结构参考 `NapCat.Docker.Framework`：容器内安装 Linux QQ、Xvfb、VNC/noVNC、supervisord，并运行 SnowLuma 的 Node.js 发行产物。

## 支持平台

- [x] Linux/Amd64
- [x] Linux/Arm64

## 端口

- `5900`: VNC
- `6081`: noVNC
- `5099`: SnowLuma WebUI
- `3000`: OneBot HTTP 默认端口
- `3001`: OneBot WebSocket 默认端口

## 预编译产物

这个 Docker 框架**不编译 SnowLuma 源码**，只消费 SnowLuma 主仓库 GitHub Release 上的预编译 `lite` tarball：

- `SnowLuma-<TAG>-linux-x64-lite.tar.gz`
- `SnowLuma-<TAG>-linux-arm64-lite.tar.gz`

镜像基础是 `node:22-bookworm-slim`（已自带 Node.js 运行时），所以挑 `lite` 版本，**不需要**带 `node` 二进制的完整版。

构建时把对应架构的 tarball 重命名为 `SnowLuma.Framework.tar.gz` 放到仓库根目录，Dockerfile 会 `COPY` 进去并按 `dpkg --print-architecture` 校验当前架构的 native 文件齐全。CI 与 `scripts/build-image.sh` 都会自动用 `gh release download` 拉取，无需手动操作。

## 本地构建

最简：从 SnowLuma release 自动下载并构建（默认 `linux/amd64`、`load` 到本地 Docker）：

```bash
SNOWLUMA_TAG=v1.6.35 ./scripts/build-image.sh
```

需要本机已装 [`gh` CLI](https://cli.github.com/)（用于下载 release 资产）以及 Docker buildx。

构建并推送到镜像仓库：

```bash
IMAGE=motricseven7/snowluma:v1.6.35 PUSH=1 SNOWLUMA_TAG=v1.6.35 ./scripts/build-image.sh
```

切换架构：

```bash
PLATFORM=linux/arm64 SNOWLUMA_TAG=v1.6.35 ./scripts/build-image.sh
```

> Multi-arch manifest 的合并请走 CI（`.github/workflows/docker-image.yml`）— 本地脚本只支持单平台。

如果你**手动准备** `SnowLuma.Framework.tar.gz` 放在仓库根目录，可以省略 `SNOWLUMA_TAG`，脚本会复用现有文件。

## CI 自动构建

SnowLuma 主仓库每次发 tag 都会自动派发 workflow_dispatch 到本仓库的 `docker-image.yml`，参数包含 `snowluma_tag` / `snowluma_repository`。Workflow 在 `ubuntu-22.04` 和 `ubuntu-22.04-arm` 原生 runner 上分别构建 amd64 / arm64，最后用 `docker buildx imagetools` 合并 manifest 推到 Docker Hub。

也可以在 Actions 页手动触发 `docker-publish` 工作流，对任意已发布的 SnowLuma tag 重打镜像。

## 启动

```bash
./scripts/run.sh
```

或使用已发布镜像：

```bash
docker compose up -d
```

## docker run 示例

```bash
docker run -d \
  --name snowluma \
  --restart unless-stopped \
  --shm-size=1g \
  --cap-add=SYS_PTRACE \
  --security-opt seccomp=unconfined \
  -e VNC_PASSWD=vncpasswd \
  -e SNOWLUMA_WEBUI_PORT=5099 \
  -p 5900:5900 \
  -p 6081:6081 \
  -p 5099:5099 \
  -p 3000:3000 \
  -p 3001:3001 \
  -v snowluma-data:/app/snowluma-data \
  -v snowluma-qq-config:/app/.config \
  -v snowluma-qq-data:/app/.local/share \
  motricseven7/snowluma:latest
```

## 常用命令

进入容器：

```bash
docker exec -it snowluma bash
```

查看日志：

```bash
docker logs -f snowluma
```

快速查找 SnowLuma WebUI 临时密码：

```bash
docker logs snowluma 2>&1 | grep -E "临时密码|initial credentials" | tail -n 1
```

只输出密码本身：

```bash
docker logs snowluma 2>&1 | sed -nE 's/.*(临时密码: |initial credentials: user=admin password=)([^[:space:]]+).*/\2/p' | tail -n 1
```

如果启动时自定义了容器名，请把命令里的 `snowluma` 替换成实际容器名。临时密码只会在全新的 `snowluma-data` 卷首次启动时输出一次；后续重启或复用旧卷时不会再生成新的明文密码。

noVNC 地址：

```text
http://IP:6081/
```

SnowLuma WebUI 地址：

```text
http://IP:5099/
```

SnowLuma 的配置和 OneBot 配置默认持久化在 `/app/snowluma-data/config`。

## 自动注入

镜像默认**不开启**自动注入（`SNOWLUMA_HOOK_AUTOLOAD=0`）。容器起来后请 VNC 登录 QQ，再到 SnowLuma WebUI 手动点击对应进程的 "Load" 按钮触发注入。

### 为什么默认关闭

在 QQ 完成登录之前对其触发自动注入存在已知的时序问题：SnowLuma 可能会读取到登录尚未完成阶段产生的临时状态，把它当成已登录，然后进入"在线但所有数据请求都超时"的卡住状态，WebUI 日志里会大量出现 `failed to load rkeys/friends/groups for UIN <某个值>: send reply timed out`。等 QQ 完成登录后再手动点 Load 不会有这个问题。

### 需要在容器启动时自动注入

只在能确认 QQ 启动时会立刻走"自动登录"且几秒内完成的场景下显式开启，否则请保持默认关闭：

```bash
docker run -e SNOWLUMA_HOOK_AUTOLOAD=1 ... motricseven7/snowluma:latest
```

或在 `docker-compose.yml` 里设 `SNOWLUMA_HOOK_AUTOLOAD: 1`。也可以在持久卷 `/app/snowluma-data/config/runtime.json` 里设置 `"hookAutoLoad": true` 长期开启；环境变量优先于 JSON 配置。

如果开启后看到上面的 `send reply timed out` 警告，请关掉自动注入、重启容器，等 QQ 登录完成再手动 Load。

## 注意

SnowLuma 当前使用 native addon 对 QQ 进程进行加载，容器启动时需要 `SYS_PTRACE` 能力和 `seccomp=unconfined`。请遵守第三方软件的使用许可和开源协议。
