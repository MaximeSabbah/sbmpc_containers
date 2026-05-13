# sbmpc_containers

Container definitions for deploying the `sbmpc` controller with ROS 2, MuJoCo, Franka ROS 2, and `linear-feedback-controller` in one environment.

The important constraint is Python compatibility. `sbmpc` currently requires Python 3.12 and JAX >= 0.8, so this repo targets ROS 2 Jazzy on Ubuntu 24.04. ROS 2 Humble uses Python 3.10 and is not a good single-process target for the future `sbmpc_ros` bridge.

## What This Image Provides

The unified image is intended to be the base for simulation and later robot-side deployment:

- ROS 2 Jazzy desktop tooling.
- `mujoco_ros2_control` built from the pinned source manifest in `repos/mujoco_ros2_control.repos`.
- `ros2_control`, `ros2_controllers`, controller manager, and visualization utilities.
- `linear-feedback-controller` built from source.
- `linear-feedback-controller-msgs` built from source.
- `franka_ros2` built from source from its Jazzy branch, plus its upstream dependencies imported from `dependency.repos`.
- `franka_description` intentionally replaced with the Agimus fork from `agimus-project/agimus-franka-description`, while preserving the ROS package name `franka_description`.
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
`/workspace/sbmpc_ros` is also restored as a legacy compatibility path for tools
that still expect it, but `/workspace/ros2_ws/src/sbmpc_ros` remains the
canonical source path for development and colcon builds.

If you started your current dev container before this compatibility mount was
added, restart it once so `/workspace/sbmpc_ros` becomes a real bind mount
instead of an older symlink chain that may resolve outside `/workspace` and
confuse VSCode.

## Repository Layout

- `docker/unified-jazzy-cuda.Dockerfile`: the main image definition.
- `repos/franka_lfc_jazzy.repos`: Franka and LFC source repositories imported into the dependency workspace.
- `repos/agimus_franka_description.repos`: override manifest used to replace upstream `franka_description` with the Agimus fork.
- `repos/mujoco_ros2_control.repos`: pinned MuJoCo ros2_control source dependency.
- `compose/dev.yaml`: development container with host networking, GPU access, X11, local source mounts, and a dedicated `/workspace/ros2_ws` colcon workspace.
- `scripts/build_unified.sh`: builds the image.
- `scripts/setup_ros2_ws.sh`: creates the host-side `ros2_ws` directory used for colcon artifacts.
- `scripts/run_dev.sh`: starts and enters the development container.
- `scripts/enter.sh`: enters an already running development container.
- `scripts/check_unified_env.sh`: verifies ROS, LFC, GPU/JAX, and `sbmpc` integration from inside the container.
- `scripts/pixi_ros_run.sh`: runs Pixi commands with ROS sourced while keeping Pixi packages ahead of ROS Python packages.

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

This check covers:

- ROS 2 Jazzy imports.
- `linear_feedback_controller` and message packages.
- the Agimus `franka_description` replacement.
- NVIDIA/JAX CUDA visibility.
- Python `mujoco`, MJX, Pinocchio, `jaxsim`, and `sbmpc` imports.
- ROS imports from inside the `sbmpc` Pixi CUDA environment.

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

## What Is Recreated By The Container

The Docker image builds and installs these ROS-side dependencies in
`/opt/sbmpc_deps_ws`:

- ROS 2 Jazzy desktop base.
- `franka_ros2` and its upstream dependencies.
- `linear-feedback-controller`.
- `linear-feedback-controller-msgs`.
- Agimus `franka_description`, replacing the upstream package while keeping the
  ROS package name.
- `mujoco_vendor` and `mujoco_ros2_control`.

The image also installs Pixi globally. The actual `sbmpc` Python/JAX/MuJoCo
environment is not baked into the image; it is installed from the mounted
`/workspace/sbmpc` checkout through `pixi install -e cuda`. This uses the
`sbmpc` `pyproject.toml` and `pixi.lock`, so a fresh PC does not need a manual
Python, JAX, Pinocchio, or MuJoCo setup.

In particular:

- live MuJoCo ROS simulation uses `mujoco_vendor` and `mujoco_ros2_control`
  from the Docker image.
- controller-side Python MuJoCo/MJX uses the `mujoco-mjx` dependency from the
  `sbmpc` Pixi environment.
- visualization/replay uses the same Pixi/ROS wrapper scripts as the current
  development PC.

## Reproducibility Notes

For practical deployment, the important source checkouts are:

- `sbmpc_containers`
- `sbmpc`
- `sbmpc_ros`

Those should be checked out to the same commits that were tested on the
development PC. The container build also imports third-party dependencies from
the `.repos` files in this repository. Some entries are version tags, while
some intentionally track active branches such as `franka_ros2` `jazzy` and the
Agimus `franka_description` `main` branch. Once robot bringup is stable, pin
those moving entries to exact commits before rebuilding the robot PC image if
bit-for-bit reproducibility is required.

