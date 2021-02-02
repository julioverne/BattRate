include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BattRateCC
$(BUNDLE_NAME)_BUNDLE_EXTENSION = bundle
$(BUNDLE_NAME)_CFLAGS +=  -fobjc-arc -I/mnt/d/codes/battrate/battratecc/headers
$(BUNDLE_NAME)_FILES = $(wildcard /mnt/d/codes/battrate/battratecc/*.m)
$(BUNDLE_NAME)_LDFLAGS += /mnt/d/codes/battrate/battratecc/Frameworks/ControlCenterUIKit.tbd
$(BUNDLE_NAME)_INSTALL_PATH = /Library/ControlCenter/Bundles/

$(BUNDLE_NAME)_ARCHS = armv7 armv7s arm64 arm64e
export ARCHS = armv7 armv7s arm64 arm64e

include $(THEOS_MAKE_PATH)/bundle.mk