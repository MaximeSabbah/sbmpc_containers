# sbmpc_containers

Docker environment for SB-MPC development, MuJoCo simulation, and Franka real
robot bringup. The image provides ROS 2 Jazzy, Franka ROS 2,
`linear-feedback-controller`, MuJoCo ROS2-control, Pixi, and GPU access. The
`sbmpc` and `sbmpc_ros` repositories are mounted from the host for fast
iteration.

## Prerequisites

Install on the host robot PC:

- Docker Engine with the Compose v2 plugin.
- NVIDIA Container Toolkit for GPU access.
- A working NVIDIA driver. `nvidia-smi` must work on the host.
- Git.
- X11 access if you want MuJoCo/RViz windows from the container.

For GPU validation, this should work on the host before using the image:

```bash
docker run --rm --gpus all nvidia/cuda:12.6.3-base-ubuntu24.04 nvidia-smi
```

No host ROS, MuJoCo, Pixi, Franka ROS 2, or `linear-feedback-controller`
installation is required. Those are provided by the Docker image or by the
mounted `sbmpc` Pixi environment.

## Essential Commands

From the host, build the image and start the development container:

```bash
cd ~/sbmpc_stack/sbmpc_containers
./scripts/build_unified.sh
./scripts/run_dev.sh
```

Inside the container, run the environment check:

```bash
/workspace/sbmpc_containers/scripts/check_unified_env.sh
```

Build the local ROS overlay:

```bash
cd /workspace/ros2_ws
colcon build --symlink-install --packages-select sbmpc_ros_bridge sbmpc_bringup
source install/setup.bash
```

Launch the real Franka controller:

```bash
ros2 launch sbmpc_bringup sbmpc_franka_lfc_real.launch.py
```

Launch the headless MuJoCo simulation:

```bash
ros2 launch sbmpc_bringup sbmpc_franka_lfc_mujoco_sim.launch.py \
  headless:=true enable_nonzero_control:=true
```

## Fresh Robot PC Setup

Start from a directory that will contain the three source checkouts and the ROS
workspace artifacts:

```bash
mkdir -p ~/sbmpc_stack
cd ~/sbmpc_stack

git clone https://github.com/MaximeSabbah/sbmpc_containers.git
git clone https://github.com/MaximeSabbah/sbmpc.git
git clone https://github.com/MaximeSabbah/sbmpc_ros.git
mkdir -p ros2_ws
```

For the current controller work, use the same branches or commits that were
validated on the development PC before moving to the robot PC. The default
layout expected by `scripts/run_dev.sh` is:

```text
~/sbmpc_stack/
  sbmpc_containers/
  sbmpc/
  sbmpc_ros/
  ros2_ws/
```

Build the unified image:

```bash
cd ~/sbmpc_stack/sbmpc_containers
./scripts/build_unified.sh
```

Only continue to `run_dev.sh` if the image build succeeds. If the build fails,
there is no local `sbmpc/unified-jazzy-cuda:latest` image yet, and Docker will
try to pull that private/local image name from Docker Hub.

Start and enter the container:

```bash
./scripts/run_dev.sh
```

Inside the container, validate the full environment:

```bash
/workspace/sbmpc_containers/scripts/check_unified_env.sh
```

This checks ROS, LFC, the Agimus Franka description, GPU/JAX, MuJoCo/MJX,
and `sbmpc` imports.

Then build the local ROS overlay:

```bash
cd /workspace/ros2_ws
colcon build --symlink-install --packages-select sbmpc_ros_bridge sbmpc_bringup
source install/setup.bash
```

Run the real robot launch with the current default robot IP and conservative
40 Hz controller preset:

```bash
ros2 launch sbmpc_bringup sbmpc_franka_lfc_real.launch.py
```

The explicit equivalent is:

```bash
ros2 launch sbmpc_bringup sbmpc_franka_lfc_real.launch.py \
  robot_ip:=172.17.0.1 \
  bridge_params_file:=/workspace/sbmpc_ros/sbmpc_bringup/config/sbmpc_bridge_exact_async_40hz.yaml
```

To test another bridge preset without editing code:

```bash
ros2 launch sbmpc_bringup sbmpc_franka_lfc_real.launch.py \
  robot_ip:=172.17.0.1 \
  bridge_params_file:=/workspace/sbmpc_ros/sbmpc_bringup/config/sbmpc_bridge_exact_async.yaml
```

## Daily Commands

Enter an already running container:

```bash
cd ~/sbmpc_stack/sbmpc_containers
./scripts/enter.sh
```

Rebuild the ROS overlay after changing `sbmpc_ros`:

```bash
cd /workspace/ros2_ws
colcon build --symlink-install --packages-select sbmpc_ros_bridge sbmpc_bringup
source install/setup.bash
```

Run the headless MuJoCo simulation:

```bash
ros2 launch sbmpc_bringup sbmpc_franka_lfc_mujoco_sim.launch.py \
  headless:=true enable_nonzero_control:=true
```

Run commands in the `sbmpc` Pixi CUDA environment while keeping ROS available:

```bash
/workspace/sbmpc_containers/scripts/pixi_ros_run.sh python -c "import rclpy, sbmpc; print('ok')"
```

## Expected Container Layout

After `run_dev.sh`, these paths should exist inside the container:

```text
/workspace/ros2_ws
/workspace/ros2_ws/src/sbmpc_ros
/workspace/sbmpc
/workspace/sbmpc_containers
/workspace/sbmpc_ros
```

It is normal for `/workspace/ros2_ws` to contain only `src/` before the local
ROS overlay is built. The `build/`, `install/`, and `log/` directories appear
after running `colcon build`.

The Franka robot description comes from
`agimus-project/agimus-franka-description`. The ROS package name is
`agimus_franka_description`, and the image also provides a `franka_description`
compatibility alias for upstream Franka ROS 2 packages that still look up the
old package name. Both checks should resolve:

```bash
ros2 pkg prefix agimus_franka_description
ros2 pkg prefix franka_description
```

## Notes

- Do not install ROS, MuJoCo, Pixi, Franka ROS 2, or LFC manually on the host.
- If `build_unified.sh` fails, do not run `run_dev.sh` yet; no local image was
  created, so Docker will try to pull `sbmpc/unified-jazzy-cuda:latest`.
- Check out the same tested commits of `sbmpc_containers`, `sbmpc`, and
  `sbmpc_ros` on the robot PC.