## Build

From this repository:

```bash
./scripts/build_unified.sh
```

This builds `sbmpc/unified-jazzy-cuda:latest` by default. The build imports and compiles Franka ROS 2 and LFC sources in `/opt/sbmpc_deps_ws`, then replaces the upstream `franka_description` dependency with the Agimus fork before building.

You can override the base image if needed:

```bash
BASE_IMAGE=osrf/ros:jazzy-desktop IMAGE_NAME=sbmpc/unified-jazzy-cuda:latest ./scripts/build_unified.sh
```

## Run

The default compose file expects `sbmpc_containers`, `sbmpc`, `sbmpc_ros`, and
`ros2_ws` to be siblings:

```text
~/sbmpc_stack/
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
It also prints the `franka_description` package path and source remote so you can confirm the Agimus replacement is active.

## Expected `sbmpc_ros` Workflow

Inside the container:

```bash
cd /workspace/ros2_ws
colcon build --symlink-install --packages-select sbmpc_ros_bridge sbmpc_bringup
colcon test --packages-select sbmpc_ros_bridge sbmpc_bringup --event-handlers console_direct+
colcon test-result --verbose
```

The canonical `sbmpc_ros` source path inside the container is:

- `/workspace/ros2_ws/src/sbmpc_ros`

The legacy compatibility mount is also available when older scripts expect it:

- `/workspace/sbmpc_ros`

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

For GUI simulation, make sure host X11 access is enabled. MuJoCo validation can run headless, and `scripts/run_dev.sh` calls `xhost +local:docker` when `DISPLAY` is set.

For an SSH-forwarded session from your laptop to a lab machine:

```bash
ssh -Y your_user@hako
cd /path/to/sbmpc_containers
./scripts/run_dev.sh
```

`run_dev.sh` now forwards your Xauthority cookie into the container as well as
`DISPLAY`, which is required for GUI apps launched from inside Docker to use the
SSH-forwarded X server on your laptop.

The `sbmpc_franka_lfc_mujoco_sim.launch.py` and `sbmpc_franka_lfc_real.launch.py`
bridge actions launch the planner node through `scripts/pixi_ros_run.sh`
automatically. You can still override the runtime with launch arguments such as
`sbmpc_dir:=...`, `pixi_env:=...`, and
`bridge_runtime_script:=/workspace/sbmpc_containers/scripts/pixi_ros_run.sh`.

Practical advice:

- `rviz2` over SSH X11 is usually workable for short checks.
- full GUI simulation over SSH X11 can be very slow or unstable, especially with 3D rendering.
- the more robust option for “seeing the robot” from home is a remote desktop path on `hako` such as TurboVNC, NoMachine, Xpra, or an existing lab desktop session, then running the Docker container from inside that desktop session.
- for quick non-visual validation from SSH only, prefer the headless launch:

```bash
cd /workspace/ros2_ws
source install/setup.bash
ros2 launch sbmpc_bringup sbmpc_franka_lfc_mujoco_sim.launch.py \
  headless:=true enable_nonzero_control:=true
```

## Design Decision: One Unified Container

This repo intentionally avoids a two-container split. The future `sbmpc_ros` process needs to publish feedforward torques and Riccati gains to LFC message types while running the same controller code used in simulation. Keeping ROS 2 Jazzy, LFC, Franka ROS 2, and `sbmpc` in one image removes Python-version and IPC boundary problems.

If the image grows too heavy, the next optimization should be multi-stage Docker builds or a separate runtime target in the same Dockerfile, not splitting controller and ROS into separate containers.

## Known Build Risks

- Franka ROS 2 and LFC are source dependencies; upstream Jazzy changes can break builds. The LFC repositories are pinned to released tags, while `franka_ros2` follows its `jazzy` branch and the Agimus `franka_description` override follows `main`.
- Some Franka and simulation tools require graphics or `/dev/dri` access for interactive visualization. The compose file mounts X11, forwards Xauthority, and exposes `/dev/dri` for this reason.
- JAX CUDA support is provided by the `sbmpc` Pixi environment plus the NVIDIA container runtime. If JAX does not see the GPU, first verify `nvidia-smi` inside the container, then rerun the Pixi CUDA environment checks.

If `rosdep install` reports unresolved keys such as `franka_description` or
`zed_wrapper`, make sure you have the Dockerfile revision that limits the
dependency workspace build to the packages SB-MPC actually uses and skips those
optional/source-provided rosdep keys.

If the build reaches `franka_example_controllers` and fails on missing
`moveit_core`, update to the Dockerfile revision that skips optional Franka
example/mobile/vision packages. They are not required for SB-MPC bringup.
