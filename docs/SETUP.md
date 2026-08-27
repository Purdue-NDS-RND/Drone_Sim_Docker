# Setup

This guide is for an x86-64 Ubuntu 22.04 or 24.04 desktop. Allow roughly 20 GB of free disk space and use a terminal inside your normal graphical login session.

## 1. Install basic tools

```bash
sudo apt update
sudo apt install -y ca-certificates curl xauth
```

## 2. Install Docker Engine and Compose

Use Docker's official Ubuntu repository:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"
```

Log out of Ubuntu and log back in. This refreshes your group membership. Verify that Docker works without `sudo`:

```bash
docker info
docker compose version
```

Do not run the simulator with `sudo`; doing that can create root-owned logs and complicate display access.

## 3. Install QGroundControl

Install its host libraries:

```bash
sudo apt install -y \
  gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-gl \
  libfuse2 libxcb-xinerama0 libxkbcommon-x11-0 libxcb-cursor-dev
```

On Ubuntu 22.04, use the x86-64 AppImage from the [official QGroundControl 5.0.8 release](https://github.com/mavlink/qgroundcontrol/releases/tag/v5.0.8). A convenient location is `~/Applications`:

```bash
mkdir -p "$HOME/Applications"
mv QGroundControl*.AppImage "$HOME/Applications/QGroundControl.AppImage"
chmod +x "$HOME/Applications/QGroundControl.AppImage"
"$HOME/Applications/QGroundControl.AppImage"
```

QGC 5.1 AppImages require Ubuntu 24.04 or newer. Do not replace Ubuntu 22.04's system `glibc` to force one to launch. This project uses Copter 4.6.3 so QGC 5.0.8 is a compatible and straightforward Ubuntu 22.04 choice.

## 4. Start the project

Open this project in a terminal, start QGroundControl, and run:

```bash
./run.sh
```

The first run downloads and compiles the image. Future starts reuse it. If the command reports a display, Docker, or graphics error, go to [Troubleshooting](TROUBLESHOOTING.md).

## Optional serial-device access

Serial access is not needed for this UDP-only simulation. If you later connect a real flight controller over USB, add yourself to `dialout` and log out and back in:

```bash
sudo usermod -aG dialout "$USER"
```
