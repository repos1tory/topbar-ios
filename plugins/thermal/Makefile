TARGET := iphone:clang:16.5:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME := rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := TopBarThermal
TopBarThermal_FILES := Tweak.xm
TopBarThermal_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-deprecated-declarations -I../../src/TopBar
TopBarThermal_FRAMEWORKS := Foundation
TopBarThermal_PRIVATE_FRAMEWORKS := IOKit
TopBarThermal_LIBRARIES := substrate
INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk
