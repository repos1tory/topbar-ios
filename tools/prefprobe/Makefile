TARGET := iphone:clang:16.5:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME := rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := PrefProbe
PrefProbe_FILES := Tweak.xm
PrefProbe_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-deprecated-declarations
PrefProbe_FRAMEWORKS := Foundation UIKit
PrefProbe_LIBRARIES := substrate
INSTALL_TARGET_PROCESSES := Preferences

include $(THEOS_MAKE_PATH)/tweak.mk
