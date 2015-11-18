ifndef DEVICE_NUM
	DEVICE_NUM := 1
endif

ifneq ($(DEVICE_NUM), 1)
	REUSE_FLAG := --reuse-servers
endif

ifdef VLOG
	VLOG_FLAGS = --v=$(VLOG) --logtostderr=true
endif

SYNCBASE_DATA_DIR=/data/data/org.chromium.mojo.shell/app_home/syncbasedata
DEVICE_NUM_PLUS_ONE := $(shell echo $(DEVICE_NUM) \+ 1 | bc)
DEVICE_ID := $(shell adb devices | sed -n $(DEVICE_NUM_PLUS_ONE)p | awk '{ print $$1; }')
DEVICE_FLAG := --target-device $(DEVICE_ID)
MOUNTTABLE_ADDR := /192.168.86.254:8101

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

# Usage example:
# DEVICE_NUM=1 make run
# DEVICE_NUM=2 make run
run: packages
	pub run flutter_tools build && pub run flutter_tools run_mojo \
	--mojo-path $(MOJO_DIR)/src \
	--android --mojo-debug -- --enable-multiprocess \
	--map-origin="https://syncslides.mojo.v.io/=$(PWD)" \
	--map-origin="https://discovery.mojo.v.io/=$(JIRI_ROOT)/release/mojo/discovery/gen/mojo/android" \
	--args-for="https://syncslides.mojo.v.io/packages/syncbase/mojo_services/android/syncbase_server.mojo \
	--root-dir=$(SYNCBASE_DATA_DIR) \
	--v23.namespace.root=$(MOUNTTABLE_ADDR) \
	$(VLOG_FLAGS)" \
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

.PHONY: uninstall
uninstall:
	adb -s $(DEVICE_ID) uninstall org.chromium.mojo.shell

.PHONY: clean
clean:
	rm -f app.flx snapshot_blob.bin
	rm -rf packages

.PHONY: clean-syncbase
clean-syncbase:
	adb -s $(DEVICE_ID) shell run-as org.chromium.mojo.shell rm -rf $(SYNCBASE_DATA_DIR)

.PHONY: very-clean
.very-clean: clean clean-syncbase
