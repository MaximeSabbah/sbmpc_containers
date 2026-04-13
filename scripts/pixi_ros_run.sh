#!/usr/bin/env bash
set -eo pipefail

source /opt/ros/${ROS_DISTRO:-jazzy}/setup.bash
if [ -f /opt/sbmpc_deps_ws/install/setup.bash ]; then
  source /opt/sbmpc_deps_ws/install/setup.bash
fi
if [ -f /workspace/ros2_ws/install/setup.bash ]; then
  source /workspace/ros2_ws/install/setup.bash
fi
set -u

PIXI_ENV=${PIXI_ENV:-cuda}
SBMPC_DIR=${SBMPC_DIR:-/workspace/sbmpc}

if [ ! -d "${SBMPC_DIR}" ]; then
  echo "Missing sbmpc checkout: ${SBMPC_DIR}" >&2
  exit 1
fi

cd "${SBMPC_DIR}"
pixi install -e "${PIXI_ENV}"

PIXI_PYTHONPATH=$(pixi run -e "${PIXI_ENV}" python -c 'import sysconfig; paths=sysconfig.get_paths(); print(":".join(dict.fromkeys([paths["purelib"], paths["platlib"]])))')
export PYTHONPATH="${PIXI_PYTHONPATH}:${PYTHONPATH:-}:/usr/lib/python3/dist-packages:/usr/local/lib/python3.12/dist-packages"

exec pixi run -e "${PIXI_ENV}" "$@"
