#import <Flutter/Flutter.h>
#include "CCIDLib/include/winscard.h"
#include "CCIDLib/include/ft301u.h"
#import "NIOSLib/include/NiOS.h"

@interface NidLib :  NSObject {}

-(NiOS *) getNiOS;
-(void)bindMessageChannel: (FlutterBasicMessageChannel*) msg;

 
-(NSString*)readAllData;
-(NSString*)openNiOSLibNi: (NSString*) strLICPath;
-(NSString*)closeNiOSLibNi;
-(NSString*)updateLicenseFileNi;
-(NSString*)getReaderListNi;
-(NSString*)connectCardNi;
-(NSString*)disconnectCardNi;
-(NSString*)getNIDTextNi;
-(NSString*)getNIDPhotoNi;
-(NSString*)selectReaderNi: (NSString*) _strReader;
-(NSString*)getLicenseInfoNi;
-(NSString*)getSoftwareInfoNi;
-(NSString*)ExistApp;
-(NSString*)getReaderInfoNi;
-(NSString*)getRidNi;
-(NSString*)FtGetLibVersion;
-(NSString*)deselectReaderNi;

-(NSString*)FtGetDevVer;
-(NSString*)FtGetSerialNum;
 
-(NSString*)scanReaderListBleNi:(SInt32)timeout;
-(NSString*)stopReaderListBleNi;


+(NSString*) setReaderTypeNi:(SInt32) nReaderType;

@end
