//#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>
#include <unistd.h>

#define useLog 0 //Yes:1, No:0

void show(CFStringRef formatString, ...) {
    CFStringRef resultString;
    CFDataRef data;
    va_list argList;

    va_start(argList, formatString);
    resultString = CFStringCreateWithFormatAndArguments(NULL, NULL, formatString, argList);
    va_end(argList);

    data = CFStringCreateExternalRepresentation(NULL, resultString, CFStringGetSystemEncoding(), '?');

    if (data != NULL) {
    	printf ("%.*s\n\n", (int)CFDataGetLength(data), CFDataGetBytePtr(data));
    	CFRelease(data);
    }
       
    CFRelease(resultString);
}

void typeCommandB() {
	/* emulate keytype of pressing Cmd-B */
	CGPostKeyboardEvent( (CGCharCode)0, (CGKeyCode)55, true );
	CGPostKeyboardEvent( (CGCharCode)'B', (CGKeyCode)11, true );
	CGPostKeyboardEvent( (CGCharCode)'B', (CGKeyCode)11, false );
	CGPostKeyboardEvent( (CGCharCode)0, (CGKeyCode)55, false );
}

OSErr selectParagraphOfmi(long parIndex){
	/* send AppleEvent to me to select paragrah parIndex in Front document*/
	OSType miSignature = 'MMKE';
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
	return(err);
}

CFDictionaryRef getProcessInfoForCreator(OSType theSignature) {
	/* find an applicarion process specified by theSignature(creator type) from runnning process.
		if target application can be found, get information of the process and return as a result
	*/
	OSErr err;
	ProcessSerialNumber psn = {kNoProcess, kNoProcess};;
	CFDictionaryRef pDict;
	CFStringRef fileCreator;
	CFStringRef targetCreator = UTCreateStringForOSType(theSignature);
	CFComparisonResult isSameSignature;
	Boolean isFound = false;
	
	err = GetNextProcess(&psn);
	while( err == noErr) {
		pDict = ProcessInformationCopyDictionary(&psn, kProcessDictionaryIncludeAllInformationMask);
		//show(CFSTR("Dictionary: %@"), pDict);
		fileCreator = CFDictionaryGetValue (pDict,CFSTR("FileCreator"));
		//show(CFSTR("fileCreator: %@"), fileCreator);
		if (fileCreator != NULL) {
			isSameSignature = CFStringCompare (fileCreator,targetCreator,0);
			//printf("compare success\n");
			if (isSameSignature == kCFCompareEqualTo) {
#if useLog
				printf("mi fournd\n");
#endif
				isFound = true;
				break;
			}
		}
		//show(CFSTR("Dictionary: %@"), pDict);
		CFRelease(pDict);
		err = GetNextProcess (&psn);
	}
	
	
	CFRelease(targetCreator);
	if (isFound) {
		return pDict;
	}
	else{
#if useLog
		printf("NULL will be retruned\n");
#endif
		return NULL;
	}
}

void usage() {
	//fprintf(stderr, "Usage: miclient [-b] [line] file \n");
	printf("Usage: miclient [-b] [line] file \n");
	exit(-1);
}

extern char *optarg;
extern int optind, opterr, optopt;

int main (int argc, char * const argv[]) {
	
	/* get arguments */
	Boolean bFlag = false;
	while(getopt(argc, argv, "b") != -1 ){
		switch(optopt){
			case 'b': bFlag = true ; break;
			case '?':
			default	:
				usage(); break;
		}
		optarg	=	NULL;
	}
	
	long parIndex = NULL;
	char * filePath;
	
	if (optind < argc) {
		if (argc - optind > 2) {
			// too many arguments
			usage();
		}
		
		filePath = argv[--argc];
		//printf("filePath : %s\n",filePath);
		if (optind < argc) {
			parIndex = atol(argv[--argc]); 
			//printf("parIndex : %i\n",parIndex);
		}
	}
	else {
		usage();
	}
	
	OSErr err;
	
	/* check file path */
	FSRef fileRef, appRef;
	LSLaunchURLSpec launchWithMiSpec;
	CFURLRef miAppURL,targetFileURL,launchedURL;
	
	err = FSPathMakeRef ((UInt8 *) filePath, &fileRef, NULL);
	if (err != noErr) {
		//fprintf(stderr,"%s is not found.\n",filePath);
		printf("Error in miclient : %s is not found.\n",filePath);
		exit(-1);
	}
	
	/* check mi process */
	OSType miSignature = 'MMKE';
	
#if useLog
	printf("before getProcessInfoForCreator\n");
#endif
	CFDictionaryRef pDict = getProcessInfoForCreator(miSignature);
	//printf("after getProcessInfoForCreator\n");
	if (pDict == NULL) {
		/* mi is not launched. */
		launchWithMiSpec.launchFlags = kLSLaunchDefaults;
		err = LSFindApplicationForInfo (miSignature, NULL, CFSTR("mi"), &appRef, &miAppURL);
		if (err != noErr ) {
			printf("Error in miclient : The Application mi could not be found.\n");
			exit(-1);
		}
	}
	else{
		/* mi is launched. */
		launchWithMiSpec.launchFlags = kLSLaunchDontSwitch;
		//launchWithMiSpec.launchFlags = kLSLaunchDefaults;
		CFStringRef theBundlePath = CFDictionaryGetValue(pDict,CFSTR("BundlePath"));
		miAppURL = CFURLCreateWithFileSystemPath(NULL,theBundlePath,kCFURLPOSIXPathStyle, NULL);
		//show(CFSTR("theBundlePath: %@"), theBundlePath);
		CFRelease(theBundlePath);
	}
	
	launchWithMiSpec.appURL = miAppURL;
	//show(CFURLGetString(miAppURL));
	
	targetFileURL = CFURLCreateWithFileSystemPath(NULL, CFStringCreateWithCString(NULL,filePath,kCFStringEncodingUTF8), kCFURLPOSIXPathStyle,false);
	//show(CFURLGetString(targetFileURL));
	
	launchWithMiSpec.itemURLs = CFArrayCreate( NULL, (void *)&targetFileURL, 1, NULL );
	launchWithMiSpec.passThruParams = NULL;
	err = LSOpenFromURLSpec(&launchWithMiSpec,&launchedURL);
	//show(CFURLGetString(launchedURL));
	if (err == noErr) {
		//printf("success to launch mi\n");
		if (pDict != NULL) {
			//printf("mi will be activate\n");
			ProcessSerialNumber psn;
			CFNumberGetValue(CFDictionaryGetValue(pDict,CFSTR("PSN")),
				 kCFNumberLongLongType,&psn);
			SetFrontProcessWithOptions(&psn,kSetFrontProcessFrontWindowOnly);
		}
		if (parIndex != NULL) {
			if (bFlag) {
				//printf("will type Command-B\n");
				typeCommandB();
				usleep(100000);
			}			
			err = selectParagraphOfmi(parIndex);
		}
	}
	else {
		//printf("err in launch\n");
	}
    return 0;
}
