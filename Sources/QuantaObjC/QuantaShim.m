/**
 * QuantaShim.m
 * Quanta
 *
 * Created by Nick Spreen (spreen.co) on 10/25/24.
 * 
 */

#import "QuantaShim.h"
#import <Foundation/NSObjCRuntime.h>
#import <objc/message.h>

@implementation QuantaShim

+ (void)load {
	Class quantaLoaderClass = NSClassFromString(@"Quanta.QuantaLoader");
	if (quantaLoaderClass) {
		SEL initSelector = NSSelectorFromString(@"initializeLibrary");
		if ([quantaLoaderClass respondsToSelector:initSelector]) {
			((void (*)(id, SEL))objc_msgSend)(quantaLoaderClass, initSelector);
		} else {
			NSLog(@"initializeLibrary method not found on QuantaLoader");
		}
	} else {
		NSLog(@"QuantaLoader class not found");
	}
}

@end
