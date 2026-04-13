#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
COMPOSE_FILE="${REPO_ROOT}/compose/dev.yaml"

export SBMPC_PANDA_DIR=${SBMPC_PANDA_DIR:-${REPO_ROOT}/../sbmpc-panda}
export SBMPC_ROS_DIR=${SBMPC_ROS_DIR:-${REPO_ROOT}/../sbmpc_ros}

if [ ! -d "${SBMPC_PANDA_DIR}" ] && [ -d "${REPO_ROOT}/../sbmpc" ]; then
  export SBMPC_PANDA_DIR="${REPO_ROOT}/../sbmpc"
fi

exec docker compose -f "${COMPOSE_FILE}" exec sbmpc-dev bash
