#include <unistd.h>
#import "miClientLib/miClient.h"

#define useLog 0 //Yes:1, No:0


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
	
	long parIndex = 0;
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
		
	/* check file path */
	FSRef fileRef;	
	OSErr err = FSPathMakeRef ((UInt8 *) filePath, &fileRef, NULL);
	if (err != noErr) {
		//fprintf(stderr,"%s is not found.\n",filePath);
		printf("Error in miclient : %s is not found.\n",filePath);
		exit(-1);
	}
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	id miclient = [[[miClient alloc] init] autorelease];
	[miclient setUseBookmarkBeforeJump:bFlag];
	BOOL isSuccess = [miclient jumpToFile:&fileRef paragraph:[NSNumber numberWithLong:parIndex]];
	
	[pool release];
	if (isSuccess)
		return 0;
	else
		return 1;
}
