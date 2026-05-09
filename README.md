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

查看 SnowLuma WebUI 临时密码：

```bash
docker logs snowluma | grep "临时密码"
```

noVNC 地址：

```text
http://IP:6081/
```

SnowLuma WebUI 地址：

```text
http://IP:5099/
```

SnowLuma 的配置和 OneBot 配置默认持久化在 `/app/snowluma-data/config`。

## 注意

SnowLuma 当前使用 native addon 对 QQ 进程进行加载，容器启动时需要 `SYS_PTRACE` 能力和 `seccomp=unconfined`。请遵守第三方软件的使用许可和开源协议。
