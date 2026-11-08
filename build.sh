#!/usr/bin/env bash

set -e

ROOT_DIR=$(
  cd $(dirname ${BASH_SOURCE[0]})
  pwd
)

# CCC_VERSION lives in npm/.env — the single source of truth shared with
# npm/compose.yml (image tag) and scripts/publish-npm.sh (npm version).
# Override ad hoc with: CCC_VERSION=1.7 ./build.sh  or  CCC_TAG=foo ./build.sh
CCC_ENV_FILE="${ROOT_DIR}/npm/.env"

# A real environment variable must win over the .env file (the same precedence
# docker compose uses), so stash any caller-supplied value and restore it after
# sourcing — otherwise `source` would silently clobber the override.
CCC_VERSION_OVERRIDE="${CCC_VERSION:-}"
if [[ -f "${CCC_ENV_FILE}" ]]; then
  set -a
  source "${CCC_ENV_FILE}"
  set +a
fi
if [[ -n "${CCC_VERSION_OVERRIDE}" ]]; then
  CCC_VERSION="${CCC_VERSION_OVERRIDE}"
fi

CCC_REPO="jiangsier/ccc"
CCC_TAG="${CCC_TAG:-${CCC_VERSION:-1.6}}"
CCC_COMPOSE_CONFIG=$(mktemp -d)/build.yml

trap "rm -f ${CCC_COMPOSE_CONFIG}" EXIT

builder=$(docker buildx ls | grep "^multiple-platforms-builder" | awk '{print $1}')
if [[ -z "${builder}" ]]; then
  docker buildx create --name multiple-platforms-builder --driver docker-container --bootstrap
fi

cat >>${CCC_COMPOSE_CONFIG} <<EOF
services:
  ccc:
    build:
      context: "${ROOT_DIR}"
      dockerfile: "${ROOT_DIR}/Dockerfile"
      tags:
        - ${CCC_REPO}:${CCC_TAG}
      platforms:
        - linux/amd64
        - linux/arm64
    image: ${CCC_REPO}:latest
EOF

echo "==> Building Docker image: ${CCC_REPO}:${CCC_TAG}"

DOCKER_BUILDKIT=1 docker compose \
  -f ${CCC_COMPOSE_CONFIG} \
  -p ccc \
  build \
  --builder multiple-platforms-builder \
  --push ccc
