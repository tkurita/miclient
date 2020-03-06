#include <unistd.h>
#import "miClientLib/miClient.h"

#define useLog 0 //Yes:1, No:0
//#define VERSION "2.1.4"

void usage() {
	printf("Usage: miclient [-h] [-v] [-b] [line] file \n");
}

extern char *optarg;
extern int optind, opterr, optopt;

int main (int argc, char * const argv[]) {
	
	/* get arguments */
	Boolean bFlag = false;
	while(getopt(argc, argv, "bvh") != -1 ){
		switch(optopt){
			case 'b': bFlag = true ; break;
            case 'v':
                printf("miclient, version %s\n", VERSION);
                exit(0);
                break;
            case 'h':
			case '?':
                usage();
                exit(0);
			default	:
                usage();
                exit(-1);
                break;
		}
		optarg	=	NULL;
	}
	
	long parIndex = 0;
	char * filePath = "";
	
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
        NSString *path = @(filePath);
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            exit(-1);
        }
        NSURL *url = [NSURL fileURLWithPath:path];
        id miclient = [miClient new];
        [miclient setUseBookmarkBeforeJump:bFlag];
        isSuccess = [miclient jumpToFileURL:url paragraph:@(parIndex)];
	}
	if (isSuccess)
		return 0;
	else
		return 1;
}
