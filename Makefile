TARGET := iphone:clang:16.5:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME := rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := RateBar
RateBar_FILES := Tweak.xm src/RateBarReader.m src/RateMath.m
RateBar_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-deprecated-declarations
RateBar_FRAMEWORKS := Foundation UIKit
RateBar_PRIVATE_FRAMEWORKS := IOKit
RateBar_LIBRARIES := substrate
INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk
