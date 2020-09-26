#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "AQApkFile.h"

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

void ApplyTemplateArgs(NSMutableString* html, NSDictionary<NSString*, NSString*>* args){
	for(NSString* key in [args keyEnumerator]){
		[html replaceOccurrencesOfString:[NSString stringWithFormat:@"{%%%@%%}", key] withString:[[[args valueForKey:key]stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"] options:0 range:NSMakeRange(0, [html length])];
	}
}

NSString* AndroidVersionForSDK(int sdk){
	NSArray<NSString*>* versions=@[@"1.0", @"1.1", @"1.5", @"1.6", @"2.0", @"2.0.1", @"2.1", @"2.2", @"2.3", @"2.3.3", @"3.0", @"3.1", @"3.2", @"4.0", @"4.0.3", @"4.1", @"4.2", @"4.3", @"4.4", @"4.4W", @"5.0", @"5.1", @"6.0", @"7.0", @"7.1", @"8.0", @"8.1", @"9.0", @"10.0", @"11.0"];
	if(sdk>0 && sdk-1<[versions count])
		return versions[sdk-1];
	return @"Unknown";
}

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    // To complete your generator please implement the function GeneratePreviewForURL in GeneratePreviewForURL.c
	@autoreleasepool{
		NSURL *fileURL = (__bridge NSURL *)url;
		NSLog(@"GeneratePreviewForURL: %@ type %@", [fileURL absoluteString], contentTypeUTI);
		NSBundle* bundle=[NSBundle bundleForClass:[AQApkFile class]];
		

		AQApkFile* apk=[[AQApkFile alloc] initWithUrl:(__bridge NSURL *)(url)];
		
		NSData* cssData=[NSData dataWithContentsOfURL:[[NSBundle bundleForClass:[AQApkFile class]] URLForResource:@"preview" withExtension:@"css"]];
		
		NSDictionary *properties = @{ // properties for the HTML data
									 (__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
									 (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html",
									 (__bridge NSString *)kQLPreviewPropertyAttachmentsKey : @{
											 @"preview.css" : @{
													 (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/css",
													 (__bridge NSString *)kQLPreviewPropertyAttachmentDataKey: cssData,
													 },
											 @"icon.png": @{
													 (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"image/png",
													 (__bridge NSString *)kQLPreviewPropertyAttachmentDataKey: [apk iconData],
													 }
											 },
									 };
		NSString* template=[NSString stringWithContentsOfURL:[[NSBundle bundleForClass:[AQApkFile class]] URLForResource:@"template" withExtension:@"html"] encoding:NSUTF8StringEncoding error:nil];
		NSMutableString *html=[NSMutableString stringWithString: template];
		
		NSDictionary<NSFileAttributeKey, id>* attrs=[[NSFileManager defaultManager]attributesOfItemAtPath:[fileURL path] error:nil];
		
		int targetSDK=[apk targetSDK];
		int minSDK=[apk minSDK];
		NSString* cpus=[apk compatibleCpuList];
		
		NSLog(@"here3");
		
		bool showSignature=[[[NSUserDefaults alloc] initWithSuiteName:@"me.grishka.ApkQuickLook"] boolForKey:@"checkSignatures"];
		if(showSignature)
			[apk loadSignature];
		
		if(QLPreviewRequestIsCancelled(preview))
			return noErr;
		
		ApplyTemplateArgs(html, @{
								  @"LocalizedName": [apk localizedName],
								  @"PackageID": [apk packageName],
								  @"VersionName": [apk versionName],
								  @"VersionCode": [apk versionCode],
								  @"Size": [NSByteCountFormatter stringFromByteCount:[attrs fileSize] countStyle:NSByteCountFormatterCountStyleFile],
								  @"LastMod": [NSDateFormatter localizedStringFromDate:[attrs fileModificationDate] dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle],
								  @"MinSDK": [NSString stringWithFormat: @"%d", minSDK],
								  @"TargetSDK": [NSString stringWithFormat: @"%d", targetSDK],
								  @"MinAndroid": AndroidVersionForSDK(minSDK),
								  @"TargetAndroid": AndroidVersionForSDK(targetSDK),
								  @"CompatibleCPUs": cpus ? cpus : NSLocalizedStringFromTableInBundle(@"Any", nil, bundle, nil),
								  @"Permissions": [[apk permissions] componentsJoinedByString:@"\n"],
								  @"CertOwner": [apk getCertInfo],
								  @"CertSHA1": [apk getCertSHA1],
								  @"SignatureValidity": [apk isSignatureValid] ? NSLocalizedStringFromTableInBundle(@"Signature is valid", nil, bundle, nil) : NSLocalizedStringFromTableInBundle(@"Signature is not valid", nil, bundle, nil),
								  @"SignatureValidityClass": [apk isSignatureValid] ? @"sig_valid" : @"sig_invalid",
								  @"SignatureBlockStyle": showSignature ? @"" : @"display: none",
								  
								  @"L_PackageID": NSLocalizedStringFromTableInBundle(@"Package ID", nil, bundle, nil),
								  @"L_Version": NSLocalizedStringFromTableInBundle(@"Version", nil, bundle, nil),
								  @"L_Size": NSLocalizedStringFromTableInBundle(@"Size", nil, bundle, nil),
								  @"L_LastMod": NSLocalizedStringFromTableInBundle(@"Last modified", nil, bundle, nil),
								  @"L_OpenInGooglePlay": NSLocalizedStringFromTableInBundle(@"Open in Google Play", nil, bundle, nil),
								  @"L_TargetSystemVersion": NSLocalizedStringFromTableInBundle(@"Target System Version", nil, bundle, nil),
								  @"L_MinSystemVersion": NSLocalizedStringFromTableInBundle(@"Minimum System Version", nil, bundle, nil),
								  @"L_CompatibleCPUs": NSLocalizedStringFromTableInBundle(@"CPU Architectures", nil, bundle, nil),
								  @"L_Permissions": NSLocalizedStringFromTableInBundle(@"Permissions", nil, bundle, nil),
								  @"L_Certificate": NSLocalizedStringFromTableInBundle(@"Certificate", nil, bundle, nil)
								  
								  });
		CFDataRef previewData = (__bridge CFDataRef)[html dataUsingEncoding: NSUTF8StringEncoding];
		QLPreviewRequestSetDataRepresentation(preview, previewData, kUTTypeHTML, (__bridge CFDictionaryRef)(properties));
	}
    return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}
