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
	xcodebuild -project DevWifiBar.xcodeproj -scheme DevWifiBarWidgets -configuration Release -derivedDataPath .build/xcode \
		CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO CODE_SIGN_STYLE=Manual \
		build

open: package
	open dist/Airtime.app
