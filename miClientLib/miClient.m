#import "miClient.h"
#import "SmartActivate.h"
#include <unistd.h>

#define useLog 0

static NSString *miCreatorCode = @"MMKE";
static OSType miSignature;
static AppleEvent event_front_docment_mode;

void typeCommandB() {
	/* emulate keytype of pressing Cmd-B */
	CGPostKeyboardEvent( (CGCharCode)0, (CGKeyCode)55, true );
	CGPostKeyboardEvent( (CGCharCode)'B', (CGKeyCode)11, true );
	CGPostKeyboardEvent( (CGCharCode)'B', (CGKeyCode)11, false );
	CGPostKeyboardEvent( (CGCharCode)0, (CGKeyCode)55, false );
}

OSErr selectParagraphOfmi(long parIndex){
	/* send AppleEvent to me to select paragrah parIndex in Front document*/
	AppleEvent event, reply;
	OSErr err;
	err = AEBuildAppleEvent(
							kAEMiscStandards, kAESelect,
							typeApplSignature, &miSignature, sizeof(miSignature),
							kAutoGenerateReturnID, kAnyTransactionID,
							&event, /* 作成するイベント */
							NULL, /* エラー情報を必要としない */
							"'----':'obj '{form:indx, want:type(cpar), seld:long(@),from:'obj '{form:indx, want:type(docu), seld:short(1), from:'null'()}}", /* 書式指定文字列 */
							parIndex); 
	err = AESendMessage(&event,&reply,kAEWaitReply ,30);
	AEDisposeDesc(&reply);
	return(err);
}

@implementation miClient

+ (void)initialize
{
	miSignature = UTGetOSTypeFromString((CFStringRef)miCreatorCode);
	OSErr err;
	AEBuildError buildError;
	err = AEBuildAppleEvent(
							kAECoreSuite, kAEGetData,
							typeApplSignature, &miSignature, sizeof(miSignature),
							kAutoGenerateReturnID, kAnyTransactionID,
							&event_front_docment_mode, /* 作成するイベント */
							&buildError, /* エラー情報を必要としない */
							"'----':'obj '{form:prop, want:type(prop),seld:type(pmod),from:'obj '{form:indx,want:type(docu), seld:short(1), from:'null'()}}");
#if useLog
	printf("build error error code:%d error pos:%d\n", buildError.fError, buildError.fErrorPos);
#endif
	
}

- (NSString *)currentDocumentMode
{
	AppleEvent reply;
	OSErr err;

	//err = AESendMessage(&event_front_docment_mode, &reply, kAEWaitReply, kAEDefaultTimeout);
	err = AESendMessage(&event_front_docment_mode, &reply, kAEWaitReply, 100);
	if (err != noErr) {
		NSLog([NSString stringWithFormat:@"fail to AESendMessage with error : %i", err]);
		return nil;
	}
	
#if useLog
	Handle result;
	OSStatus resultStatus;
	resultStatus = AEPrintDescToHandle(&reply,&result);
	printf("%s\n",*result);
#endif
	
	AEDesc givenDesc;
	err = AEGetParamDesc(&reply, keyDirectObject, typeUnicodeText, &givenDesc);
	if (err != noErr) {
		NSLog([NSString stringWithFormat:@"fail to AEGetParamDesc with error : %i", err]);
		return nil;
	}
	
	Size theLength = AEGetDescDataSize(&givenDesc);
	UInt8 *theData = malloc(theLength);
	if (theLength != 0) {
		err = AEGetDescData(&givenDesc, theData, theLength);
	}
	
	if (err != noErr) {
#if useLog
		printf("can't get mode with error :%i\n",err);
#endif
		//err = -1704 : menu is opened
		//err = -1701 : No documents
		free(theData);
		AEDisposeDesc(&reply);
		NSDictionary *info = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:err] forKey:@"result code"];
		NSException *exception = [NSException exceptionWithName:@"miClientException"
												reason:@"Can't get document mode" userInfo:info];
		@throw exception;
		return @"";
	}
	
	NSString *theMode = [NSString stringWithCharacters:(unichar *)theData length:theLength/sizeof(unichar)];
#if useLog
	NSLog(theMode);
#endif
	AEDisposeDesc(&reply);
	free(theData);

#if useLog
	NSLog(@"end of currentDocumentMode");
#endif
	return theMode;
}

- (NSString *)name
{
	return @"mi";
}

- (BOOL)jumpToFile:(FSRef *)pFileRef paragraph:(NSNumber *)npar
{
	OSErr err;
	
	FSRef appRef;
	LSLaunchFSRefSpec launchWithMiSpec;
	ProcessSerialNumber psn;	
	
	/* check mi process */
	NSDictionary *pDict = (NSDictionary *)getProcessInfo((CFStringRef)miCreatorCode, nil, nil);
		
	if (pDict == NULL) {
		/* mi is not launched. */
		launchWithMiSpec.launchFlags = kLSLaunchDefaults;
		err = LSFindApplicationForInfo (miSignature, NULL, NULL, &appRef, NULL);
		if (err != noErr ) {
			//printf("Error in miclient : The Application mi could not be found.\n");
			return NO;
		}
	}
	else{
		/* mi is launched. */
		launchWithMiSpec.launchFlags = kLSLaunchDontSwitch;
		//launchWithMiSpec.launchFlags = kLSLaunchDefaults;
		
		[[pDict objectForKey:@"PSN"] getValue:&psn];
		err = GetProcessBundleLocation(&psn, &appRef);
	}
		
	launchWithMiSpec.appRef = &appRef;
	launchWithMiSpec.numDocs = 1;
	launchWithMiSpec.itemRefs = pFileRef;
	launchWithMiSpec.passThruParams = NULL;
	
	err = LSOpenFromRefSpec(&launchWithMiSpec, NULL);
	BOOL bFlag = YES;
	if (err == noErr) {
		//printf("success to launch mi\n");
		if (pDict != NULL) {
			//printf("mi will be activate\n");
			SetFrontProcessWithOptions(&psn,kSetFrontProcessFrontWindowOnly);
		}
		
		if (npar != nil) {
			long parIndex = [npar longValue];
			if (bFlag) {
				//printf("will type Command-B\n");
				typeCommandB();
				usleep(200000);
			}
			
			err = selectParagraphOfmi(parIndex);
		}
	}
	else {
		//printf("err in launch\n");
	}
	[pDict release];
	
	return err == noErr;
}

@end
