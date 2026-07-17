# Claude Code Container

`cc-c` — run `claude` (the Claude Code CLI) inside a container with a single command.

`cc-c` is a thin wrapper around `claude`: it treats the current directory as the project directory, automatically mounts the host's Claude config, project code, and SSH credentials, then launches `claude` inside the container. Every argument passed to `cc-c` is forwarded verbatim to `claude` in the container.

## Installation

```bash
npm install -g @jiangsier/cc-c
```

This gives you a global `cc-c` command.

## Prerequisites

- Docker is installed on the host, and `docker compose` works.
- **The host's `~/.claude/` directory must have Claude configured** (login credentials, settings, etc.). The container mounts the host's `~/.claude` to `/home/node/.claude` inside the container, so `claude` reuses the host configuration directly. If the host's `~/.claude/` is not configured (e.g. not logged in), `claude` in the container won't work either. You can run `claude` once on the host to complete login and initial setup.
- The container image is pulled from `jiangsier/ccc:latest` on Docker Hub by default. To override, set the `CCC_IMAGE` environment variable, e.g.:

  ```bash
  CCC_IMAGE=jiangsier/ccc:latest cc-c
  ```

## Built-in tools in the image

The container image (`jiangsier/ccc`) ships a complete dev toolchain, so `claude` can invoke these directly inside the container — no extra installs needed on the host or in the container. Preinstalled tools include, among others:

- **C/C++**: `gcc`, `make`
- **Java**: `temurin-25-jdk`, `maven`
- **Python**: `python3` (3.14.6), `pip`, `venv` (pip index pointed at `mirrors.aliyun.com`)
- **Node**: `node` (26.5.0), `npm`, from the `node:bookworm` base image
- **Golang**: `go` (1.26.5)
- **Others**: `git`, `zip`/`unzip`, `vim`, `ffmpeg`, `ssh`/`openssl`/`curl`/`wget`, `net-tools`/`iproute2`, `nfs-common`, `rsync`, `clawhub`, etc.

## Usage

From any project directory, simply run:

```bash
cc-c
```

to launch an interactive `claude` inside the container. Arguments passed to `cc-c` are forwarded to `claude`, e.g.:

```bash
cc-c --dangerously-skip-permissions
# runs inside the container: claude --dangerously-skip-permissions
```

## How it works

`cc-c` does the following:

1. Takes the current directory (`$PWD`) as the project directory and its basename as the project name.
2. Exports `CCC_PROJECT_DIR=$PWD` and `CCC_PROJECT=$(basename $PWD)`.
3. Uses the `compose.yml` bundled inside the package (no `compose.yml` is needed in the current directory) to run:

   ```bash
   docker compose -f <temp compose.yml> run --rm ccc <your cc-c args...>
   ```

The compose service's `entrypoint` is `claude`, so the arguments following `cc-c` are ultimately handed to `claude` inside the container.

At runtime the container:

- uses `host` network mode;
- mounts the host's `~/.claude` (Claude config/settings) → `/home/node/.claude` inside the container;
- mounts the current project directory → `/home/node/<project>` inside the container, and uses it as the working directory;
- mounts the host's `~/.ssh` (SSH credentials) → `/home/node/.ssh` inside the container;
- launches with `claude` as the entrypoint from `/home/node/<project>`.

Optional environment variables:

| Variable | Purpose | Default |
| --- | --- | --- |
| `CCC_IMAGE` | Override the container image | `jiangsier/ccc:latest` |
| `CCC_CONFIG_DIR` | Host Claude config directory | `$HOME/.claude` |
| `CCC_PROJECT_DIR` | Host project directory (auto-set by `cc-c` to the current directory) | `$PWD` |
| `CCC_PROJECT` | Container project mount basename and working-directory name (auto-set by `cc-c`) | `$(basename $PWD)` |

## License

MIT
