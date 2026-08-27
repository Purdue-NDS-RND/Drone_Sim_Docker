# Using the simulator

## Start and stop

Start QGroundControl normally on the host, open a terminal in the project, and run:

```bash
./run.sh
```

Wait for the Iris to appear in Gazebo and for QGC to report **Ready to Fly**. Stop everything with `Ctrl+C` in the same terminal. The shutdown handler stops Gazebo, ArduPilot SITL, MAVProxy, and the container.

## Guided takeoff with QGroundControl

1. Open QGC's **Fly** view and wait for **Ready to Fly**.
2. Select **Guided** from the flight-mode selector.
3. Choose **Arm** and confirm it.
4. Choose **Takeoff**, enter `5 m`, and confirm.
5. Watch the Iris climb in Gazebo and its altitude change in QGC.
6. Choose **Land** when finished. The vehicle should disarm after landing.

If QGC rejects an action, open its vehicle-messages panel. ArduPilot normally explains the exact pre-arm or mode-change problem there.

## Open an interactive MAVProxy console

Leave `./run.sh` running and open a second terminal in the project:

```bash
docker compose exec simulator /opt/ardupilot-python/bin/mavproxy.py \
  --master=udp:127.0.0.1:14551 \
  --no-state
```

When it shows a prompt such as `STABILIZE>`, try:

```text
mode guided
arm throttle
takeoff 5
mode land
```

Press `Ctrl+C` to close this extra console. The optional `adsb` module warning is harmless for this Iris simulation. Only one program should listen on UDP 14551 at a time, so close this console before starting your own program.

## Connect a Python program with pymavlink

Create a host virtual environment once:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install pymavlink
```

Minimal listener:

```python
from pymavlink import mavutil

vehicle = mavutil.mavlink_connection("udpin:127.0.0.1:14551")
vehicle.wait_heartbeat(timeout=30)
print(f"Connected to system {vehicle.target_system}")
```

Run it while the simulation is active. Port 14551 carries an independent MAVLink stream, so QGC can remain connected on 14550.

## Connect with MAVSDK-Python

MAVSDK uses the same student port:

```python
await drone.connect(system_address="udpin://0.0.0.0:14551")
```

## Logs

Every run creates timestamped files under `logs/`. The file `logs/last-run.txt` identifies the newest set. Useful files include:

- `gazebo-*.log` for the 3D simulator and plugin;
- `sim-vehicle-*.log` for simulator startup and MAVProxy;
- `arducopter-*.log` for the flight controller and JSON connection;
- `mavlink-*.tlog` for telemetry;
- `state/` for persistent parameters and ArduPilot DataFlash logs.

Because the container runs as your Linux user, you can open, copy, or delete these files without `sudo`.
