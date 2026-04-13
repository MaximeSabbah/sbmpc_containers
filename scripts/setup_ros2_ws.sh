#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

export ROS2_WS_DIR=${ROS2_WS_DIR:-${REPO_ROOT}/../ros2_ws}
export SBMPC_ROS_DIR=${SBMPC_ROS_DIR:-${REPO_ROOT}/../sbmpc_ros}

mkdir -p "${ROS2_WS_DIR}/src"

ROS_SRC_LINK="${ROS2_WS_DIR}/src/sbmpc_ros"
if [ -d "${SBMPC_ROS_DIR}" ]; then
  if [ -L "${ROS_SRC_LINK}" ] || [ ! -e "${ROS_SRC_LINK}" ]; then
    ln -sfn "${SBMPC_ROS_DIR}" "${ROS_SRC_LINK}"
  fi
fi

cat <<EOF
Prepared ROS 2 workspace:
  ROS2_WS_DIR=${ROS2_WS_DIR}
  SBMPC_ROS_DIR=${SBMPC_ROS_DIR}

This directory is the canonical colcon workspace root.
Develop sbmpc_ros from:
  /workspace/ros2_ws/src/sbmpc_ros

On the host, there is still one real Git checkout at:
  ${SBMPC_ROS_DIR}

The workspace keeps a symlink at:
  ${ROS_SRC_LINK}

Inside the dev container, the repo is mounted directly at
  /workspace/ros2_ws/src/sbmpc_ros

while build/, install/, and log/ stay under
  /workspace/ros2_ws
EOF
