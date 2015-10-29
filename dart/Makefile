
default: run

.PHONY: dartanalyzer
dartanalyzer: packages
	dartanalyzer lib/main.dart

.PHONY: dartfmt
dartfmt: packages
	dartfmt --overwrite lib

.PHONY: packages
packages:
	pub upgrade

run: packages
	pub run sky_tools build && pub run sky_tools run_mojo --mojo-path $(MOJO_DIR)/src --android --mojo-debug -- --enable-multiprocess --map-origin="https://syncslides.mojo.v.io/=$(PWD)" --args-for="https://syncslides.mojo.v.io/packages/syncbase/mojo_services/android/syncbase_server.mojo --v=1 --logtostderr=true --root-dir=/data/data/org.chromium.mojo.shell/app_home/syncbasedata" --no-config-file --free-host-ports

.PHONY: clean
clean:
	rm -f app.flx snapshot_blob.bin
	rm -rf packages
