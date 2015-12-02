ifndef DEVICE_NUM
	DEVICE_NUM := 1
endif

SYNCBASE_DATA_DIR=/data/data/org.chromium.mojo.shell/app_home/syncbasedata
DEVICE_NUM_PLUS_ONE := $(shell echo $(DEVICE_NUM) \+ 1 | bc)
DEVICE_ID := $(shell adb devices | sed -n $(DEVICE_NUM_PLUS_ONE)p | awk '{ print $$1; }')
DEVICE_FLAG := --target-device $(DEVICE_ID)
MOUNTTABLE_ADDR := /192.168.86.254:8101

# Currently the only way to pass arguments to the app is by using a file.
SETTINGS_FILE := /sdcard/syncslides_settings.json
SETTINGS_JSON := {\"deviceid\": \"$(DEVICE_ID)\", \"mounttable\": \"$(MOUNTTABLE_ADDR)\"}

ifneq ($(DEVICE_NUM), 1)
	REUSE_FLAG := --reuse-servers
endif

ifdef VLOG
	VLOG_FLAGS = --v=$(VLOG) --logtostderr=true
endif

SYNCBASE_ARGS := https://syncbase.syncslides.mojo.v.io/syncbase_server.mojo --root-dir=$(SYNCBASE_DATA_DIR) --v23.namespace.root=$(MOUNTTABLE_ADDR) --name=$(DEVICE_ID) $(VLOG_FLAGS)

default: run

.PHONY: dartanalyzer
dartanalyzer: packages
	dartanalyzer lib/main.dart

.PHONY: dartfmt
dartfmt: packages
	dartfmt --overwrite lib

packages: pubspec.yaml
	pub get

.PHONY: upgrade-packages
upgrade-packages:
	pub upgrade

.PHONY: build
build: packages
	pub run flutter_tools build

GS_BUCKET_PATH := gs://mojo_services/syncslides
GS_BUCKET_URL := storage.googleapis.com/mojo_services/syncslides
SYNCSLIDES_URL = mojo://$(GS_BUCKET_URL)/app.flx

APP_FLX_FILE := $(PWD)/build/app.flx
SYNCBASE_MOJO_DIR := $(PWD)/packages/syncbase/mojo_services/android
DISCOVERY_MOJO_DIR := $(PWD)/packages/v23discovery/mojo_services/android
MOJO_SHELL_CMD_PATH := /data/local/tmp/org.chromium.mojo.shell.cmd

SYNCSLIDES_SHORTCUT_NAME := SyncSlides
SYNCSLIDES_ICON := https://avatars0.githubusercontent.com/u/9374332?v=3&s=200

define GENERATE_SHORTCUT_FILE
	sed -e "s;%GS_BUCKET_URL%;$1;g" -e "s;%SYNCBASE_FLAGS%;$2;g" \
	shortcut_template > shortcut_commands
endef

.PHONY: install
install: build deploy
	$(call GENERATE_SHORTCUT_FILE,$(GS_BUCKET_URL),$(SYNCBASE_ARGS))
	adb -s $(DEVICE_ID) push -p shortcut_commands $(MOJO_SHELL_CMD_PATH)
	adb -s $(DEVICE_ID) shell chmod 555 $(MOJO_SHELL_CMD_PATH)
	adb -s $(DEVICE_ID) shell 'echo $(SETTINGS_JSON) > $(SETTINGS_FILE)'
	$(MOJO_DIR)/src/mojo/devtools/common/mojo_run --android $(DEVICE_FLAG) "mojo:shortcut $(SYNCSLIDES_SHORTCUT_NAME) $(SYNCSLIDES_URL) $(SYNCSLIDES_ICON)"

.PHONY: uninstall
uninstall:
	adb -s $(DEVICE_ID) uninstall org.chromium.mojo.shell
	adb -s $(DEVICE_ID) shell rm -f $(MOJO_SHELL_CMD_PATH)
# TODO(aghassemi): Is there a way to remove the shortcut via adb?

.PHONY: deploy
deploy: packages
	gsutil cp $(APP_FLX_FILE) $(GS_BUCKET_PATH)
	gsutil cp $(SYNCBASE_MOJO_DIR)/syncbase_server.mojo $(GS_BUCKET_PATH)
	gsutil cp $(DISCOVERY_MOJO_DIR)/discovery.mojo $(GS_BUCKET_PATH)
	gsutil -m acl set -R -a public-read $(GS_BUCKET_PATH)

# Usage example:
# DEVICE_NUM=1 make run
# DEVICE_NUM=2 make run
run: build
	adb -s $(DEVICE_ID) shell 'echo $(SETTINGS_JSON) > $(SETTINGS_FILE)'
	pub run flutter_tools run_mojo \
	--mojo-path $(MOJO_DIR)/src \
	--android --mojo-debug -- --enable-multiprocess \
	--map-origin="https://syncbase.syncslides.mojo.v.io/=$(SYNCBASE_MOJO_DIR)" \
	--map-origin="https://discovery.syncslides.mojo.v.io/=$(DISCOVERY_MOJO_DIR)" \
	--args-for="$(SYNCBASE_ARGS)" \
	$(DEVICE_FLAG) \
	$(REUSE_FLAG) \
	--no-config-file

# Helper targets
run1:
	DEVICE_NUM=1 make run
run2:
	DEVICE_NUM=2 make run
run3:
	DEVICE_NUM=3 make run
run4:
	DEVICE_NUM=4 make run

.PHONY: clean
clean:
	rm -f app.flx snapshot_blob.bin
	rm -rf packages
	adb -s $(DEVICE_ID) shell run-as org.chromium.mojo.shell rm $(SETTINGS_FILE) settings_commands

.PHONY: clean-syncbase
clean-syncbase:
	adb -s $(DEVICE_ID) shell run-as org.chromium.mojo.shell rm -rf $(SYNCBASE_DATA_DIR)

.PHONY: very-clean
.very-clean: clean clean-syncbase
