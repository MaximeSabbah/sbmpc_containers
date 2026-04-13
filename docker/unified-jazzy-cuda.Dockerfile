# syntax=docker/dockerfile:1.6
ARG BASE_IMAGE=osrf/ros:jazzy-desktop
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ARG ROS_DISTRO=jazzy
ARG USERNAME=sbmpc
ARG USER_UID=1000
ARG USER_GID=1000

ENV ROS_DISTRO=${ROS_DISTRO}
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ENV RCUTILS_COLORIZED_OUTPUT=1
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics
ENV PIXI_HOME=/opt/pixi
ENV PATH=/opt/pixi/bin:${PATH}
ENV CCACHE_DIR=/ccache
ENV ROS2_WS=/workspace/ros2_ws

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash-completion \
    build-essential \
    ca-certificates \
    ccache \
    cmake \
    curl \
    git \
    gnupg \
    htop \
    iproute2 \
    iputils-ping \
    less \
    locales \
    lsb-release \
    nano \
    net-tools \
    ninja-build \
    pkg-config \
    python3-colcon-common-extensions \
    python3-pip \
    python3-rosdep \
    python3-vcstool \
    python3-venv \
    sudo \
    tmux \
    unzip \
    vim \
    wget \
    ros-${ROS_DISTRO}-controller-manager \
    ros-${ROS_DISTRO}-joint-state-broadcaster \
    ros-${ROS_DISTRO}-joint-state-publisher \
    ros-${ROS_DISTRO}-robot-state-publisher \
    ros-${ROS_DISTRO}-ros-gz \
    ros-${ROS_DISTRO}-ros2-control \
    ros-${ROS_DISTRO}-ros2-controllers \
    ros-${ROS_DISTRO}-rviz2 \
    ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
    ros-${ROS_DISTRO}-xacro \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then rosdep init; fi \
    && rosdep update --rosdistro ${ROS_DISTRO}

RUN curl -fsSL https://pixi.sh/install.sh | PIXI_HOME=${PIXI_HOME} bash \
    && ln -sf ${PIXI_HOME}/bin/pixi /usr/local/bin/pixi \
    && pixi --version

RUN if ! getent group ${USER_GID} >/dev/null; then groupadd --gid ${USER_GID} ${USERNAME}; fi \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} -s /bin/bash \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

WORKDIR /opt/sbmpc_deps_ws
COPY repos/franka_lfc_jazzy.repos /tmp/franka_lfc_jazzy.repos

RUN mkdir -p src \
    && vcs import --shallow --recursive src < /tmp/franka_lfc_jazzy.repos \
    && if [ -f src/franka_ros2/dependency.repos ]; then \
         vcs import --shallow --recursive src < src/franka_ros2/dependency.repos; \
       fi

RUN source /opt/ros/${ROS_DISTRO}/setup.bash \
    && apt-get update \
    && rosdep install --from-paths src --ignore-src -y --rosdistro ${ROS_DISTRO} \
    && rm -rf /var/lib/apt/lists/*

RUN source /opt/ros/${ROS_DISTRO}/setup.bash \
    && colcon build --symlink-install \
       --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DBUILD_TESTS=OFF

RUN mkdir -p /workspace /workspace/ros2_ws/src /ccache \
    && chown -R ${USERNAME}:${USERNAME} /workspace /ccache /opt/sbmpc_deps_ws

RUN cat >/ros_entrypoint_sbmpc.sh <<'EOF'
#!/usr/bin/env bash
set -e

source /opt/ros/${ROS_DISTRO}/setup.bash
if [ -f /opt/sbmpc_deps_ws/install/setup.bash ]; then
  source /opt/sbmpc_deps_ws/install/setup.bash
fi
mkdir -p "${ROS2_WS}/src"
if [ -f "${ROS2_WS}/install/setup.bash" ]; then
  source "${ROS2_WS}/install/setup.bash"
fi

exec "$@"
EOF
RUN chmod +x /ros_entrypoint_sbmpc.sh

USER ${USERNAME}
WORKDIR /workspace/ros2_ws

RUN printf '\nexport ROS2_WS=/workspace/ros2_ws\nsource /opt/ros/${ROS_DISTRO}/setup.bash\nif [ -f /opt/sbmpc_deps_ws/install/setup.bash ]; then source /opt/sbmpc_deps_ws/install/setup.bash; fi\nif [ -f ${ROS2_WS}/install/setup.bash ]; then source ${ROS2_WS}/install/setup.bash; fi\n' >> /home/${USERNAME}/.bashrc

ENTRYPOINT ["/ros_entrypoint_sbmpc.sh"]
CMD ["bash"]
