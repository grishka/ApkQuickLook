#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <ZipZap/ZipZap.h>
#import "AQApkFile.h"

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);

// https://stackoverflow.com/questions/9221145/remove-curled-corner-from-qlgenerator-thumbnail
// Undocumented properties
const CFStringRef kQLThumbnailPropertyIconFlavorKey = CFSTR("IconFlavor");

typedef NS_ENUM(NSInteger, QLThumbnailIconFlavor)
{
	kQLThumbnailIconPlainFlavor		= 0,
	kQLThumbnailIconShadowFlavor	= 1,
	kQLThumbnailIconBookFlavor		= 2,
	kQLThumbnailIconMovieFlavor		= 3,
	kQLThumbnailIconAddressFlavor	= 4,
	kQLThumbnailIconImageFlavor		= 5,
	kQLThumbnailIconGlossFlavor		= 6,
	kQLThumbnailIconSlideFlavor		= 7,
	kQLThumbnailIconSquareFlavor	= 8,
	kQLThumbnailIconBorderFlavor	= 9,
	// = 10,
	kQLThumbnailIconCalendarFlavor	= 11,
	kQLThumbnailIconPatternFlavor	= 12,
};

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    // To complete your generator please implement the function GenerateThumbnailForURL in GenerateThumbnailForURL.c
	@autoreleasepool{
		NSDictionary *properties = @{(__bridge NSString *) kQLThumbnailPropertyIconFlavorKey: @(kQLThumbnailIconPlainFlavor) };
		CGContextRef cgContext=QLThumbnailRequestCreateContext(thumbnail, maxSize, false, (__bridge CFDictionaryRef)(properties));
		
		AQApkFile* apk=[[AQApkFile alloc] initWithUrl:(__bridge NSURL *)(url)];
		
		NSImage* icon=[apk icon];
		if(!icon)
			return noErr;

		if(cgContext) {
			NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)cgContext flipped:NO];
			[NSGraphicsContext saveGraphicsState];
			[NSGraphicsContext setCurrentContext:context];
			
			//NSLog(@"Size: %f x %f", maxSize.width, maxSize.height);
			
			[icon drawInRect:NSMakeRect(0, 0, maxSize.width, maxSize.height)];
			
			// done drawing, so set the current context back to what it was
			[NSGraphicsContext restoreGraphicsState];

			QLThumbnailRequestFlushContext(thumbnail, cgContext);
			CFRelease(cgContext);
		}
	}
    return noErr;
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail)
{
    // Implement only if supported
}
