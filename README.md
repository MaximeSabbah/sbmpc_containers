# sbmpc_containers

Container definitions for deploying the `sbmpc` controller with ROS 2, Gazebo, Franka ROS 2, and `linear-feedback-controller` in one environment.

The important constraint is Python compatibility. `sbmpc` currently requires Python 3.12 and JAX >= 0.8, so this repo targets ROS 2 Jazzy on Ubuntu 24.04. ROS 2 Humble uses Python 3.10 and is not a good single-process target for the future `sbmpc_ros` bridge.

## What This Image Provides

The unified image is intended to be the base for simulation and later robot-side deployment:

- ROS 2 Jazzy desktop tooling.
- Gazebo / `ros_gz` integration packages available from ROS apt packages.
- `ros2_control`, `ros2_controllers`, controller manager, and visualization utilities.
- `linear-feedback-controller` built from source.
- `linear-feedback-controller-msgs` built from source.
- `franka_ros2` built from source from its Jazzy branch, plus its upstream dependencies imported from `dependency.repos`.
- Pixi installed globally, so `sbmpc` can keep using its own Pixi environment.
- NVIDIA container runtime support through Docker `--gpus all` / Compose `gpus: all`.

The image does not copy `sbmpc` into the build by default. It mounts your local checkout into `/workspace/sbmpc`, which keeps iteration fast and avoids rebuilding the ROS image every time controller code changes.

The canonical ROS workspace inside the dev container is `/workspace/ros2_ws`. The
`sbmpc_ros` checkout is mounted into `/workspace/ros2_ws/src/sbmpc_ros`, so
`build/`, `install/`, and `log/` live under the workspace root instead of inside
the Git repository.

Inside the container, use only:

```bash
/workspace/ros2_ws/src/sbmpc_ros
```

as the `sbmpc_ros` source path. The older compatibility mount at
`/workspace/sbmpc_ros` has been removed to avoid ambiguity.

## Repository Layout

- `docker/unified-jazzy-cuda.Dockerfile`: the main image definition.
- `repos/franka_lfc_jazzy.repos`: source repositories imported into the ROS workspace.
- `compose/dev.yaml`: development container with host networking, GPU access, X11, local source mounts, and a dedicated `/workspace/ros2_ws` colcon workspace.
- `scripts/build_unified.sh`: builds the image.
- `scripts/setup_ros2_ws.sh`: creates the host-side `ros2_ws` directory used for colcon artifacts.
- `scripts/run_dev.sh`: starts and enters the development container.
- `scripts/enter.sh`: enters an already running development container.
- `scripts/check_unified_env.sh`: verifies ROS, LFC, GPU/JAX, and `sbmpc` integration from inside the container.
- `scripts/pixi_ros_run.sh`: runs Pixi commands with ROS sourced while keeping Pixi packages ahead of ROS Python packages.

## Prerequisites

Install on the host:

- Docker Engine with the Compose v2 plugin.
- NVIDIA Container Toolkit for GPU access.
- X11 access if you want Gazebo/RViz windows from the container.

For GPU validation, this should work on the host before using the image:

```bash
docker run --rm --gpus all nvidia/cuda:12.6.3-base-ubuntu24.04 nvidia-smi
```

## Build

From this repository:

```bash
./scripts/build_unified.sh
```

This builds `sbmpc/unified-jazzy-cuda:latest` by default. The build imports and compiles Franka ROS 2 and LFC sources in `/opt/sbmpc_deps_ws`.

You can override the base image if needed:

```bash
BASE_IMAGE=osrf/ros:jazzy-desktop IMAGE_NAME=sbmpc/unified-jazzy-cuda:latest ./scripts/build_unified.sh
```

## Run

The default compose file expects this directory structure:

```text
/home/msabbah/Desktop/
  sbmpc_containers/
  sbmpc/
  sbmpc_ros/
  ros2_ws/
```

`scripts/run_dev.sh` creates `ros2_ws/src` automatically if it does not already
exist and wires `ros2_ws/src/sbmpc_ros` to your host checkout.

Start and enter the container:

```bash
./scripts/run_dev.sh
```

If your `sbmpc` checkout is elsewhere, pass an absolute path:

```bash
SBMPC_DIR=/path/to/sbmpc ./scripts/run_dev.sh
```

You can also override the ROS workspace artifact directory:

```bash
ROS2_WS_DIR=/path/to/ros2_ws ./scripts/run_dev.sh
```

Inside the container, validate the full environment:

```bash
/workspace/sbmpc_containers/scripts/check_unified_env.sh
```

The check script verifies that ROS 2, LFC packages, and `sbmpc` Pixi/JAX CUDA setup can coexist in the same container.

## Expected `sbmpc_ros` Workflow

Inside the container:

```bash
cd /workspace/ros2_ws
colcon build --symlink-install --packages-select sbmpc_ros_bridge
colcon test --packages-select sbmpc_ros_bridge --event-handlers console_direct+
colcon test-result --verbose
```

The canonical `sbmpc_ros` source path inside the container is:

- `/workspace/ros2_ws/src/sbmpc_ros`

## Expected `sbmpc` Workflow

Inside the container:

```bash
cd /workspace/sbmpc
pixi install -e cuda
pixi run -e cuda python -m pytest tests/test_mppi_gains.py tests/test_panda_pregrasp.py -q
pixi run -e cuda python examples/panda_pick_and_place.py --gains
```

When ROS is sourced and you need to run `sbmpc` from Pixi, prefer the wrapper so Pixi's Pinocchio wins over ROS Pinocchio on `PYTHONPATH`:

```bash
/workspace/sbmpc_containers/scripts/pixi_ros_run.sh python -c "import rclpy, sbmpc; print('ok')"
```

For GUI simulation, make sure host X11 access is enabled. `scripts/run_dev.sh` calls `xhost +local:docker` when `DISPLAY` is set.

## Design Decision: One Unified Container

This repo intentionally avoids a two-container split. The future `sbmpc_ros` process needs to publish feedforward torques and Riccati gains to LFC message types while running the same controller code used in simulation. Keeping ROS 2 Jazzy, LFC, Franka ROS 2, and `sbmpc` in one image removes Python-version and IPC boundary problems.

If the image grows too heavy, the next optimization should be multi-stage Docker builds or a separate runtime target in the same Dockerfile, not splitting controller and ROS into separate containers.

## Known Build Risks

- Franka ROS 2 and LFC are source dependencies; upstream Jazzy changes can break builds. The LFC repositories are pinned to released tags, while `franka_ros2` follows its `jazzy` branch.
- Some Gazebo/Franka packages require graphics or `/dev/dri` access for interactive simulation. The compose file mounts X11 and `/dev/dri` for this reason.
- JAX CUDA support is provided by the `sbmpc` Pixi environment plus the NVIDIA container runtime. If JAX does not see the GPU, first verify `nvidia-smi` inside the container, then rerun the Pixi CUDA environment checks.
