cask "ai-power" do
  version "0.1.3"
  sha256 "c940257c8c3de49d8e408687d3c8be4fbb52770bc8e070f20c81aaa37f8695e0"

  url "https://github.com/Relay-lab/ai-power/releases/download/v#{version}/AI-Power-#{version}.dmg"
  name "AI Power"
  desc "Menu bar app that keeps AI workflows running on macOS at the right time"
  homepage "https://github.com/Relay-lab/ai-power"

  depends_on macos: ">= :sonoma"

  app "AI Power.app"
end
