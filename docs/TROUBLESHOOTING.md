# Troubleshooting

## Quick reset

Stop this project's container and start it again:

```bash
./run.sh --down
./run.sh
```

To reset ArduPilot's saved parameters once:

```bash
WIPE_PARAMS=1 ./run.sh
```

## Docker permission denied

```bash
sudo usermod -aG docker "$USER"
```

Log out and back in, then confirm `docker info` works without `sudo`.

## Docker reports `unsupported protocol: Yunix`

If Ubuntu is in the middle of an update, let it finish and reboot first. This error comes from the Docker/containerd runtime, not ArduPilot or Gazebo. After rebooting, verify:

```bash
docker info
docker run --rm hello-world
```

## `DISPLAY is empty` or Gazebo does not open

Run from a terminal inside your logged-in Ubuntu desktop, not from a text-only console. Check:

```bash
echo "$DISPLAY"
ls /tmp/.X11-unix
```

The project requires X11 or Xwayland. It deliberately does not use insecure commands such as `xhost +`.

## Xauthority error

Check that your desktop session has a cookie:

```bash
xauth nlist "$DISPLAY"
```

Logging out and back in usually repairs a stale display environment.

## Black Gazebo window or OpenGL/EGL error

Try software rendering:

```bash
SOFTWARE_RENDERING=1 ./run.sh
```

Hardware acceleration normally uses `/dev/dri` and your `video` and `render` groups. NVIDIA Container Toolkit configuration is optional; Intel/AMD Mesa or software rendering is the portable default.

## QGroundControl does not connect

QGC should listen on UDP 14550. In **Application Settings > Comm Links**, add a UDP link on port `14550` if auto-connect is disabled. Do not configure QGC on 14551 because that port is reserved for student code.

Check for another program already using the QGC port:

```bash
ss -lunp | grep 14550
```

## QGroundControl reports missing `ARMING_CHECK`

The default Copter 4.6.3 image includes this parameter. The warning usually means an old Copter 4.7 container is still running. Stop old containers, rebuild, and reset parameters once:

```bash
./run.sh --down
WIPE_PARAMS=1 ./run.sh --build
```

Do not invent the missing parameter or disable safety checks.

## Gazebo opens but ArduPilot does not connect

Run:

```bash
cat logs/last-run.txt
docker compose ps
docker compose logs simulator
```

The logs should show Gazebo starting `iris_runway.sdf`, the ArduPilot plugin loading, and SITL receiving data from its JSON backend. Stop any stale copy with `./run.sh --down`.

## Get more help

When asking another club member for help, include:

```bash
docker version
docker compose version
docker compose ps
cat logs/last-run.txt
```

Also describe whether Gazebo opened and copy the most recent relevant error from `logs/`.
