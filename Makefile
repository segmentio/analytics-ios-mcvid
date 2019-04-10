XCPRETTY := xcpretty -c && exit ${PIPESTATUS[0]}

SDK ?= "iphonesimulator"
DESTINATION ?= "platform=iOS Simulator,name=iPhone 7"
PROJECT := analytics-ios-mcvid
XC_ARGS := -scheme $(PROJECT)-Example -workspace Example/$(PROJECT).xcworkspace -sdk $(SDK) -destination $(DESTINATION) ONLY_ACTIVE_ARCH=NO

install: Example/Podfile analytics-ios-mcvid.podspec
        pod repo update
        pod install --project-directory=Example

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
        set -o pipefail && xcodebuild $(XC_ARGS) $(XC_BUILD_ARGS) | xcpretty

test-pretty:
        @set -o pipefail && xcodebuild test $(XC_ARGS) $(XC_TEST_ARGS) | xcpretty --report junit

xctest:
        xctool test $(XC_ARGS) run-tests

.PHONY: test build xctest xcbuild clean
.SILENT:
