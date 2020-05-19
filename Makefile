.PHONY: install clean

PRODUCT_NAME := miclient

install: clean
	xcodebuild -scheme $(PRODUCT_NAME) install DSTROOT=${HOME} SKIP_INSTALL=NO

clean:
	xcodebuild  -scheme $(PRODUCT_NAME) clean
