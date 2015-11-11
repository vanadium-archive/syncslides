ifdef DEVICE_NUM

ifneq ($(DEVICE_NUM), 1)
	REUSE_FLAG := --reuse-server
endif

DEVICE_NUM_PLUS_ONE := $(shell echo $(DEVICE_NUM) \+ 1 | bc)
DEVICE_ID := $(shell adb devices | sed -n $(DEVICE_NUM_PLUS_ONE)p | awk '{ print $$1; }')
DEVICE_FLAG := --target-device $(DEVICE_ID)

endif



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
	pub run sky_tools build && pub run sky_tools run_mojo --mojo-path $(MOJO_DIR)/src/mojo/devtools/common/mojo_run --android --mojo-debug -- --enable-multiprocess --map-origin="https://syncslides.mojo.v.io/=$(PWD)" --args-for="https://syncslides.mojo.v.io/packages/syncbase/mojo_services/android/syncbase_server.mojo --v=1 --v23.namespace.root=/ns.dev.v.io:8101 $(NAME_FLAG) --logtostderr=true --root-dir=/data/data/org.chromium.mojo.shell/app_home/syncbasedata" $(DEVICE_FLAG) --no-config-file $(REUSE_FLAG)

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
