#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

IMAGE_NAME=${IMAGE_NAME:-sbmpc/unified-jazzy-cuda:latest}
BASE_IMAGE=${BASE_IMAGE:-osrf/ros:jazzy-desktop}
USER_UID=${USER_UID:-$(id -u)}
USER_GID=${USER_GID:-$(id -g)}
USERNAME=${USERNAME:-sbmpc}

cd "${REPO_ROOT}"

docker build \
  --file docker/unified-jazzy-cuda.Dockerfile \
  --tag "${IMAGE_NAME}" \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --build-arg USER_UID="${USER_UID}" \
  --build-arg USER_GID="${USER_GID}" \
  --build-arg USERNAME="${USERNAME}" \
  .
