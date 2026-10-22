TARGET := iphone:clang:16.5:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME := rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := TopBarProbe
TopBarProbe_FILES := Tweak.xm
TopBarProbe_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-deprecated-declarations
TopBarProbe_FRAMEWORKS := Foundation UIKit
TopBarProbe_LIBRARIES := substrate
INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk
