TARGET := iphone:clang:16.5:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME := rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := TopBarIP
TopBarIP_FILES := Tweak.xm
TopBarIP_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-deprecated-declarations -I../../src/TopBar
TopBarIP_FRAMEWORKS := Foundation UIKit
TopBarIP_LIBRARIES := substrate
INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk
