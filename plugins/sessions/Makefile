TARGET := iphone:clang:16.5:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME := rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := TopBarSessions
TopBarSessions_FILES := Tweak.xm
TopBarSessions_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-deprecated-declarations -I../../src/TopBar
TopBarSessions_FRAMEWORKS := Foundation
TopBarSessions_LIBRARIES := substrate
INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk
