include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SmartBatteryPercentage
SmartBatteryPercentage_FILES = Tweak.xm
SmartBatteryPercentage_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
