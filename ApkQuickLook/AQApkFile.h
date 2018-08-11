//
//  AQApkFile.h
//  ApkQuickLook
//
//  Created by Grishka on 02.03.2018.
//  Copyright © 2018 Grishka. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ZipZap/ZipZap.h>

@interface AQApkFile : NSObject 

- (AQApkFile*) initWithUrl: (NSURL*) url;
- (NSData*) iconData;
- (NSImage*) icon;
- (NSString*) packageName;
- (NSString*) name;
- (NSString*) localizedName;
- (NSString*) versionName;
- (NSString*) versionCode;
- (int) targetSDK;
- (int) minSDK;
- (NSString*) compatibleCpuList;
- (NSArray<NSString*>*) permissions;

- (void) loadSignature;
- (NSString*) getCertSHA1;
- (NSString*) getCertInfo;
- (bool) isSignatureValid;

@end
