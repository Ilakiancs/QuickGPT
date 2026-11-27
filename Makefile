.PHONY: build run install uninstall clean release

APP_NAME = QuickGPT
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = /Applications

# Build release binary
build:
	@echo "Building $(APP_NAME)..."
	@swift build -c release
	@cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	@echo "Build complete!"

# Build and run (without installing)
run: build
	@pkill -f $(APP_NAME) 2>/dev/null || true
	@sleep 0.5
	@open $(APP_BUNDLE)
	@echo "$(APP_NAME) running from dev build"

# Install to /Applications
install: build
	@pkill -f $(APP_NAME) 2>/dev/null || true
	@sleep 0.5
	@rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	@cp -r $(APP_BUNDLE) $(INSTALL_DIR)/
	@echo "Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"
	@open $(INSTALL_DIR)/$(APP_BUNDLE)

# Uninstall from /Applications
uninstall:
	@pkill -f $(APP_NAME) 2>/dev/null || true
	@rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	@echo "Uninstalled $(APP_NAME)"

# Clean build artifacts
clean:
	@swift package clean
	@rm -rf .build
	@echo "Cleaned build artifacts"

# Create release zip for distribution
release: build
	@rm -f $(APP_NAME).zip
	@ditto -c -k --keepParent $(APP_BUNDLE) $(APP_NAME).zip
	@echo "Created $(APP_NAME).zip for distribution"
