# Claude Code Container

This repo provides two things:

1. **Docker image** (`jiangsier/ccc`): a Debian `node:bookworm`-based image with a full dev toolchain and the Claude Code CLI built in. Built and pushed multi-arch (amd64 + arm64) via `build.sh`; run interactively through `npm/compose.yml` with `claude` as the container entrypoint.
2. **npm package** (`@jiangsier/cc-c`): a thin `cc-c` command (TypeScript → `dist/`) that runs `claude` inside the above image from any project directory.

## Quick start: using `cc-c`

Install the global command:

```bash
npm install -g @jiangsier/cc-c
```

Run it from a project directory:

```bash
cc-c                                # start an interactive claude inside the container
cc-c --dangerously-skip-permissions # any claude flag is forwarded to claude in the container
```

`cc-c` treats the current directory as the project directory and its basename as the project name, then runs `docker compose run --rm ccc <your args>` using the `compose.yml` bundled inside the package. Since that compose service's entrypoint is `claude`, the forwarded args end up with `claude`.

The container runs in host network mode and mounts:

- `~/.claude` (config) → `/home/node/.claude`
- the current project directory → `/home/node/<project>`,
- `~/.ssh` (credentials) → `/home/node/.ssh`, available to `git` and similar commands.

Then it launches `claude` from `/home/node/<project>`.

The container's timezone is set to `UTC` to avoid claude's timezone-detection issues.

> Prerequisites: Docker is installed on the host and `docker compose` works; **and the host's `~/.claude/` directory must have Claude configured** (login credentials, settings, etc.).

See [`npm/README.md`](npm/README.md) for more detail.

## Built-in tools in the image

The container image (`jiangsier/ccc`) ships a complete dev toolchain, so `claude` can invoke these directly inside the container — no extra installs needed on the host or in the container. Preinstalled tools include, among others:

- **C/C++**: `gcc`, `make`
- **Java**: `temurin-25-jdk`, `maven`
- **Python**: `python3` (3.15.2), `pip`, `venv` — built from source; pip's index defaults to `mirrors.aliyun.com`, overridable at build time via `--build-arg PIP_INDEX_URL=...`
- **Node**: `node` (LTS) and `npm`, from the `node:bookworm` base image — a floating tag, so the exact version tracks upstream on each rebuild
- **Golang**: `go` (1.27.3)
- **Others**: `git`, `zip`/`unzip`, `vim`, `ffmpeg`, `ssh`/`openssl`/`curl`/`wget`, `net-tools`/`iproute2`, `nfs-common`, `rsync`, `clawhub`, etc.

See [`Dockerfile`](Dockerfile) for details.

## Building the Docker image

The release version has a single source of truth: `CCC_VERSION` in [`npm/.env`](npm/.env). It drives the Docker tag (`build.sh`), the default image tag (`npm/compose.yml`) and the npm package version (`scripts/publish-npm.sh`, as `${CCC_VERSION}.0`). To cut a release, bump that one value — then build and push the image **before** publishing the CLI, since the published CLI defaults to pulling that exact tag.

Build multi-arch (amd64 + arm64) and push:

```bash
./build.sh
```

Run an interactive `claude` directly with the image:

```bash
CCC_PROJECT=$(basename $PWD) docker compose -f npm/compose.yml run --rm ccc
```

## Directory layout

| Path | Description |
| --- | --- |
| `Dockerfile` | Image definition (node:bookworm + toolchain + claude) |
| `build.sh` | Multi-arch build and push of `jiangsier/ccc` |
| `npm/` | `@jiangsier/cc-c` npm package source (`src/cli.ts` → `dist/cli.js`) |
| `npm/compose.yml` | Container run config (entrypoint is `claude`, mounts config/project/ssh); shared by local repo runs and the bundled `cc-c` CLI |
| `npm/.env` | `CCC_VERSION` — single source of truth for the release version (Docker tag, default image tag, npm package version). Tracked in git via a `!npm/.env` negation in `.gitignore` |
| `scripts/publish-npm.sh` | Publishes `@jiangsier/cc-c` to the public npm registry |

## License

MIT
