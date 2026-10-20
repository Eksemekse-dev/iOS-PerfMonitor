TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PerfMonitor

PerfMonitor_FILES = Tweak.x
PerfMonitor_FRAMEWORKS = UIKit CoreGraphics QuartzCore

include $(THEOS_MAKEFILE_PATH)/tweak.mk
