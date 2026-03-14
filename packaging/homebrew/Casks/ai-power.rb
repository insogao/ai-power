cask "ai-power" do
  version "0.1.1"
  sha256 "f8f69cd74a640bef3dc65ce4aee251ee4a57ef8f044bcb6a8458c9cb33e8f33d"

  url "https://github.com/Relay-lab/ai-power/releases/download/v#{version}/AI-Power-#{version}.dmg"
  name "AI Power"
  desc "Menu bar app that keeps AI workflows running on macOS at the right time"
  homepage "https://github.com/Relay-lab/ai-power"

  depends_on macos: ">= :sonoma"

  app "AI Power.app"
end
