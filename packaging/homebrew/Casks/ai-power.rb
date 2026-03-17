cask "ai-power" do
  version "0.1.2"
  sha256 "90753225b6d6cf3f9623af29e03b1601e3c327f0e8f040283ae6a6b81ad09828"

  url "https://github.com/Relay-lab/ai-power/releases/download/v#{version}/AI-Power-#{version}.dmg"
  name "AI Power"
  desc "Menu bar app that keeps AI workflows running on macOS at the right time"
  homepage "https://github.com/Relay-lab/ai-power"

  depends_on macos: ">= :sonoma"

  app "AI Power.app"
end
