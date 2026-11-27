class Quickgpt < Formula
  desc "Lightweight ChatGPT menu bar client for macOS"
  homepage "https://github.com/Ilakiancs/QuickGPT"
  url "https://github.com/Ilakiancs/QuickGPT/releases/download/v1.1.0/QuickGPT.zip"
  sha256 "b8ec336807b1275f6b4876f393bb2c778066474665a7577dda07902758fb4f10"
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
    EOS
  end

  service do
    run [opt_prefix/"QuickGPT.app/Contents/MacOS/QuickGPT"]
    keep_alive true
  end
end
