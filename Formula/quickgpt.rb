class Quickgpt < Formula
  desc "Lightweight ChatGPT menu bar client for macOS"
  homepage "https://github.com/Ilakiancs/QuickGPT"
  url "https://github.com/Ilakiancs/QuickGPT/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "" # Will be filled after creating release
  license "MIT"

  depends_on xcode: ["14.0", :build]
  depends_on macos: :ventura

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"

    # Create app bundle structure
    app_bundle = "#{buildpath}/QuickGPT.app"
    bin.install "#{buildpath}/.build/release/QuickGPT"

    # Copy app bundle to prefix
    prefix.install app_bundle
  end

  def caveats
    <<~EOS
      QuickGPT has been installed!

      To start: open /Applications/QuickGPT.app
      Or run: brew services start quickgpt

      Grant Accessibility permission for global shortcuts:
      System Settings → Privacy & Security → Accessibility → QuickGPT
    EOS
  end

  service do
    run [opt_prefix/"QuickGPT.app/Contents/MacOS/QuickGPT"]
    keep_alive true
  end
end
