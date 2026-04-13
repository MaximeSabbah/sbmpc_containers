#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
COMPOSE_FILE="${REPO_ROOT}/compose/dev.yaml"

if [ -n "${DISPLAY:-}" ] && [[ "${DISPLAY}" != localhost:* ]] && command -v xhost >/dev/null 2>&1; then
  xhost +local:docker >/dev/null
fi

export SBMPC_DIR=${SBMPC_DIR:-${REPO_ROOT}/../sbmpc}
export SBMPC_ROS_DIR=${SBMPC_ROS_DIR:-${REPO_ROOT}/../sbmpc_ros}
export ROS2_WS_DIR=${ROS2_WS_DIR:-${REPO_ROOT}/../ros2_ws}
export XAUTHORITY_HOST=${XAUTHORITY_HOST:-${XAUTHORITY:-${HOME}/.Xauthority}}
export XAUTHORITY_IN_CONTAINER=${XAUTHORITY_IN_CONTAINER:-/tmp/.docker.xauth}

if [ ! -f "${XAUTHORITY_HOST}" ]; then
  export XAUTHORITY_HOST=/dev/null
fi

if [ ! -d "${SBMPC_DIR}" ]; then
  echo "Missing sbmpc checkout: ${SBMPC_DIR}" >&2
  echo "Set SBMPC_DIR=/absolute/path/to/sbmpc and retry." >&2
  exit 1
fi

if [ ! -d "${SBMPC_ROS_DIR}" ]; then
  mkdir -p "${SBMPC_ROS_DIR}"
fi

"${REPO_ROOT}/scripts/setup_ros2_ws.sh"

docker compose -f "${COMPOSE_FILE}" up -d
exec docker compose -f "${COMPOSE_FILE}" exec -w /workspace/ros2_ws sbmpc-dev bash
