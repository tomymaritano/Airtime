.PHONY: build test package open widgets notary

build:
	swift build -c release --product DevWifiBar

test:
	swift test

package:
	./Scripts/package_app.sh

notary:
	./Scripts/setup_notary.sh

widgets:
	xcodegen generate
	xcodebuild -project DevWifiBar.xcodeproj -scheme DevWifiBarWidgets -configuration Release -derivedDataPath .build/xcode build

open: package
	open dist/Airtime.app
