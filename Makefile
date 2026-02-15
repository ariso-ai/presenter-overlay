APP_NAME = PresenterOverlay
BUNDLE = $(APP_NAME).app
SOURCES = $(wildcard Sources/*.swift)

.PHONY: all build run clean

all: run

build: $(BUNDLE)

$(BUNDLE): $(SOURCES) Info.plist
	@echo "Compiling $(APP_NAME)..."
	swiftc \
		-o $(APP_NAME) \
		-framework AVFoundation \
		-framework SwiftUI \
		-framework AppKit \
		-target arm64-apple-macosx14.0 \
		$(SOURCES)
	@echo "Creating app bundle..."
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	rm $(APP_NAME)
	@echo "Built $(BUNDLE) successfully."

run: $(BUNDLE)
	@echo "Launching $(APP_NAME)..."
	open $(BUNDLE)

clean:
	rm -rf $(BUNDLE)
	rm -f $(APP_NAME)
