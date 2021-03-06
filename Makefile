XCPRETTY := xcpretty -c && exit ${PIPESTATUS[0]}

SDK ?= "iphonesimulator"
DESTINATION ?= "platform=iOS Simulator,name=iPhone 11"
PROJECT := analytics-ios-mcvid
XC_ARGS := -scheme $(PROJECT)-Example -workspace Example/$(PROJECT).xcworkspace -sdk $(SDK) -destination $(DESTINATION) ONLY_ACTIVE_ARCH=YES

install: Example/Podfile analytics-ios-mcvid.podspec
	pod repo update
	pod install --project-directory=Example

lint:
	pod lib lint --use-libraries --allow-warnings

clean:
	xcodebuild $(XC_ARGS) clean | $(XCPRETTY)

build:
	xcodebuild $(XC_ARGS) | $(XCPRETTY)

test:
	xcodebuild test $(XC_ARGS) | $(XCPRETTY)

xcbuild:
	xctool $(XC_ARGS)

clean-pretty:
	set -o pipefail && xcodebuild $(XC_ARGS) clean | xcpretty

build-pretty:
	set -o pipefail && xcodebuild $(XC_ARGS) | xcpretty

test-pretty:
	set -o pipefail && xcodebuild test $(XC_ARGS) | xcpretty --report junit

xctest:
	xctool test $(XC_ARGS) run-tests

.PHONY: test build xctest xcbuild clean
.SILENT:
