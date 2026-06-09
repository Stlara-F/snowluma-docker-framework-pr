[DockerHub仓库](https://hub.docker.com/r/dockeruserstlara/snowluma)，[部署示例](https://github.com/Stlara-F/SnowLuma.Docker.Framework/blob/main/help.md)，[SnowLuma文档](https://snowluma.github.io/zh/docs/docker/)
# SnowLuma.Docker.Framework

SnowLuma 的 Linux Docker 运行框架：容器内集成 Linux QQ、Xvfb、VNC/noVNC、supervisord，并运行 SnowLuma 的 Node.js 发行产物。

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

- **触发**：外部 cronjob 每 15 分钟通过 `repository_dispatch` 推送 `snowluma-dev-updated` 事件；也支持 `workflow_dispatch` 手动触发
- **去重**：`.github/snowluma-dev-lock.json` 记录已同步的 SHA，未变化则跳过（`force=true` 可强制重下）
- **产物**：tarball 和锁文件一并提交到仓库；同时作为 Actions Artifact 保留 **7 天**
- **触发下游**：同步后自动调用 `docker-image.yml` 构建并推送 `dev` 标签的 Docker 镜像

```bash
# 手动触发同步
gh workflow run sync-snowluma-dev.yml -f force=true -f platforms=linux-x64

# 从 workflow artifact 下载产物
gh run download -R <owner>/SnowLuma.Docker.Framework \
  --name SnowLuma.Framework-dev \
  --dir .
```

## CI 自动构建 Docker 镜像

工作流 [docker-image.yml](.github/workflows/docker-image.yml) 支持 `workflow_dispatch`，通过 3 阶段（resolve → build 矩阵 → merge 多架构 manifest）构建并推送多架构镜像至 Docker Hub。

## GitHub Actions 配置

在仓库 Settings → Secrets and variables → Actions 中配置以下项：

### sync-snowluma-dev 工作流所需

| 类型 | 名称 | 用途 |
|------|------|------|
| Secret | `GH_PAT` | git push 和 gh CLI 认证（优先使用） |
| Secret | `SNOWLUMA_GH_TOKEN` | `GH_PAT` 的第一级回退 |
| Secret | `SNOWLUMA_GITHUB_TOKEN` | 第二级回退 |
| Variable | `DOCKER_IMAGE` | 触发下游构建时的镜像名称（默认 `motricseven7/snowluma`） |

`SnowLuma/SnowLuma` 仓库需要分配 **Actions: Read** 权限。

### docker-image 工作流所需

| 类型 | 名称 | 用途 |
|------|------|------|
| Secret | `DOCKERHUB_USERNAME` | Docker Hub 登录用户名 |
| Secret | `DOCKERHUB_TOKEN` | Docker Hub 访问令牌 |
| Variable | `DOCKER_IMAGE` | 构建和推送的镜像名称（默认 `motricseven7/snowluma`） |

### cronjob任务配置
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
- [x] 将带有 HTTP 3xx 状态代码的重定向视为成功
## 注意事项

- SnowLuma 使用 native addon 对 QQ 进程进行注入，容器需要 `SYS_PTRACE` 能力和 `seccomp=unconfined`
- QQ 需要 `--no-sandbox` 标志在容器内运行
- 容器重启时 `start.sh` 会自动清理残留 AF_UNIX socket（`mojo.*.sock`）
- 请遵守第三方软件的使用许可和开源协议
