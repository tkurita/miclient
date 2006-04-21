#import <Cocoa/Cocoa.h>
#include <ApplicationServices/ApplicationServices.h>

@interface miClient : NSObject {

}

-(BOOL) jumpToFile:(FSRef *)pFileRef paragraph:(NSNumber *)npar;
-(NSString *) currentDocumentMode;

@end
