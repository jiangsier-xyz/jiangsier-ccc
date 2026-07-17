# Claude Code Container

本仓库提供两样东西：

1. **Docker 镜像**（`jiangsier/ccc`）：基于 Debian `node:bookworm` 的镜像，内置完整开发工具链与 Claude Code CLI。通过 `build.sh` 多架构（amd64 + arm64）构建并推送；通过 `npm/compose.yml` 以 `claude` 作为容器入口点交互式运行。
2. **npm 包**（`@jiangsier/cc-c`）：一个薄包装命令 `cc-c`（TypeScript → `dist/`），在任意项目目录下把 `claude` 跑进上述镜像里。

## 快速开始：使用 `cc-c`

安装全局命令：

```bash
npm install -g @jiangsier/cc-c
```

在项目目录下运行：

```bash
cc-c                                # 在容器内启动交互式 claude
cc-c --dangerously-skip-permissions # 任意 claude 参数都会透传给容器内的 claude
```

`cc-c` 会以当前目录为项目目录、以目录名作为项目名称，然后用包内自带的 `compose.yml` 执行 `docker compose run --rm ccc <你的参数>`。由于该 compose 服务的 entrypoint 为 `claude`，透传的参数最终交给 `claude`。

容器会以 host 网络模式运行，挂载以下目录：

- `~/.claude`（配置）→ `/home/node/.claude`
- 当前项目目录 → `/home/node/<项目名>`、
- `~/.ssh`（凭证）→ `/home/node/.ssh`，可用于 `git` 等命令

然后，在 `/home/node/<项目名>` 下启动 claude。

容器的时区被设置为 `UTC` 以避免 claude 的时区检测带来麻烦。

> 前置条件：本机已安装 Docker，且 `docker compose` 可正常使用；**且需在宿主机 `~/.claude/` 目录下完成 Claude 的配置**（登录凭据、设置等）。

更多细节见 [`npm/README.md`](npm/README.md)。

## 镜像内置工具

容器镜像（`jiangsier/ccc`）已预装一套完整的开发工具链，`claude` 在容器内可直接调用，无需在宿主机或容器里额外安装。预装工具包括但不限于：

- **C/C++**：`gcc`、`make`
- **Java**：`temurin-25-jdk`、`maven`
- **Python**：`python3`（3.14.6）、`pip`、`venv`（pip 镜像源已指向 `mirrors.aliyun.com`）
- **Node**：`node`（26.5.0）、`npm`，来自基础镜像 `node:bookworm`
- **Golang**：`go`（1.26.5）
- **其它**：`git`、`zip`/`unzip`、`vim`、`ffmpeg`、`ssh`/`openssl`/`curl`/`wget`、`net-tools`/`iproute2`、`nfs-common`、`rsync`、`clawhub` 等等

参考 [`Dockerfile`](Dockerfile) 了解细节。

## 构建 Docker 镜像

多架构（amd64 + arm64）构建并推送：

```bash
./build.sh
```

直接用镜像跑一次交互式 claude：

```bash
CC_PROJECT=$(basename $PWD) docker compose -f npm/compose.yml run --rm ccc
```

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `Dockerfile` | 镜像定义（node:bookworm + 工具链 + claude） |
| `build.sh` | 多架构构建并推送 `jiangsier/ccc` |
| `npm/` | `@jiangsier/cc-c` npm 包源码（`src/cli.ts` → `dist/cli.js`） |
| `npm/compose.yml` | 容器运行配置（entrypoint 为 `claude`，挂载配置/项目/ssh）；仓库本地运行与包内 `cc-c` 共用此文件 |
| `scripts/publish-npm.sh` | 将 `@jiangsier/cc-c` 发布到 npm 公共仓库 |

## License

MIT
