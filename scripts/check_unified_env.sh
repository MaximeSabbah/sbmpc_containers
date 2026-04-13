#!/usr/bin/env bash
set -eo pipefail

source /opt/ros/${ROS_DISTRO:-jazzy}/setup.bash
if [ -f /opt/sbmpc_deps_ws/install/setup.bash ]; then
  source /opt/sbmpc_deps_ws/install/setup.bash
fi
set -u

ROS2_WS=${ROS2_WS:-/workspace/ros2_ws}

echo "== ROS =="
echo "ROS_DISTRO=${ROS_DISTRO:-unset}"
ros2 pkg prefix rclpy >/dev/null
python3 --version
python3 - <<'PY'
import rclpy
print('rclpy import: ok')
PY

echo "== LFC packages =="
ros2 pkg prefix linear_feedback_controller
ros2 pkg prefix linear_feedback_controller_msgs

echo "== Franka Description =="
ros2 pkg prefix franka_description
if [ -d /opt/sbmpc_deps_ws/src/franka_description/.git ]; then
  git -C /opt/sbmpc_deps_ws/src/franka_description remote get-url origin
fi

echo "== ROS workspace =="
echo "ROS2_WS=${ROS2_WS}"
mkdir -p "${ROS2_WS}/src"
if [ -d "${ROS2_WS}/src/sbmpc_ros" ]; then
  cd "${ROS2_WS}"
  colcon list --base-paths src
else
  echo "Skipping sbmpc_ros workspace listing: ${ROS2_WS}/src/sbmpc_ros is not mounted."
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  echo "== NVIDIA =="
  nvidia-smi
else
  echo "nvidia-smi not found in PATH; JAX GPU validation may still work through CUDA wheels."
fi

if [ -d /workspace/sbmpc ]; then
  echo "== sbmpc Pixi environment =="
  cd /workspace/sbmpc
  pixi install -e cuda
  PIXI_PYTHONPATH=$(pixi run -e cuda python -c 'import sysconfig; paths=sysconfig.get_paths(); print(":".join(dict.fromkeys([paths["purelib"], paths["platlib"]])))')
  export PYTHONPATH="${PIXI_PYTHONPATH}:${PYTHONPATH:-}:/usr/lib/python3/dist-packages:/usr/local/lib/python3.12/dist-packages"
  pixi run -e cuda python - <<'PY'
import jax
print('jax backend:', jax.default_backend())
print('jax devices:', jax.devices())
PY
  pixi run -e cuda python - <<'PY'
import pinocchio
import sbmpc
import jaxsim
import mujoco
print('pinocchio path:', pinocchio.__file__)
print('sbmpc import: ok')
print('jaxsim import: ok')
print('mujoco import: ok')
PY
  pixi run -e cuda python - <<'PY'
import rclpy
from linear_feedback_controller_msgs.msg import Control
print('pixi ROS import: ok')
print('pixi LFC Control msg import: ok')
PY
  pixi run -e cuda python -m pytest tests/test_mppi_gains.py tests/test_panda_pregrasp.py -q
else
  echo "Skipping sbmpc checks: /workspace/sbmpc is not mounted."
fi
