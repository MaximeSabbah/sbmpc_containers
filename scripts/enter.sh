#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
COMPOSE_FILE="${REPO_ROOT}/compose/dev.yaml"

export SBMPC_DIR=${SBMPC_DIR:-${REPO_ROOT}/../sbmpc}
export SBMPC_ROS_DIR=${SBMPC_ROS_DIR:-${REPO_ROOT}/../sbmpc_ros}
export ROS2_WS_DIR=${ROS2_WS_DIR:-${REPO_ROOT}/../ros2_ws}

exec docker compose -f "${COMPOSE_FILE}" exec -w /workspace/ros2_ws sbmpc-dev bash
