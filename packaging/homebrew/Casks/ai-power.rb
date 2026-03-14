cask "ai-power" do
  version "0.1.1"
  sha256 "d83eb7a4695f1bf758b26f5135448caf246fe4a908b5ac1c9204620981d2256b"

  url "https://github.com/Relay-lab/ai-power/releases/download/v#{version}/AI-Power-#{version}.dmg"
  name "AI Power"
  desc "Menu bar app that keeps AI workflows running on macOS at the right time"
  homepage "https://github.com/Relay-lab/ai-power"

  depends_on macos: ">= :sonoma"

  app "AI Power.app"
end
