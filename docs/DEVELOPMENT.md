# How it works and how to maintain it

This guide contains details most students do not need for their first flight.

## Data flow

Gazebo calculates the Iris vehicle's motion and simulated sensor readings. The official `ardupilot_gazebo` plugin exchanges that data with ArduPilot through its JSON simulator backend. ArduPilot calculates motor commands, which the plugin sends back to Gazebo.

MAVProxy connects to SITL and sends two MAVLink copies:

- `udp:127.0.0.1:14550` for native QGroundControl;
- `udp:127.0.0.1:14551` for one student pymavlink, MAVSDK, or MAVProxy client.

Compose uses Linux `network_mode: host`, so the container shares the host's network namespace. That is why native QGC can use loopback and why no Docker ports are published. It is also one reason the project is intentionally Linux-specific.

## Display and GPU security

`run.sh` copies only the active display's MIT-MAGIC-COOKIE into a temporary mode-0600 Xauthority file. The container receives that file read-only along with the read-only X11 socket. Cleanup removes the cookie file when the run ends. The project never uses `xhost +`.

When `/dev/dri` exists, `compose.gpu.yaml` shares it with the container. `run.sh` detects the host UID, primary GID, `video` GID, and `render` GID so Gazebo can access graphics devices and generated logs remain owned by the student. `SOFTWARE_RENDERING=1` selects Mesa llvmpipe when hardware OpenGL is unavailable.

## Reproducible pins

- ArduPilot tag: `Copter-4.6.3`
- ArduPilot commit: `92b0cd788ec29406f26c6f9c31d5ceedbd1cc538`
- `ardupilot_gazebo` commit: `082a0fe231f6e63bc8d1598f1cba461d9e2ea7f5`
- Default image: `ardupilot-gz:4.6.3`
- Container: `ardupilot-gz-sim`

The Dockerfile checks that the release tag resolves to its expected immutable commit. A mismatched or moved tag fails instead of silently building different code.

## Configuration

Set variables immediately before `./run.sh`:

```bash
SOFTWARE_RENDERING=1 ./run.sh
WIPE_PARAMS=1 ./run.sh
WORLD=iris_runway.sdf MAVLINK_API=udp:127.0.0.1:14600 ./run.sh
```

| Variable | Default | Meaning |
|---|---|---|
| `WORLD` | `iris_runway.sdf` | Installed Gazebo world name or accessible path |
| `MAVLINK_QGC` | `udp:127.0.0.1:14550` | QGC MAVLink output |
| `MAVLINK_API` | `udp:127.0.0.1:14551` | Student MAVLink output |
| `SOFTWARE_RENDERING` | `0` | Use Mesa software rendering when set to `1` |
| `WIPE_PARAMS` | `0` | Reset SITL parameters on this start when set to `1` |
| `GAZEBO_STARTUP_TIMEOUT` | `90` | Seconds allowed for Gazebo's world clock to appear |
| `SIM_IMAGE` | `ardupilot-gz:4.6.3` | Docker image name/tag |

The startup script invokes the equivalent of:

```bash
sim_vehicle.py \
  -v ArduCopter \
  -f gazebo-iris \
  --model JSON \
  --no-rebuild \
  --no-extra-ports \
  --out=udp:127.0.0.1:14550 \
  --out=udp:127.0.0.1:14551
```

`--no-extra-ports` prevents MAVProxy's automatic outputs from duplicating the two explicit streams.

## Validation and rebuilds

```bash
make validate       # Shell syntax and resolved Compose configuration
make build          # Build without launching the graphical simulator
make run            # Start and reuse the existing image
make rebuild        # Rebuild every Docker layer without cache
make down           # Stop and remove the project container
```

To change pins, supply a matching tag and immutable commits, choose a distinct image tag, and force a build:

```bash
ARDUPILOT_VERSION=Copter-X.Y.Z \
ARDUPILOT_COMMIT=<40-character-commit> \
ARDUPILOT_GAZEBO_COMMIT=<40-character-commit> \
SIM_IMAGE=ardupilot-gz:X.Y.Z-custom \
./run.sh --build
```

After changing ArduPilot versions, use `WIPE_PARAMS=1` for the first start so saved parameters from a different firmware do not leak into the new test.

## Upstream references

- [ArduPilot SITL with Gazebo](https://ardupilot.org/dev/docs/sitl-with-gazebo.html)
- [Official ArduPilot Gazebo plugin](https://github.com/ArduPilot/ardupilot_gazebo)
- [Gazebo Harmonic on Ubuntu](https://gazebosim.org/docs/harmonic/install_ubuntu/)
- [QGroundControl releases](https://github.com/mavlink/qgroundcontrol/releases)
