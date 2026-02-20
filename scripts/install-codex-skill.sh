#!/usr/bin/env bash
set -euo pipefail

REPO="${SCREENCOG_REPO:-atiti/screencog}"
SKILL_NAME="${SCREENCOG_SKILL_NAME:-screencog}"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
DEST_DIR="${CODEX_HOME_DIR}/skills/${SKILL_NAME}"
DEST_FILE="${DEST_DIR}/SKILL.md"
SOURCE_URL="https://raw.githubusercontent.com/${REPO}/main/skills/screencog/SKILL.md"

mkdir -p "$DEST_DIR"
curl -fsSL "$SOURCE_URL" -o "$DEST_FILE"

echo "Installed/updated Codex skill at:"
echo "  $DEST_FILE"
