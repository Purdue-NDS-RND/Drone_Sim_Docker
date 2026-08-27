FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG ARDUPILOT_VERSION=Copter-4.6.3
ARG ARDUPILOT_COMMIT=92b0cd788ec29406f26c6f9c31d5ceedbd1cc538
ARG ARDUPILOT_GAZEBO_COMMIT=082a0fe231f6e63bc8d1598f1cba461d9e2ea7f5

LABEL org.opencontainers.image.title="ArduPilot Gazebo Starter" \
      org.opencontainers.image.description="ArduPilot Copter SITL with the official Gazebo Harmonic plugin" \
      org.opencontainers.image.version="${ARDUPILOT_VERSION}" \
      io.ardupilot.commit="${ARDUPILOT_COMMIT}" \
      io.ardupilot.gazebo.commit="${ARDUPILOT_GAZEBO_COMMIT}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Gazebo Harmonic is officially packaged for Ubuntu 22.04 by OSRF.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        sudo \
    && curl -fsSL https://packages.osrfoundation.org/gazebo.gpg \
        -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] https://packages.osrfoundation.org/gazebo/ubuntu-stable jammy main" \
        > /etc/apt/sources.list.d/gazebo-stable.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        cmake \
        git \
        gz-harmonic \
        gstreamer1.0-gl \
        gstreamer1.0-libav \
        gstreamer1.0-plugins-bad \
        libgl1-mesa-dri \
        libglx-mesa0 \
        libgstreamer-plugins-base1.0-dev \
        libgstreamer1.0-dev \
        libgz-sim8-dev \
        libopencv-dev \
        mesa-utils \
        procps \
        rapidjson-dev \
        tini \
    && useradd --create-home --shell /bin/bash --uid 10001 builder \
    && usermod -aG sudo builder \
    && printf 'builder ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/builder \
    && chmod 0440 /etc/sudoers.d/builder \
    && mkdir -p /opt/ardupilot /opt/ardupilot-python \
    && chown builder:builder /opt/ardupilot /opt/ardupilot-python

ENV PYTHONUSERBASE=/opt/ardupilot-python
ENV PATH=/opt/ardupilot-python/bin:/opt/ardupilot/Tools/autotest:${PATH}

USER builder
WORKDIR /opt

# Clone the named stable tag, then verify its immutable commit before building.
RUN git clone --depth 1 --branch "${ARDUPILOT_VERSION}" --recurse-submodules \
        --shallow-submodules https://github.com/ArduPilot/ardupilot.git /opt/ardupilot \
    && test "$(git -C /opt/ardupilot rev-parse HEAD)" = "${ARDUPILOT_COMMIT}"

# Install the Jammy SITL-only subset of the pinned ArduPilot prerequisites.
# Embedded cross-compilers, coverage tools, and MAVProxy GUI modules are not
# needed for this image because QGroundControl runs natively on the host.
RUN sudo apt-get update \
    && sudo apt-get install -y --no-install-recommends \
        astyle \
        ccache \
        gawk \
        libtool \
        libxml2-dev \
        libxslt1-dev \
        ppp \
        python-is-python3 \
        python3-dev \
        python3-numpy \
        python3-pexpect \
        python3-pip \
        python3-psutil \
        python3-pyparsing \
        python3-setuptools \
        wget \
    && python3 -m pip install --user --no-cache-dir --upgrade \
        pip packaging setuptools wheel \
    && python3 -m pip install --user --no-cache-dir \
        future \
        lxml \
        pymavlink \
        pyserial \
        MAVProxy \
        geocoder \
        'empy==3.3.4' \
        ptyprocess \
        dronecan \
        tabulate

RUN cd /opt/ardupilot \
    && ./waf configure --board sitl \
    && ./waf build --target bin/arducopter

USER root
WORKDIR /opt

# ardupilot_gazebo has no release tags, so pin an exact tested commit.
RUN git init /opt/ardupilot_gazebo \
    && git -C /opt/ardupilot_gazebo remote add origin https://github.com/ArduPilot/ardupilot_gazebo.git \
    && git -C /opt/ardupilot_gazebo fetch --depth 1 origin "${ARDUPILOT_GAZEBO_COMMIT}" \
    && git -C /opt/ardupilot_gazebo checkout --detach FETCH_HEAD \
    && test "$(git -C /opt/ardupilot_gazebo rev-parse HEAD)" = "${ARDUPILOT_GAZEBO_COMMIT}" \
    && cmake -S /opt/ardupilot_gazebo -B /opt/ardupilot_gazebo/build \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    && cmake --build /opt/ardupilot_gazebo/build --parallel "$(nproc)" \
    && apt-get install -y --no-install-recommends libdebuginfod1 libqt5svg5 \
    && rm -f /etc/sudoers.d/builder \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 start-sim.sh /usr/local/bin/start-sim.sh
COPY --chmod=0755 sitl-process-wrapper.sh /usr/local/bin/sitl-process-wrapper.sh

ENV GZ_VERSION=harmonic \
    GZ_PARTITION=ardupilot_gazebo_starter \
    GZ_SIM_SYSTEM_PLUGIN_PATH=/opt/ardupilot_gazebo/build \
    GZ_SIM_RESOURCE_PATH=/opt/ardupilot_gazebo/models:/opt/ardupilot_gazebo/worlds \
    HOME=/sim/state \
    LOG_DIR=/sim \
    WORLD=iris_runway.sdf \
    MAVLINK_QGC=udp:127.0.0.1:14550 \
    MAVLINK_API=udp:127.0.0.1:14551 \
    SOFTWARE_RENDERING=0 \
    WIPE_PARAMS=0 \
    QT_X11_NO_MITSHM=1

WORKDIR /sim
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/start-sim.sh"]
