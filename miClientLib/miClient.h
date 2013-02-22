#import <Cocoa/Cocoa.h>
#include <ApplicationServices/ApplicationServices.h>

@interface miClient : NSObject {
	BOOL useBookmarkBeforeJump;
}
+ (miClient *)sharedClient;

-(BOOL) jumpToFile:(FSRef *)pFileRef paragraph:(NSNumber *)npar;
-(NSString *) currentDocumentMode;
-(NSString *) name;
-(void)setUseBookmarkBeforeJump:(BOOL)aFlag;
- (NSString *)currentDocumentContent;

@end
