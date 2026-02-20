#!/usr/bin/env bash
set -euo pipefail

REPO="${SCREENCOG_REPO:-atiti/screencog}"
INSTALL_DIR="${SCREENCOG_INSTALL_DIR:-$HOME/.local/bin}"
BINARY_NAME="screencog"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "screencog installer currently supports macOS only." >&2
  exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
  arm64)
    ASSET="screencog-macos-arm64"
    ;;
  x86_64)
    ASSET="screencog-macos-x86_64"
    ;;
  *)
    echo "Unsupported macOS architecture: $ARCH" >&2
    exit 1
    ;;
esac

URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"
TMP_DIR="$(mktemp -d)"
TMP_BIN="$TMP_DIR/$BINARY_NAME"
DEST="$INSTALL_DIR/$BINARY_NAME"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Downloading ${ASSET} from ${REPO}..."
curl -fL --retry 3 --retry-delay 1 "$URL" -o "$TMP_BIN"

chmod +x "$TMP_BIN"
mkdir -p "$INSTALL_DIR"
install -m 0755 "$TMP_BIN" "$DEST"

# Remove quarantine attribute when possible for direct downloads.
xattr -d com.apple.quarantine "$DEST" >/dev/null 2>&1 || true

echo "Installed/updated: $DEST"
echo "Run: $DEST --help"

if ! command -v screencog >/dev/null 2>&1; then
  echo "Tip: add $INSTALL_DIR to PATH if needed." >&2
fi
