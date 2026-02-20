#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <tag>" >&2
  echo "Example: $0 v0.3.0" >&2
  exit 1
fi

TAG="$1"
if [[ ! "$TAG" =~ ^v[0-9] ]]; then
  echo "Tag must start with 'v' (example: v0.3.0)." >&2
  exit 1
fi

REPO="${SCREENCOG_REPO:-atiti/screencog}"
VERSION="${TAG#v}"
CHECKSUMS_URL="https://github.com/${REPO}/releases/download/${TAG}/checksums.txt"
FORMULA_PATH="Formula/screencog.rb"

TMP_FILE="$(mktemp)"
cleanup() {
  rm -f "$TMP_FILE"
}
trap cleanup EXIT

echo "Downloading checksums from ${CHECKSUMS_URL}..."
curl -fsSL "$CHECKSUMS_URL" -o "$TMP_FILE"

ARM_SHA="$(awk '/screencog-macos-arm64$/ {print $1}' "$TMP_FILE" | head -n1)"
X86_SHA="$(awk '/screencog-macos-x86_64$/ {print $1}' "$TMP_FILE" | head -n1)"

if [[ -z "$ARM_SHA" || -z "$X86_SHA" ]]; then
  echo "Could not parse arm64/x86_64 checksums from checksums.txt" >&2
  exit 1
fi

cat > "$FORMULA_PATH" <<EOF
class Screencog < Formula
  desc "Background-capable macOS window capture and input automation CLI"
  homepage "https://github.com/${REPO}"
  version "${VERSION}"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/${REPO}/releases/download/${TAG}/screencog-macos-arm64", using: :nounzip
      sha256 "${ARM_SHA}"
    else
      url "https://github.com/${REPO}/releases/download/${TAG}/screencog-macos-x86_64", using: :nounzip
      sha256 "${X86_SHA}"
    end
  end

  def install
    binary = Dir["screencog-macos-*"].first
    raise "screencog release binary not found in formula stage directory" if binary.nil?

    bin.install binary => "screencog"
  end

  test do
    assert_match "screencog - targeted window screenshot capture for macOS",
      shell_output("#{bin}/screencog --help")
  end
end
EOF

echo "Updated ${FORMULA_PATH} for ${TAG}"
