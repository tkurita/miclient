#import <Cocoa/Cocoa.h>
#include <ApplicationServices/ApplicationServices.h>

@interface miClient : NSObject {
	BOOL useBookmarkBeforeJump;
}

-(BOOL) jumpToFile:(FSRef *)pFileRef paragraph:(NSNumber *)npar;
-(NSString *) currentDocumentMode;
-(NSString *) name;
-(void)setUseBookmarkBeforeJump:(BOOL)aFlag;

@end
