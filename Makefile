.PHONY: fetch iso
fetch:
	sudo ./scripts/fetch-vendor.sh
iso:
	sudo ./scripts/build-iso.sh
