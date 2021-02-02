include $(THEOS)/makefiles/common.mk

SUBPROJECTS += battratehooks
SUBPROJECTS += battratesettings
SUBPROJECTS += battratecc

include $(THEOS_MAKE_PATH)/aggregate.mk

all::
	
