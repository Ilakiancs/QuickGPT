.PHONY: build run install uninstall clean release test

APP_NAME = QuickGPT
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = /Applications
NATIVE_ARCH := $(shell uname -m)
VERSION ?= $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
ARCHS = arm64 x86_64
DIST = dist

# Build the app for this Mac's architecture into ./QuickGPT.app
build:
	@scripts/build-app.sh $(NATIVE_ARCH) .

# Run unit tests
test:
	@swift test

# Build and run (without installing)
run: build
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 0.5
	@open $(APP_BUNDLE)
	@echo "$(APP_NAME) running from dev build"

# Install to /Applications
install: build
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 0.5
	@rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	@cp -r $(APP_BUNDLE) $(INSTALL_DIR)/
	@echo "Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"
	@open $(INSTALL_DIR)/$(APP_BUNDLE)

# Uninstall from /Applications
uninstall:
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	@echo "Uninstalled $(APP_NAME)"

# Clean build artifacts
clean:
	@swift package clean
	@rm -rf .build $(DIST)
	@echo "Cleaned build artifacts"

# Build release zips for Apple Silicon and Intel, plus SHA256SUMS.txt, into dist/
#   dist/QuickGPT-<version>-arm64.zip, dist/QuickGPT-<version>-x86_64.zip, dist/SHA256SUMS.txt
release:
	@rm -rf $(DIST) && mkdir -p $(DIST)
	@for arch in $(ARCHS); do \
		scripts/build-app.sh $$arch $(DIST)/$$arch $(VERSION) || exit 1; \
		(cd $(DIST)/$$arch && ditto -c -k --norsrc --noextattr --keepParent $(APP_BUNDLE) ../$(APP_NAME)-$(VERSION)-$$arch.zip) || exit 1; \
	done
	@# No resource forks/xattrs above: they'd become ._ junk files inside the app when Homebrew unzips it
	@cd $(DIST) && shasum -a 256 $(APP_NAME)-$(VERSION)-*.zip > SHA256SUMS.txt && cat SHA256SUMS.txt
