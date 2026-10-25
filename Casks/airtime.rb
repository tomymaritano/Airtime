cask "airtime" do
  version "0.3.0"
  # Placeholder: the v0.3.0 asset does not exist yet, so no real checksum
  # can be computed. Fill this in from the release workflow's "Cask
  # checksum" step output once that tag is built. Do not use :no_check.
  sha256 "REPLACE_AT_RELEASE"

  url "https://github.com/tomymaritano/Airtime/releases/download/v#{version}/Airtime-#{version}.zip"
  name "Airtime"
  desc "Menu bar Wi-Fi stats and LLM connection radar for macOS"
  homepage "https://github.com/tomymaritano/Airtime"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Airtime.app"

  zap trash: [
    # Bundle ID intentionally still reads "devwibar" -- it did not change
    # in the product rename, so this is where preferences actually live.
    "~/Library/Preferences/com.tomymaritano.devwibar.plist",
  ]
end
