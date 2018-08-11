//
//  AQApkFile.m
//  ApkQuickLook
//
//  Created by Grishka on 02.03.2018.
//  Copyright © 2018 Grishka. All rights reserved.
//

#import "AQApkFile.h"
#import <iconv.h>
#import <AppKit/AppKit.h>

@implementation AQApkFile {
	NSArray<NSString*>* aaptOutput;
	NSMutableDictionary<NSString*, NSString*>* parsedOutput;
	NSMutableArray<NSString*>* permissions;
	ZZArchive* apkArchive;
	NSString* certSHA1;
	NSString* certOwner;
	bool signatureValid;
	
	NSURL* url;
}

- (NSString*) removeQuotesFromString: (NSString*) s{
	return [[[s substringWithRange:NSMakeRange(1, [s length]-2)] stringByReplacingOccurrencesOfString:@"\\'" withString:@"'"] stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
}

- (NSData *)cleanUTF8:(NSData *)data {
	iconv_t cd = iconv_open("UTF-8", "UTF-8"); // convert to UTF-8 from UTF-8
	int one = 1;
	iconvctl(cd, ICONV_SET_DISCARD_ILSEQ, &one); // discard invalid characters
	
	size_t inbytesleft, outbytesleft;
	inbytesleft = outbytesleft = data.length;
	char *inbuf  = (char *)data.bytes;
	char *outbuf = malloc(sizeof(char) * data.length);
	char *outptr = outbuf;
	if (iconv(cd, &inbuf, &inbytesleft, &outptr, &outbytesleft)
		== (size_t)-1) {
		NSLog(@"this should not happen, seriously");
		return nil;
	}
	NSData *result = [NSData dataWithBytes:outbuf length:data.length - outbytesleft];
	iconv_close(cd);
	free(outbuf);
	return result;
}

ZZArchiveEntry* FindEntryWithName(ZZArchive* archive, NSString* name){
	for(UInt i=0;i<[archive.entries count];i++){
		if([archive.entries[i].fileName isEqualToString:name])
			return archive.entries[i];
	}
	return nil;
}

bool IsValidIcon(NSString* name){
	if(!name)
		return false;
	return true;
}

- (int) stringOutput: (NSString**)output ofProcess: (NSString*)exePath withArguments: (NSArray<NSString*>*)args{
	NSTask* task=[[NSTask alloc]init];
	[task setLaunchPath:exePath];
	[task setArguments:args];
	NSPipe* pipe=[NSPipe pipe];
	NSFileHandle* file=pipe.fileHandleForReading;
	[task setStandardOutput:pipe];
	[task launch];
	[task waitUntilExit];
	NSData* outputData=[self cleanUTF8:[file readDataToEndOfFile]];
	[file closeFile];
	*output=[[NSString alloc]initWithData:outputData encoding:NSUTF8StringEncoding];
	//NSLog(@"len %lu", (unsigned long)outputData.length);
	//NSLog(@"%@", [[NSString alloc]initWithData:outputData encoding:NSASCIIStringEncoding]);
	
	return [task terminationStatus];
}

- (AQApkFile*) initWithUrl: (NSURL*) url{
	self=[super init];
	self->url=url;
	NSString* output;
	
	int exitStatus=[self stringOutput:&output ofProcess:[[NSBundle bundleForClass:[self class]] pathForResource:@"aapt" ofType:@""] withArguments:@[@"d", @"badging", [url path]]];
	if(exitStatus!=0){
		NSLog(@"aapt exited with unexpected code %d", exitStatus);
		return nil;
	}
	NSLog(@"%@", output);
	aaptOutput=[output componentsSeparatedByString:@"\n"];
	
	parsedOutput=[NSMutableDictionary dictionary];
	permissions=[NSMutableArray array];
	NSArray<NSString*>* pkgInfo=[aaptOutput[0] componentsSeparatedByString:@" "];
	for(UInt i=1;i<[pkgInfo count];i++){
		NSArray<NSString*>* kv=[pkgInfo[i] componentsSeparatedByString:@"="];
		[parsedOutput setObject:[self removeQuotesFromString: kv[1]] forKey:kv[0]];
	}
	for(UInt i=1;i<[aaptOutput count];i++){
		NSArray<NSString*>* kv=[aaptOutput[i] componentsSeparatedByString:@":"];
		if([kv count]<2){
			NSLog(@"error parsing line %@", aaptOutput[i]);
			continue;
		}
		NSString* value;
		if([kv count]==2)
			value=kv[1];
		else
			value=[[kv subarrayWithRange:NSMakeRange(1, [kv count]-1)] componentsJoinedByString:@":"];
		if([kv[0] isEqualToString:@"uses-permission"] || [kv[0] isEqualToString:@"uses-permission-sdk32"]){
			[permissions addObject:[self removeQuotesFromString:kv[1]]];
			/*NSArray<NSString*>* pairs=[value componentsSeparatedByString:@" "];
			for(UInt j=0;j<[pairs count];j++){
				NSArray<NSString*>* kv=[pairs[j] componentsSeparatedByString:@"="];
				if([kv count]<2)
					continue;
				if([kv[0] isEqualToString:@"name"]){
					NSString* permission=[self removeQuotesFromString: kv[1]];
					[permissions addObject:permission];
				}
			}*/
			continue;
		}
		[parsedOutput setObject:value forKey:kv[0]];
	}
	[permissions sortUsingComparator:^NSComparisonResult(NSString* _Nonnull obj1, NSString* _Nonnull obj2) {
		return [obj1 compare: obj2];
	}];
	for(UInt i=0;i<[permissions count];i++){
		NSString* androidPermission=@"android.permission.";
		if([permissions[i] compare:androidPermission options:0 range:NSMakeRange(0, [androidPermission length])]==NSOrderedSame){
			[permissions setObject:[permissions[i] stringByReplacingOccurrencesOfString:androidPermission withString:@""] atIndexedSubscript:i];
		}
	}

	apkArchive=[ZZArchive archiveWithURL:url error:nil];
	
	return self;
}

- (NSData*) iconData{
	NSString* iconName=[parsedOutput objectForKey:@"application-icon-640"];
	if(!IsValidIcon(iconName))
		iconName=[parsedOutput objectForKey:@"application-icon-480"];
	if(!IsValidIcon(iconName))
		iconName=[parsedOutput objectForKey:@"application-icon-320"];
	if(!IsValidIcon(iconName))
		iconName=[parsedOutput objectForKey:@"application-icon-240"];
	if(!IsValidIcon(iconName))
		iconName=[parsedOutput objectForKey:@"application-icon-160"];
	if(!IsValidIcon(iconName))
		iconName=[parsedOutput objectForKey:@"application-icon-120"];
	if(!IsValidIcon(iconName))
		return nil;
	NSLog(@"icon: %@", iconName);
	ZZArchiveEntry* iconEntry=FindEntryWithName(apkArchive, [self removeQuotesFromString: iconName]);
	if(!iconEntry)
		return nil;
	NSData* iconData=[iconEntry newDataWithError:nil];
	return iconData;
}

- (NSImage*) icon{
	return [[NSImage alloc] initWithData: [self iconData]];
}

- (NSString*) packageName{
	return [parsedOutput objectForKey:@"name"];
}

- (NSString*) name{
	return [self removeQuotesFromString:[parsedOutput objectForKey:@"application-label"]];
}

- (NSString*) localizedName{
	NSLocale* locale=[NSLocale currentLocale];
	NSString* locName=[parsedOutput objectForKey:[NSString stringWithFormat:@"application-label-%@_%@", [locale languageCode], [locale countryCode]]];
	if(!locName)
		locName=[parsedOutput objectForKey:[NSString stringWithFormat:@"application-label-%@", [locale languageCode]]];
	if(locName)
		return [self removeQuotesFromString:locName];
		
	return [self name];
}

- (NSString*) versionName{
	return [parsedOutput objectForKey:@"versionName"];
}

- (NSString*) versionCode{
	return [parsedOutput objectForKey:@"versionCode"];
}

- (int) minSDK{
	return atoi([[self removeQuotesFromString: [parsedOutput objectForKey:@"sdkVersion"]] cString]);
}

- (int) targetSDK{
	return atoi([[self removeQuotesFromString: [parsedOutput objectForKey:@"targetSdkVersion"]] cString]);
}

- (NSString*) compatibleCpuList{
	NSString* cpus=[parsedOutput objectForKey:@"native-code"];
	if(!cpus)
		return nil;
	NSArray<NSString*>* a=[cpus componentsSeparatedByString:@" "];
	NSMutableArray<NSString*>* b=[NSMutableArray array];
	for(NSString* s in a){
		if([s length]>2)
    		[b addObject:[self removeQuotesFromString:s]];
	}
	return [b componentsJoinedByString:@", "];
}

- (NSArray<NSString*>*) permissions{
	return permissions;
}


- (void) loadSignature{
	NSString* jarsignerPath=@"/usr/bin/jarsigner";
	NSString* keytoolPath=@"/usr/bin/keytool";
	
	if(![[NSFileManager defaultManager] fileExistsAtPath:jarsignerPath] || ![[NSFileManager defaultManager] fileExistsAtPath:keytoolPath])
		return;
	
	NSString* jarsignerOutput;
	NSString* keytoolOutput;
	[self stringOutput:&jarsignerOutput ofProcess:jarsignerPath withArguments:@[@"-verify", [url path]]];
	[self stringOutput:&keytoolOutput ofProcess:keytoolPath withArguments:@[@"-printcert", @"-jarfile", [url path]]];
	//NSLog(@"jarsigner: %@", jarsignerOutput);
	//NSLog(@"keytool: %@", keytoolOutput);
	
	signatureValid=[jarsignerOutput containsString:@"jar verified."];
	NSRegularExpression* regex=[NSRegularExpression regularExpressionWithPattern:@"Owner: (.+)\n" options:0 error:nil];
	NSTextCheckingResult* result=[regex firstMatchInString:keytoolOutput options:0 range:NSMakeRange(0, [keytoolOutput length])];
	if([result numberOfRanges]>=2){
		certOwner=[keytoolOutput substringWithRange:[result rangeAtIndex:1]];
	}
	regex=[NSRegularExpression regularExpressionWithPattern:@"SHA1: ([A-F0-9:]+)\n" options:0 error:nil];
	result=[regex firstMatchInString:keytoolOutput options:0 range:NSMakeRange(0, [keytoolOutput length])];
	if([result numberOfRanges]>=2){
		certSHA1=[keytoolOutput substringWithRange:[result rangeAtIndex:1]];
	}
}

- (NSString*) getCertSHA1{
	return certSHA1 ? certSHA1 : @"";
}

- (NSString*) getCertInfo{
	return certOwner ? certOwner : @"";
}

- (bool) isSignatureValid{
	return signatureValid;
}

@end
