#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

export ROS2_WS_DIR=${ROS2_WS_DIR:-${REPO_ROOT}/../ros2_ws}

mkdir -p "${ROS2_WS_DIR}/src"

cat <<EOF
Prepared ROS 2 workspace:
  ROS2_WS_DIR=${ROS2_WS_DIR}

This directory is the canonical colcon workspace root.
Source repositories are mounted into /workspace/ros2_ws/src inside the dev container,
while build/, install/, and log/ stay under the workspace root.
EOF
