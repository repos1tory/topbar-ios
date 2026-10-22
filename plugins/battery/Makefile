TARGET := iphone:clang:16.5:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME := rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := TopBarBattery
TopBarBattery_FILES := Tweak.xm ../../src/RateBarReader.m ../../src/RateMath.m
TopBarBattery_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-deprecated-declarations -I../../src -I../../src/TopBar
TopBarBattery_FRAMEWORKS := Foundation UIKit
TopBarBattery_PRIVATE_FRAMEWORKS := IOKit
TopBarBattery_LIBRARIES := substrate
INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk
