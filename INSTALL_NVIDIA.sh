#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" != "0" ]]; then
  echo "This installer must be run as root (try: sudo $0)" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[1/6] Refreshing package index..."
apt-get update -y

echo "[2/6] Installing helper utilities..."
apt-get install -y --no-install-recommends \
  ca-certificates \
  gnupg \
  software-properties-common \
  ubuntu-drivers-common

echo "[3/6] Ensuring required repositories are enabled..."
add-apt-repository -y restricted >/dev/null
add-apt-repository -y multiverse >/dev/null

if ! dpkg --print-foreign-architectures | grep -qx 'i386'; then
  echo " - Enabling i386 multiarch support"
  dpkg --add-architecture i386
fi

if ! grep -Rqs "graphics-drivers" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
  echo " - Adding graphics-drivers PPA"
  add-apt-repository -y ppa:graphics-drivers/ppa >/dev/null
fi

echo "[4/6] Refreshing package index (post repository updates)..."
apt-get update -y

DRIVER_PKG="nvidia-driver-580-open"
WAYLAND_AMD64="libnvidia-egl-wayland1"
GL_I386="libnvidia-gl-580:i386"
WAYLAND_I386="libnvidia-egl-wayland1:i386"
PRIME_PKG="nvidia-prime"
SETTINGS_PKG="nvidia-settings"

install_list=("${DRIVER_PKG}" "${PRIME_PKG}" "${SETTINGS_PKG}" "${WAYLAND_AMD64}")

if ! apt-cache show "${DRIVER_PKG}" >/dev/null 2>&1; then
  echo "[5/6] ${DRIVER_PKG} not available; falling back to ubuntu-drivers autoinstall"
  ubuntu-drivers autoinstall
else
  echo "[5/6] Installing NVIDIA driver stack (${DRIVER_PKG})..."
  apt-get install -y "${install_list[@]}"

  if apt-cache show "${GL_I386}" >/dev/null 2>&1; then
    echo " - Installing 32-bit NVIDIA GL/EGL compatibility libraries"
    apt-get install -y "${GL_I386}" "${WAYLAND_I386}"
  else
    echo " - Skipping 32-bit GL/EGL compatibility libs (package not available)"
  fi
fi

echo "[6/6] All NVIDIA components installed."

echo
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "NVIDIA utilities detected. You can validate the driver with: nvidia-smi"
else
  echo "nvidia-smi not found in PATH; ensure installation succeeded before rebooting."
fi

echo "Reboot the system to load the NVIDIA kernel modules: sudo reboot"
