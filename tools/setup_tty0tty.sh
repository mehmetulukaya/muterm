#!/usr/bin/env bash
# Build and install the tty0tty virtual null-modem kernel module.
#
# tty0tty creates /dev/tnt0 ../dev/tnt7 in pairs: tnt0<->tnt1,
# tnt2<->tnt3, ...  RTS is wired to CTS and DTR to DSR/CD on the peer.
#
# Usage:
#   ./tools/setup_tty0tty.sh              # build and install
#   ./tools/setup_tty0tty.sh --uninstall  # remove module and udev rules
#   TTY0TTY_SRC=/path/to/tty0tty ./tools/setup_tty0tty.sh
#
# The script needs sudo for the installation step.

set -euo pipefail

REPO_URL="https://github.com/lcgamboa/tty0tty.git"
KERNEL_RELEASE="$(uname -r)"
DEFAULT_SRC="/tmp/opencode/tty0tty"
TMP_DIR=""

log() {
  printf '\n==> %s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

if [[ "${1:-}" == "--uninstall" ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    SUDO=()
  else
    SUDO=(sudo)
  fi

  log "Removing tty0tty"
  "${SUDO[@]}" rm -f "/lib/modules/${KERNEL_RELEASE}/misc/tty0tty.ko"
  "${SUDO[@]}" rm -f /etc/modules-load.d/tty0tty.conf
  "${SUDO[@]}" rm -f /etc/udev/rules.d/99-tty0tty.rules
  "${SUDO[@]}" depmod -a
  "${SUDO[@]}" modprobe -r tty0tty 2>/dev/null || true
  "${SUDO[@]}" udevadm control --reload-rules || true
  "${SUDO[@]}" udevadm trigger || true
  log "Done. Existing /dev/tnt* nodes disappear after the module is unloaded."
  exit 0
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

if [[ ! -d "/lib/modules/${KERNEL_RELEASE}/build" ]]; then
  echo "error: kernel headers for ${KERNEL_RELEASE} are missing." >&2
  echo "       Install them with: sudo apt install linux-headers-${KERNEL_RELEASE}" >&2
  exit 1
fi

if [[ -z "${TTY0TTY_SRC:-}" ]]; then
  if [[ -d "${DEFAULT_SRC}/module" ]]; then
    SRC="$DEFAULT_SRC"
  else
    TMP_DIR="$(mktemp -d /tmp/tty0tty-build.XXXXXX)"
    SRC="${TMP_DIR}/tty0tty"
    log "Cloning ${REPO_URL}"
    git clone --depth 1 "$REPO_URL" "$SRC"
  fi
else
  SRC="$TTY0TTY_SRC"
fi

if [[ ! -f "${SRC}/module/Makefile" ]]; then
  echo "error: ${SRC} does not look like a tty0tty source tree." >&2
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

log "Building tty0tty for ${KERNEL_RELEASE}"
make -C "${SRC}/module" clean
make -C "${SRC}/module"

log "Installing tty0tty (sudo may ask for your password)"
# The upstream install target copies the module, writes the modules-load
# and udev files, runs depmod and loads the module with modprobe.
"${SUDO[@]}" make -C "${SRC}/module" install

log "Installed ports"
ls -l /dev/tnt* 2>/dev/null || warn "no /dev/tnt* nodes yet; check 'dmesg | tail'"

cat <<'EOF'

tty0tty is ready.  The pairs are:

  /dev/tnt0 <-> /dev/tnt1
  /dev/tnt2 <-> /dev/tnt3
  /dev/tnt4 <-> /dev/tnt5
  /dev/tnt6 <-> /dev/tnt7

Use one side in MUTerm and the other side in the simulator, e.g.:

  ./tools/mu_sim.py /dev/tnt1 --baud 9600
  # MUTerm -> /dev/tnt0

If MUTerm cannot open the port, check that your user is in the dialout group
(new group membership requires a fresh login):

  groups
  sudo usermod -aG dialout "$USER"

On systems with Secure Boot, unsigned kernel modules may be refused by the
kernel even after a successful build.  Check with 'mokutil --sb-state' and
sign the module or disable Secure Boot if necessary.
EOF
