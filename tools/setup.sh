#!/bin/sh
# Installs the Godot version pinned in .godot-version (Linux and macOS).
# Puts a `godot` command in ~/.local/bin. Safe to re-run.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=$(tr -d '[:space:]' < "$ROOT/.godot-version")   # e.g. 4.6-stable
BASE="https://github.com/godotengine/godot/releases/download/$VERSION"
BIN_DIR="$HOME/.local/bin"
INSTALL_DIR="$HOME/.local/opt/godot-$VERSION"

case "$(uname -s)" in
  Linux)
    case "$(uname -m)" in
      x86_64|amd64)  ARCH=x86_64 ;;
      aarch64|arm64) ARCH=arm64 ;;
      *) echo "Unsupported CPU: $(uname -m)" >&2; exit 1 ;;
    esac
    ZIP="Godot_v${VERSION}_linux.$ARCH.zip"
    EXE="$INSTALL_DIR/Godot_v${VERSION}_linux.$ARCH"
    sha512() { sha512sum "$1" | cut -d' ' -f1; }
    ;;
  Darwin)
    ZIP="Godot_v${VERSION}_macos.universal.zip"
    EXE="$INSTALL_DIR/Godot.app/Contents/MacOS/Godot"
    sha512() { shasum -a 512 "$1" | cut -d' ' -f1; }
    ;;
  *) echo "Unsupported OS: $(uname -s). On Windows run tools/setup.ps1" >&2; exit 1 ;;
esac

if [ -x "$EXE" ]; then
  echo "Godot $VERSION already installed at $INSTALL_DIR"
else
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  echo "Downloading $ZIP ..."
  curl -fL --progress-bar -o "$TMP/$ZIP" "$BASE/$ZIP"
  curl -fsSL -o "$TMP/SHA512-SUMS.txt" "$BASE/SHA512-SUMS.txt"

  EXPECTED=$(awk -v f="$ZIP" '$2 == f { print $1 }' "$TMP/SHA512-SUMS.txt")
  [ -n "$EXPECTED" ] || { echo "No checksum published for $ZIP" >&2; exit 1; }
  [ "$(sha512 "$TMP/$ZIP")" = "$EXPECTED" ] || { echo "Checksum mismatch for $ZIP" >&2; exit 1; }
  echo "Checksum OK"

  mkdir -p "$INSTALL_DIR"
  unzip -oq "$TMP/$ZIP" -d "$INSTALL_DIR"
  chmod +x "$EXE"
fi

mkdir -p "$BIN_DIR"
ln -sf "$EXE" "$BIN_DIR/godot"
echo "Linked $BIN_DIR/godot -> $EXE"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "NOTE: add $BIN_DIR to your PATH (e.g. in ~/.profile), then open a new terminal." ;;
esac

"$EXE" --version
echo "Done. From the project folder run:  godot -e"
