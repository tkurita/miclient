#include <unistd.h>
#import "miClientLib/miClient.h"

#define useLog 0 //Yes:1, No:0


void usage() {
	//fprintf(stderr, "Usage: miclient [-b] [line] file \n");
	printf("Usage: miclient [-v] [-b] [line] file \n");
	exit(-1);
}

extern char *optarg;
extern int optind, opterr, optopt;

int main (int argc, char * const argv[]) {
	
	/* get arguments */
	Boolean bFlag = false;
	while(getopt(argc, argv, "bv") != -1 ){
		switch(optopt){
			case 'b': bFlag = true ; break;
            case 'v':
                printf("miclient, version 2.1\n");
                exit(0);
                break;
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
    
    BOOL isSuccess;
	@autoreleasepool {
        NSString *path = [NSString stringWithCString:filePath encoding:NSUTF8StringEncoding];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            exit(-1);
        }
        NSURL *url = [NSURL fileURLWithPath:path];
        id miclient = [miClient new];
        [miclient setUseBookmarkBeforeJump:bFlag];
        isSuccess = [miclient jumpToFileURL:url paragraph:[NSNumber numberWithLong:parIndex]];
	}
	if (isSuccess)
		return 0;
	else
		return 1;
}
