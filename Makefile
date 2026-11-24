TARGET := iphone:clang:latest:15.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = Instagram

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SRTInstaPlus

SRTInstaPlus_FILES = Tweak.xm
SRTInstaPlus_CFLAGS = -fobjc-arc
SRTInstaPlus_FRAMEWORKS = UIKit Foundation Photos AVFoundation

include $(THEOS_MAKE_PATH)/tweak.mk
