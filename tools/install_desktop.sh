#!/usr/bin/env bash
#
# Install MUTerm's desktop entry and icon for the current user.
#
# The desktop entry lets the application menu and the task bar associate the
# running MUTerm window (WM_CLASS "MUTerm") with the PNG icon.  Copying the PNG
# also keeps the icon crisp on desktop environments that prefer themed icons.
#
# Usage:
#   ./tools/install_desktop.sh              # install for the current user
#   ./tools/install_desktop.sh --uninstall  # remove the entry and the icon
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
EXE="$APP_DIR/binaryfiles/MUTerm"
ICON_SRC="$APP_DIR/MUTerm.png"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
ICON_DIR="$DATA_HOME/icons/hicolor/48x48/apps"
ICON_DST="$ICON_DIR/muterm.png"
DESKTOP_DIR="$DATA_HOME/applications"
DESKTOP_FILE="$DESKTOP_DIR/muterm.desktop"

uninstall() {
  rm -f -- "$DESKTOP_FILE" "$ICON_DST"
  command -v update-desktop-database >/dev/null 2>&1 &&
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 &&
    gtk-update-icon-cache -f -t "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true
  echo "Removed $DESKTOP_FILE and $ICON_DST"
}

if [[ "${1:-}" == "--uninstall" ]]; then
  uninstall
  exit 0
fi

if [[ ! -x "$EXE" ]]; then
  echo "error: $EXE not found; build the project first (lazbuild MUTerm.lpi)" >&2
  exit 1
fi

if [[ ! -f "$ICON_SRC" ]]; then
  echo "error: $ICON_SRC not found" >&2
  exit 1
fi

mkdir -p -- "$ICON_DIR" "$DESKTOP_DIR"
install -m 644 -- "$ICON_SRC" "$ICON_DST"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=MU Terminal
GenericName=Serial Terminal
Comment=Serial, TCP and UDP terminal with scripting
Exec="$EXE"
Icon=muterm
Terminal=false
Categories=Development;Utility;Network;
StartupWMClass=MUTerm
EOF
chmod 644 -- "$DESKTOP_FILE"

command -v update-desktop-database >/dev/null 2>&1 &&
  update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
command -v gtk-update-icon-cache >/dev/null 2>&1 &&
  gtk-update-icon-cache -f -t "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true

echo "Installed $DESKTOP_FILE"
echo "Installed $ICON_DST"
