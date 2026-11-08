#!/usr/bin/env bash
# publish-npm.sh — publish the @jiangsier/cc-c npm package to the public npm registry.
#
# Uses `npm publish` against registry.npmjs.org. Auth via the caller's
# `npm login` session, or an `NPM_PUBLISH_TOKEN` (automation token) for CI.
#
# The compiled dist/ (the ccc CLI) is bundled inside the published tarball via
# the package `files` field — no separate artifact upload.
set -euo pipefail

cd "$(dirname "$0")/.."

REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org}"
PACKAGE_DIR="${NPM_PACKAGE_DIR:-npm}"

# CCC_VERSION in ${PACKAGE_DIR}/.env is the single source of truth for the
# release version — it also drives the Docker tag in build.sh and the default
# image tag in compose.yml. npm requires package.json "version" to be a literal,
# so sync it from .env here (1.6 -> 1.6.0) before anything reads it.
CCC_ENV_FILE="./${PACKAGE_DIR}/.env"
# A real environment variable wins over the .env file (same precedence docker
# compose uses), so stash and restore it — sourcing would otherwise clobber it.
CCC_VERSION_OVERRIDE="${CCC_VERSION:-}"
if [ -f "$CCC_ENV_FILE" ]; then
  set -a
  . "$CCC_ENV_FILE"
  set +a
fi
if [ -n "$CCC_VERSION_OVERRIDE" ]; then
  CCC_VERSION="$CCC_VERSION_OVERRIDE"
fi
CCC_VERSION="${CCC_VERSION:-1.6}"
echo "syncing ${PACKAGE_DIR}/package.json version from CCC_VERSION=${CCC_VERSION} -> ${CCC_VERSION}.0"
(cd "./${PACKAGE_DIR}" && npm version "${CCC_VERSION}.0" --no-git-tag-version --allow-same-version >/dev/null)

PACKAGE_NAME="$(node -p "require('./${PACKAGE_DIR}/package.json').name")"
PACKAGE_VERSION="$(node -p "require('./${PACKAGE_DIR}/package.json').version")"
USERCONFIG=""

cleanup() {
  if [ -n "$USERCONFIG" ]; then
    rm -f "$USERCONFIG"
  fi
}
trap cleanup EXIT

if npm view "${PACKAGE_NAME}@${PACKAGE_VERSION}" version --registry="$REGISTRY" >/dev/null 2>&1; then
  echo "${PACKAGE_NAME}@${PACKAGE_VERSION} already published; skip npm publish"
  exit 0
fi

# Install dev deps (typescript + @types/node) and build dist/ before publishing.
# `--include=dev` guards against environments with `omit=dev` set globally (e.g.
# some CI sandboxes), which would otherwise skip typescript and break the build.
echo "building ${PACKAGE_NAME}@${PACKAGE_VERSION}…"
(cd "./${PACKAGE_DIR}" && npm install --include=dev && npm run clean && npm run build)
chmod +x "./${PACKAGE_DIR}/dist/cli.js"

publish_args=(--registry="$REGISTRY")
if [ -n "${NPM_PUBLISH_TOKEN:-}" ]; then
  USERCONFIG="$(mktemp)"
  registry_host="${REGISTRY#http://}"
  registry_host="${registry_host#https://}"
  registry_host="${registry_host%/}"
  printf '//%s/:_authToken=%s\n' "$registry_host" "$NPM_PUBLISH_TOKEN" > "$USERCONFIG"
  npm publish "./${PACKAGE_DIR}" --registry="$REGISTRY" --userconfig "$USERCONFIG"
else
  # Uses the caller's `npm login` session.
  (cd "./${PACKAGE_DIR}" && npm publish --registry="$REGISTRY")
fi

echo "published ${PACKAGE_NAME}@${PACKAGE_VERSION}"
