TARGET := iphone:clang:16.5:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME := rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := TopBar
TopBar_FILES := Tweak.xm \
	src/TopBar/TBPreferences.m \
	src/TopBar/TBStockItem.m \
	src/TopBar/TBPluginRegistry.m \
	src/TopBar/TBStatusBarController.m \
	src/TopBar/TBDebug.m
TopBar_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-deprecated-declarations -Isrc/TopBar
TopBar_FRAMEWORKS := Foundation UIKit
TopBar_LIBRARIES := substrate
INSTALL_TARGET_PROCESSES := SpringBoard

BUNDLE_NAME := TopBarPrefs
TopBarPrefs_FILES := TopBarPrefs/TopBarPrefsController.m \
	src/TopBar/TBPreferences.m \
	src/TopBar/TBStockItem.m
TopBarPrefs_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-deprecated-declarations -Isrc/TopBar
TopBarPrefs_FRAMEWORKS := Foundation UIKit
TopBarPrefs_RESOURCE_DIRS := TopBarPrefs/Resources
TopBarPrefs_INSTALL_PATH := /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
include $(THEOS_MAKE_PATH)/tweak.mk
