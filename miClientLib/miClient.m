#import "miClient.h"
#import <Carbon/Carbon.h>
#include <unistd.h>

#if !defined(__LP64__)
typedef unsigned int NSUInteger;
#endif

#define useLog 0

static NSString *miCreatorCode = @"MMKE";
static NSString *miID = @"net.mimikaki.mi";
static OSType miSignature;
static AppleEvent event_front_docment_mode;
static AppleEvent event_front_docment_content;

static miClient *SHARED_INSTANCE = nil;


void typeCommandB() {
	/* emulate keytype of pressing Cmd-B */
    
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    
    CGEventRef kev_b = CGEventCreateKeyboardEvent(source, kVK_ANSI_B, true);
    CGEventSetFlags(kev_b, kCGEventFlagMaskCommand);
    CGEventTapLocation location = kCGHIDEventTap;
    
    CGEventPost(location, kev_b);
    
    CFRelease(kev_b);
    CFRelease(source);
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
	err = AESendMessage(&event,&reply,kAEWaitReply ,100);
	AEDisposeDesc(&reply);
	return(err);
}

@implementation miClient

+ (void)initialize
{
	miSignature = UTGetOSTypeFromString((__bridge CFStringRef)miCreatorCode);
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
	
	err = AEBuildAppleEvent(
							kAECoreSuite, kAEGetData,
							typeApplSignature, &miSignature, sizeof(miSignature),
							kAutoGenerateReturnID, kAnyTransactionID,
							&event_front_docment_content, /* 作成するイベント */
							&buildError, /* エラー情報を必要としない */
							"'----':'obj '{form:prop, want:type(prop),seld:type(pcnt),from:'obj '{form:indx,want:type(docu), seld:short(1), from:'null'()}}");	
	
}

+ (miClient *)sharedClient
{
	@synchronized(self) {  
        if (SHARED_INSTANCE == nil) {  
            (void)[[self alloc] init];
        }  
    }
	return SHARED_INSTANCE;
}

+ (id)allocWithZone:(NSZone *)zone {  
    @synchronized(self) {  
        if (SHARED_INSTANCE == nil) {  
            SHARED_INSTANCE = [super allocWithZone:zone];  
            return SHARED_INSTANCE;  
        }  
    }  
    return nil;  
}  

- (id)copyWithZone:(NSZone*)zone {  
    return self;  // シングルトン状態を保持するため何もせず self を返す  
}  

- (id)init {
    if (self = [super init]) {
        useBookmarkBeforeJump = NO;
    }
    return self;
}

- (NSString *)currentDocumentContent
{
	AppleEvent reply;
	OSErr err;
	
	err = AESendMessage(&event_front_docment_content, &reply, kAEWaitReply, kAEDefaultTimeout);
	if (err != noErr) {
		NSLog(@"fail to AESendMessage with error : %i", err);
		return nil;
	}
	
	NSAppleEventDescriptor *appevent = [[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&reply];
	return [[appevent descriptorForKeyword:keyDirectObject] stringValue];
}

- (NSString *)currentDocumentMode
{
	AppleEvent reply;
	OSErr err;

	//err = AESendMessage(&event_front_docment_mode, &reply, kAEWaitReply, kAEDefaultTimeout);
	err = AESendMessage(&event_front_docment_mode, &reply, kAEWaitReply, 100);
	if (err != noErr) {
		NSLog(@"fail to AESendMessage with error : %i", err);
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
		NSLog(@"fail to AEGetParamDesc with error : %i", err);
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
		NSDictionary *info = @{@"result code": [NSNumber numberWithInt:err]};
		NSException *exception = [NSException exceptionWithName:@"miClientException"
												reason:@"Can't get document mode" userInfo:info];
		@throw exception;
		return @"";
	}
	
	NSString *theMode = [NSString stringWithCharacters:(unichar *)theData length:theLength/sizeof(unichar)];
#if useLog
	NSLog(@"%@", theMode);
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

- (void)setUseBookmarkBeforeJump:(BOOL)aFlag
{
	useBookmarkBeforeJump = aFlag;
}

- (BOOL)jumpToFileURL:(NSURL *)url paragraph:(NSNumber *)npar
{
	//OSErr err;
	OSStatus err;
	LSLaunchURLSpec launchWithMiSpec;
	
	/* check mi process */
    NSURL *mi_url = nil;
    NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:miID];
    NSRunningApplication *mi_process = nil;
    if (apps.count) {
        /* mi is launched. */
        mi_process = [apps lastObject];
        mi_url = [mi_process bundleURL];
 		launchWithMiSpec.launchFlags = kLSLaunchDontSwitch;
    } else {
  		launchWithMiSpec.launchFlags = kLSLaunchDefaults;
		NSString *app_path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:miID];
		if (!app_path ) {
			NSLog(@"Error in miclient : Can't find an application of the identifier : %@", miID);
			return NO;
		}
        mi_url = [NSURL fileURLWithPath:app_path];
    }
    
	launchWithMiSpec.appURL = (__bridge CFURLRef)(mi_url);
	launchWithMiSpec.itemURLs = (__bridge CFArrayRef)(@[url]);
	launchWithMiSpec.passThruParams = NULL;
	launchWithMiSpec.asyncRefCon = NULL;
    
	err = LSOpenFromURLSpec(&launchWithMiSpec, NULL);
	if (err == noErr) {
#if useLog
		printf("success to launch mi\n");
#endif
		if (mi_process) {
#if useLog
			NSLog(@"mi will be activate : %@", mi_process);
#endif
			if (![mi_process activateWithOptions:NSApplicationActivateIgnoringOtherApps] ) {
                // does not work without NSApplicationActivateIgnoringOtherApps option.
                NSLog(@"%@", @"fail to activate mi process");
                return NO;
            }
		}
		
		if (npar != nil) {
			long parIndex = [npar longValue];
			if (useBookmarkBeforeJump) {
#if useLog
				printf("will type Command-B\n");
#endif
				typeCommandB();
				usleep(200000);
			}
			err = selectParagraphOfmi(parIndex);
			if ((err != noErr) && (mi_process)) {
				// when mi is not launched, error -609 occur, but works expected.
				NSLog(@"fail to selectParagraphOfmi with error %d", err);
				goto bail;
			}
		}
	}
	else {
		NSLog(@"Fail to LSOpenFromURLSpec with error %d", err);
	}
bail:
	return err == noErr;
}

@end
