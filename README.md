# ArduPilot Gazebo Starter

Launch a complete virtual quadcopter with one command:

```bash
./run.sh
```

This project is meant for students who want to learn drone programming without first becoming Linux, Docker, or flight-controller experts. You do not need a physical drone. Gazebo displays and simulates an Iris quadcopter, ArduPilot flies it, and QGroundControl gives you the same kind of ground-station interface used with real vehicles.

## What you get

After startup:

- **Gazebo Harmonic** opens a 3D runway and an Iris quadcopter.
- **ArduPilot Copter SITL** acts as the flight controller. SITL means “software in the loop”: the real flight-control code runs on your computer instead of a flight-controller board.
- **QGroundControl** runs normally on your computer and automatically receives the simulated vehicle on UDP port `14550`.
- Your **Python or MAVSDK program** can independently use UDP port `14551`.
- Flight and diagnostic logs are saved under `logs/`.

QGroundControl is not placed inside Docker. Keeping the desktop application native makes it easier to update and use, while Docker handles the complicated simulator dependencies.

## Why Docker?

ArduPilot and Gazebo require many packages, build tools, environment variables, and compatible versions. Installing all of them directly can leave every club member with a slightly different system. Docker gives everyone the same tested simulator environment while still displaying Gazebo on the Linux desktop.

Docker helps this project provide:

- one setup that is reproducible across club computers;
- pinned software versions that do not unexpectedly change during a semester;
- no ROS 2 or other unrelated robotics packages on the host;
- simulator logs owned by the student, not by root;
- easy cleanup without uninstalling system-wide simulation libraries.

This design targets **native Ubuntu Linux**. It uses Linux host networking so QGroundControl and student programs can communicate with the container through `127.0.0.1`. It also shares the Linux display and GPU with Gazebo. Docker Desktop on macOS and Windows does not provide those pieces in the same way.

## Software choices

| Part | Version | Why it is here |
|---|---|---|
| Ubuntu container | 22.04 | Stable base supported by Gazebo Harmonic |
| Gazebo | Harmonic LTS (`gz-sim` 8.x) | 3D world, physics, sensors, and vehicle display |
| ArduPilot | Copter 4.6.3 | Stable flight firmware compatible with QGC 5.0.8 on Ubuntu 22.04 |
| ArduPilot Gazebo plugin | commit `082a0fe` | Connects Gazebo physics to ArduPilot's JSON simulator backend |
| QGroundControl | 5.0.8 on Ubuntu 22.04 | Native ground station for viewing and controlling the vehicle |
| MAVProxy | Included in the image | Routes MAVLink to QGC and student code; also provides a command console |

Copter 4.6.3 is intentional. Copter 4.7 renamed `ARMING_CHECK` to `ARMING_SKIPCHK`, but the QGC 5.0.8 AppImage that runs on Ubuntu 22.04 does not understand that change. The result was a misleading missing-parameter warning and unreliable Guided actions. Version 4.6.3 provides everything needed for introductory Guided flight, missions, pymavlink, and MAVSDK while avoiding that mismatch.

Gazebo Harmonic remains a modern, supported LTS release. The firmware choice does not require an older Gazebo version.

## Start here

1. Follow [Setup](docs/SETUP.md) once to install Docker, QGroundControl, and the small host dependencies.
2. Open a terminal in this project.
3. Start QGroundControl on the host.
4. Run:

```bash
./run.sh
```

The first build can take several minutes and use significant disk space. Later starts reuse the image named `ardupilot-gz:4.6.3`. The running container is named `ardupilot-gz-sim`.

Wait for Gazebo to show the Iris and for QGroundControl to say **Ready to Fly**. Stop the simulation with `Ctrl+C` in the terminal that ran `./run.sh`.

## Where to go next

- [Setup](docs/SETUP.md) — install prerequisites and QGroundControl.
- [Using the simulator](docs/USING_THE_SIM.md) — take off, use MAVProxy, and connect Python or MAVSDK.
- [Troubleshooting](docs/TROUBLESHOOTING.md) — fixes for Docker, graphics, QGC, and startup problems.
- [How it works and how to maintain it](docs/DEVELOPMENT.md) — networking, display security, version pins, configuration, and rebuilds.

## Project layout

```text
Drone_Sim_Docker/
├── Dockerfile              # Builds the pinned simulator environment
├── compose.yaml            # Describes the simulator container
├── compose.gpu.yaml        # Shares the host GPU when available
├── run.sh                  # Student-facing start command
├── start-sim.sh            # Starts and stops Gazebo, SITL, and MAVProxy
├── sitl-process-wrapper.sh # Captures SITL output and signals cleanly
├── Makefile                # Shortcuts such as make run and make validate
├── docs/                   # Setup, usage, troubleshooting, and design guides
└── logs/                   # Local runtime and flight logs
```

## Safety note

This is a simulation, but it uses real ArduPilot flight-control software and real MAVLink commands. Learn safe arming and mode-change habits here before applying anything to physical hardware. Never disable arming checks on a real aircraft just to make an error disappear.
