include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BattRate

$(TWEAK_NAME)_FILES = /mnt/d/codes/battrate/battratehooks/Tweak.xm

$(TWEAK_NAME)_FRAMEWORKS = CydiaSubstrate Foundation UIKit CoreGraphics IOKit Security

#$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_LDFLAGS = -Wl,-segalign,4000

$(TWEAK_NAME)_ARCHS = armv7 armv7s arm64 arm64e
export ARCHS = armv7 armv7s arm64 arm64e

include $(THEOS_MAKE_PATH)/tweak.mk
	
	
all::
	