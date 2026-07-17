#!/usr/bin/env bash

set -e

ROOT_DIR=$(
  cd $(dirname ${BASH_SOURCE[0]})
  pwd
)
CCC_REPO="jiangsier/ccc"
CCC_TAG="1.5"
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
