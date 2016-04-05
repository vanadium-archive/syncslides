ifndef DEVICE_NUM
	DEVICE_NUM := 1
endif

SYNCBASE_DATA_DIR=/data/data/org.chromium.mojo.shell/app_home/syncbasedata
# TODO(aghassemi): We should be able to drop the mount table dependency once syncgroup creation no longer requires one.
# See https://github.com/vanadium/issues/issues/873
MOUNTTABLE_ADDR := /ns.dev.v.io:8101/tmp/syncslides

DEVICE_NUM_PLUS_ONE := $(shell echo $(DEVICE_NUM) \+ 1 | bc)
DEVICE_ID := $(shell adb devices | sed -n $(DEVICE_NUM_PLUS_ONE)p | awk '{ print $$1; }')
DEVICE_FLAG := --target-device $(DEVICE_ID)

ifneq ($(DEVICE_NUM), 1)
	REUSE_FLAG := --reuse-servers
endif

ifdef VLOG
	VLOG_FLAGS = --v=$(VLOG) --logtostderr=true
endif

# TODO(aghassemi): Remove use of proxy once BLE-RPC is supported.
SYNCBASE_ARGS := https://syncbase.syncslides.mojo.v.io/syncbase_server.mojo --root-dir=$(SYNCBASE_DATA_DIR) --v23.proxy=/ns.dev.v.io:8101/proxy --v23.namespace.root=$(MOUNTTABLE_ADDR) --name=$(DEVICE_ID) $(VLOG_FLAGS)

SETTINGS_FILE := /sdcard/syncslides_settings.json
SETTINGS_JSON := {\"deviceid\": \"$(DEVICE_ID)\", \"mounttable\": \"$(MOUNTTABLE_ADDR)\"}

SAMPLE_DECKS_PATH := $(PWD)/assets/sample_decks
SD_CARD_DECKS_PATH = '/sdcard/syncslides/decks'

MOJO_DEVTOOLS := $(shell jiri profile env --profiles=v23:mojo --target=arm-android MOJO_DEVTOOLS=)
MOJO_SHELL := $(shell jiri profile env --profiles=v23:mojo --target=arm-android MOJO_SHELL=)

GS_BUCKET_PATH := gs://mojo_services/syncslides
GS_BUCKET_URL := storage.googleapis.com/mojo_services/syncslides
SYNCSLIDES_URL = mojo://$(GS_BUCKET_URL)/app.flx

APP_FLX_FILE := $(PWD)/build/app.flx
SYNCBASE_MOJO_DIR := $(PWD)/packages/syncbase/mojo_services/android
DISCOVERY_MOJO_DIR := $(PWD)/packages/v23discovery/mojo_services/arm_android
MOJO_SHELL_CMD_PATH := /data/local/tmp/org.chromium.mojo.shell.cmd

SYNCSLIDES_SHORTCUT_NAME := SyncSlides
SYNCSLIDES_ICON := https://avatars0.githubusercontent.com/u/9374332?v=3&s=200

define GENERATE_SHORTCUT_FILE
	sed -e "s;%GS_BUCKET_URL%;$1;g" -e "s;%SYNCBASE_FLAGS%;$2;g" \
	shortcut_template > shortcut_commands
endef

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
	pub run flutter_tools build flx

.PHONY: create-shortcut
create-shortcut: clear-shortcut build install-shell
	$(call GENERATE_SHORTCUT_FILE,$(GS_BUCKET_URL),$(SYNCBASE_ARGS))
	adb -s $(DEVICE_ID) push -p shortcut_commands $(MOJO_SHELL_CMD_PATH)
	adb -s $(DEVICE_ID) shell chmod 555 $(MOJO_SHELL_CMD_PATH)
	adb -s $(DEVICE_ID) shell 'echo $(SETTINGS_JSON) > $(SETTINGS_FILE)'
	$(MOJO_DEVTOOLS)/mojo_run --shell-path $(MOJO_SHELL) --android --target-device=$(DEVICE_ID) "https://$(GS_BUCKET_URL)/shortcut.mojo $(SYNCSLIDES_SHORTCUT_NAME) $(SYNCSLIDES_URL) $(SYNCSLIDES_ICON)"

.PHONY: clear-shortcut
clear-shortcut:
	adb -s $(DEVICE_ID) shell rm -f $(MOJO_SHELL_CMD_PATH)

.PHONY: install-shell
install-shell: clear-shortcut
	adb -s $(DEVICE_ID) install $(MOJO_SHELL)

.PHONY: uninstall-shell
uninstall-shell: clear-shortcut
	adb -s $(DEVICE_ID) uninstall org.chromium.mojo.shell

.PHONY: deploy
deploy: build
	gsutil cp $(APP_FLX_FILE) $(GS_BUCKET_PATH)
	gsutil cp $(SYNCBASE_MOJO_DIR)/syncbase_server.mojo $(GS_BUCKET_PATH)
	gsutil cp $(DISCOVERY_MOJO_DIR)/discovery.mojo $(GS_BUCKET_PATH)
	gsutil -m acl set -R -a public-read $(GS_BUCKET_PATH)
	gsutil setmeta -h "Cache-Control:private, max-age=0, no-transform" $(GS_BUCKET_PATH)/*.*

.PHONY: copy-sample-deck
copy-sample-deck:
	adb -s $(DEVICE_ID) push -p $(SAMPLE_DECKS_PATH) $(SD_CARD_DECKS_PATH)

# Usage example:
# DEVICE_NUM=1 make run
# DEVICE_NUM=2 make run
run: build install-shell copy-sample-deck
	adb -s $(DEVICE_ID) shell 'echo $(SETTINGS_JSON) > $(SETTINGS_FILE)'
	pub run flutter_tools run_mojo \
	--devtools-path $(MOJO_DEVTOOLS)/mojo_run \
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
	rm -f app.flx snapshot_blob.bin shortcut_commands
	rm -rf packages
	-adb -s $(DEVICE_ID) shell run-as org.chromium.mojo.shell rm $(SETTINGS_FILE)

.PHONY: clean-syncbase
clean-syncbase:
	-adb -s $(DEVICE_ID) shell run-as org.chromium.mojo.shell rm -rf $(SYNCBASE_DATA_DIR)

.PHONY: very-clean
.very-clean: clean clean-syncbase
