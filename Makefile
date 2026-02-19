APP_NAME = PresenterOverlay
BUNDLE = $(APP_NAME).app
SOURCES = $(wildcard Sources/*.swift)
TEST_SOURCES = $(wildcard Tests/*.swift)
# Sources without @main entry point, safe to compile with tests
TESTABLE_SOURCES = $(filter-out Sources/PresenterOverlayApp.swift,$(SOURCES))

SWIFT_FLAGS = \
	-framework AVFoundation \
	-framework SwiftUI \
	-framework AppKit \
	-target arm64-apple-macosx14.0


.PHONY: all build run clean test

all: run

build: $(BUNDLE)

$(BUNDLE): $(SOURCES) Info.plist
	@echo "Compiling $(APP_NAME)..."
	swiftc \
		-o $(APP_NAME) \
		$(SWIFT_FLAGS) \
		$(SOURCES)
	@echo "Creating app bundle..."
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/
	rm $(APP_NAME)
	@echo "Built $(BUNDLE) successfully."

run: $(BUNDLE)
	@echo "Launching $(APP_NAME)..."
	open $(BUNDLE)

test: $(TESTABLE_SOURCES) $(TEST_SOURCES)
	@echo "Compiling tests..."
	swiftc \
		-o TestRunner \
		$(SWIFT_FLAGS) \
		$(TESTABLE_SOURCES) $(TEST_SOURCES)
	@echo "Running tests..."
	./TestRunner
	@rm -f TestRunner

clean:
	rm -rf $(BUNDLE)
	rm -f $(APP_NAME)
	rm -f TestRunner
