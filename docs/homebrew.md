# Homebrew tap prep for `screencog`

This repository includes a tap-style formula at `Formula/screencog.rb` and a helper script to update it from a tagged release.

## Requirements

- A GitHub release tag like `v0.3.0`
- Release assets uploaded by `.github/workflows/release-binaries.yml`:
  - `screencog-macos-arm64`
  - `screencog-macos-x86_64`
  - `checksums.txt`

## Update formula for a release

```bash
./scripts/update-homebrew-formula.sh v0.3.0
```

This script:

1. Downloads `checksums.txt` for the tag.
2. Extracts `arm64` and `x86_64` SHA-256 values.
3. Rewrites `Formula/screencog.rb` with version, URLs, and checksums.

## Validate locally

```bash
brew style Formula/screencog.rb
brew audit --strict --new Formula/screencog.rb
brew install --build-from-source Formula/screencog.rb
brew test screencog
```

## Publish in a tap

Recommended structure is a tap repo such as `atiti/homebrew-screencog` containing:

- `Formula/screencog.rb`

User install flow:

```bash
brew tap atiti/screencog
brew install screencog
```

## Notes

- The formula installs prebuilt binaries from GitHub Releases.
- For `homebrew-core`, source builds are typically preferred; this setup is optimized for a custom tap.
