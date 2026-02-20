class Screencog < Formula
  desc "Background-capable macOS window capture and input automation CLI"
  homepage "https://github.com/atiti/screencog"
  version "0.0.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/atiti/screencog/releases/download/v0.0.0/screencog-macos-arm64", using: :nounzip
      sha256 "REPLACE_WITH_ARM64_SHA256"
    else
      url "https://github.com/atiti/screencog/releases/download/v0.0.0/screencog-macos-x86_64", using: :nounzip
      sha256 "REPLACE_WITH_X86_64_SHA256"
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
