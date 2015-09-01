#import <Cocoa/Cocoa.h>
#include <ApplicationServices/ApplicationServices.h>

@interface miClient : NSObject {
	BOOL useBookmarkBeforeJump;
}
+ (miClient *)sharedClient;

- (BOOL)jumpToFileURL:(NSURL *)url paragraph:(NSNumber *)npar;
- (NSString *) currentDocumentMode;
- (NSString *) name;
- (void)setUseBookmarkBeforeJump:(BOOL)aFlag;
- (NSString *)currentDocumentContent;

@end
