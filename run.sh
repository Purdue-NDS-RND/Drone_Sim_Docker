#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$PROJECT_DIR"

force_build=0
build_only=0
action=up

usage() {
    cat <<'EOF'
Usage: ./run.sh [--build|--build-only|--down|--help]

  no option      Start the simulation, building the pinned image if absent
  --build        Rebuild the image, then start the simulation
  --build-only   Build the image without needing a display
  --down         Stop and remove this project's containers
EOF
}

case "${1:-}" in
    "") ;;
    --build) force_build=1 ;;
    --build-only) force_build=1; build_only=1 ;;
    --down) action=down ;;
    --help|-h) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
esac

if [[ $(uname -s) != Linux ]]; then
    echo "ERROR: this project requires native Linux because it uses Docker host networking and Linux X11 sockets." >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed. Install Docker Engine from https://docs.docker.com/engine/install/ubuntu/." >&2
    exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
    echo "ERROR: the Docker Compose plugin is unavailable. Install the docker-compose-plugin package." >&2
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    cat >&2 <<EOF
ERROR: Docker is installed but this user cannot reach the daemon.
Add ${USER:-your-user} to the docker group, then log out and back in:
  sudo usermod -aG docker "${USER:-your-user}"
EOF
    exit 1
fi

export HOST_UID=${HOST_UID:-$(id -u)}
export HOST_GID=${HOST_GID:-$(id -g)}
export VIDEO_GID=${VIDEO_GID:-$(getent group video | cut -d: -f3 || true)}
export RENDER_GID=${RENDER_GID:-$(getent group render | cut -d: -f3 || true)}
VIDEO_GID=${VIDEO_GID:-$HOST_GID}
RENDER_GID=${RENDER_GID:-$HOST_GID}
export VIDEO_GID RENDER_GID
export SIM_IMAGE=${SIM_IMAGE:-ardupilot-gz:4.6.3}

compose_files=(-f compose.yaml)
if [[ -d /dev/dri ]]; then
    compose_files+=(-f compose.gpu.yaml)
fi

if [[ $action == down ]]; then
    docker compose "${compose_files[@]}" down --remove-orphans
    exit 0
fi

if [[ $force_build -eq 1 ]] || ! docker image inspect "$SIM_IMAGE" >/dev/null 2>&1; then
    echo "Building $SIM_IMAGE (the first build can take several minutes)..."
    docker compose "${compose_files[@]}" build
else
    echo "Reusing existing image $SIM_IMAGE"
fi

if [[ $build_only -eq 1 ]]; then
    exit 0
fi

if [[ -z ${DISPLAY:-} ]]; then
    echo "ERROR: DISPLAY is empty. Run this command from the logged-in Linux desktop session." >&2
    exit 1
fi
if ! command -v xauth >/dev/null 2>&1; then
    echo "ERROR: xauth is required. Install it with: sudo apt install xauth" >&2
    exit 1
fi
if [[ ! -d /tmp/.X11-unix ]]; then
    echo "ERROR: /tmp/.X11-unix is unavailable; no host X11/Xwayland socket can be forwarded." >&2
    exit 1
fi

software=${SOFTWARE_RENDERING:-0}
case "${software,,}" in
    1|true|yes|on)
        export SOFTWARE_RENDERING=1 LIBGL_ALWAYS_SOFTWARE=1
        ;;
    0|false|no|off|"")
        export SOFTWARE_RENDERING=0 LIBGL_ALWAYS_SOFTWARE=0
        if [[ ! -d /dev/dri ]]; then
            echo "ERROR: /dev/dri is unavailable. GPU rendering cannot start." >&2
            echo "Retry with software rendering: SOFTWARE_RENDERING=1 ./run.sh" >&2
            exit 1
        fi
        ;;
    *)
        echo "ERROR: SOFTWARE_RENDERING must be 0/1, true/false, yes/no, or on/off." >&2
        exit 2
        ;;
esac

mkdir -p logs
if [[ ! -w logs ]]; then
    echo "ERROR: $PROJECT_DIR/logs is not writable by UID $HOST_UID." >&2
    echo "Fix ownership with: sudo chown -R $HOST_UID:$HOST_GID '$PROJECT_DIR/logs'" >&2
    exit 1
fi

runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
XAUTH_FILE=$(mktemp "$runtime_dir/ardupilot-gazebo-xauth.XXXXXX")
export XAUTH_FILE
cleanup() {
    rm -f -- "$XAUTH_FILE"
}
trap cleanup EXIT

# Copy only the current display cookie into an isolated, short-lived authority
# file. FamilyWild makes the cookie work despite the container hostname.
cookie=$(xauth nlist "$DISPLAY" 2>/dev/null || true)
if [[ -z $cookie ]]; then
    echo "ERROR: no Xauthority cookie exists for DISPLAY=$DISPLAY." >&2
    echo "Check XAUTHORITY and run this script from the active desktop session." >&2
    exit 1
fi
printf '%s\n' "$cookie" | sed -e 's/^..../ffff/' | xauth -f "$XAUTH_FILE" nmerge -
chmod 0600 "$XAUTH_FILE"

display_number=${DISPLAY##*:}
display_number=${display_number%%.*}
if [[ ! -S /tmp/.X11-unix/X${display_number} ]]; then
    echo "ERROR: DISPLAY=$DISPLAY does not match /tmp/.X11-unix/X${display_number}." >&2
    exit 1
fi

echo "Host IDs: uid=$HOST_UID gid=$HOST_GID video_gid=$VIDEO_GID render_gid=$RENDER_GID"
echo "Display: $DISPLAY; temporary Xauthority: $XAUTH_FILE"
echo "MAVLink: ${MAVLINK_QGC:-udp:127.0.0.1:14550} (QGC), ${MAVLINK_API:-udp:127.0.0.1:14551} (student API)"
if pgrep -f '[Q]GroundControl' >/dev/null 2>&1; then
    echo "QGroundControl is running on the host and should auto-connect on UDP 14550."
else
    echo "QGroundControl is not currently running; start its host AppImage at any time to auto-connect on UDP 14550."
fi

docker compose "${compose_files[@]}" up --remove-orphans
