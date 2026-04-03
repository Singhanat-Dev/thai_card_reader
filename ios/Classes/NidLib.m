/*
 flutter packages pub get
 flutter doctor -v
 cd ios
 pod install
 */
#import "NidLib.h"
#import "NIOSLib/include/NiOS.h"
#include "CCIDLib/include/winscard.h"
#include "CCIDLib/include/ft301u.h"



#import <UIKit/UIKit.h>

 
 
#define LIC_FILE        @"lic/rdnidlib.dlt"

//https://github.com/flutter/flutter/blob/master/examples/platform_channel_swift/ios/Runner/AppDelegate.swift

//https://github.com/flutter/flutter/tree/master/dev/integration_tests/platform_interaction

@implementation NidLib
 

FlutterBasicMessageChannel *mMessageChannel;

SInt32 activeReaderTypeNi = -1;

-(void)bindMessageChannel: (FlutterBasicMessageChannel*) msg {
    mMessageChannel = msg;
}


- (void)OnRDNID_NotifyMessage:(NSNotification *)notification {
    
    NSDictionary *userInfo = notification.userInfo;
    NSString *NotifyId = [userInfo objectForKey:@"NotifyId" ];
    NSString *MessageType = [userInfo objectForKey:@"MessageType" ];
    NSString *Caller = [userInfo objectForKey:@"Caller" ];
    NSNumber *perc = [userInfo objectForKey:@"Percent" ];
    NSObject *arg = [userInfo objectForKey:@"ArgData" ];
    
    int percValue  = [perc intValue];
    NSString *msg;
    
  
    if( [Caller caseInsensitiveCompare:@"getNIDTextNi"] ==NSOrderedSame  ||
        [Caller caseInsensitiveCompare:@"getATextNi"] ==NSOrderedSame)
    {
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : \"%@\" , \"ResValue\" : \"%d\"} ", @ "EVENT_NIDTEXT",percValue ];
        if( percValue>=100) {
            NSString *nsData = (NSString*)arg;
            msg =  [NSString stringWithFormat:@"{  \"ResCode\" : \"%@\" , \"ResValue\" : \"%d\", \"ResText\" : \"%@\"  } ", @ "EVENT_NIDTEXT",percValue ,nsData ];

        }
      
    }
    
    if( [Caller compare:@"getNIDPhotoNi"] ==NSOrderedSame  )
    {

        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : \"%@\" , \"ResValue\" : \"%d\"} ",
                @ "EVENT_NIDPHOTO",percValue ];
    }
   

    if( [Caller compare:@"CardStatus"] ==NSOrderedSame  )
    {
        NSNumber *status = [userInfo objectForKey:@"Status" ];
        int attached  = [status intValue];
        //Experiment only, don't use for real product
        if (attached==1) {

            msg =  [NSString stringWithFormat:@"{  \"ResCode\" : \"%@\" , \"ResValue\" : %@} ",
                    @ "EVENT_CARD",@"true" ];
 
        }
        else{
 
            msg =  [NSString stringWithFormat:@"{  \"ResCode\" : \"%@\" , \"ResValue\" : %@} ",
                    @ "EVENT_CARD",@"false" ];
            
        }
    }

    if( [Caller compare:@"ReaderStatus"] ==NSOrderedSame  )
    {
        NSNumber *status = [userInfo objectForKey:@"Status" ];
        int attached  = [status intValue];
        if (attached==1) {
            msg =  [NSString stringWithFormat:@"{  \"ResCode\" : \"%@\" , \"ResValue\" : %@} ",
                    @ "EVENT_READER", @"true" ];
        }
        else{
             
            msg =  [NSString stringWithFormat:@"{  \"ResCode\" : \"%@\" , \"ResValue\" : %@} ",
                    @ "EVENT_READER", @"false" ];
        }
    }
    
    if( [Caller compare:@"scanReaderListBleNi"] ==NSOrderedSame  )
    {
        NSString *readerName = (NSString*)arg;
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : \"%@\" , \"ResValue\" : \"%d\", \"ResText\" : \"%@\"  } ", @ "EVENT_READERLISTBLE",0, readerName  ];
        
    }

    if( [Caller compare:@"getReaderListNi"] ==NSOrderedSame  )
    {
        NSString *readerName = (NSString*)arg;
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : \"%@\" , \"ResValue\" : \"%d\", \"ResText\" : \"%@\"  } ", @ "EVENT_READERLIST",0, readerName  ];
        
    }

    
    dispatch_async(dispatch_get_main_queue(), ^{
        [mMessageChannel sendMessage:msg];
    });

    return ;
    
}



-(NiOS *) getNiOS {
  static NiOS *mNiOS=NULL;
   if(mNiOS==NULL) {
       
       mNiOS = [[NiOS alloc] init];
       [[NSNotificationCenter defaultCenter] addObserver:self
                                                selector:@selector(OnRDNID_NotifyMessage:)
                                                    name: NiOS_NotifyMessage object:NULL];
       

   }
   return mNiOS;
}




//https://gist.github.com/chourobin/f83f3b3a6fd2053fad29fff69524f91c#file-simple-example-md
-(NSString*)readAllData
{
    // add the notification listener for receiving the call back message during reading the current card.

    NiOS *mNiOS =  [self getNiOS];
    NSString* msg ;
    
    int nres = [ mNiOS connectCardNi];
    if(nres!=0) {
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", NI_CONNECTION_ERROR,@"NI_CONNECTION_ERROR" ];
         
        return msg;
    }
  
    CFTimeInterval startBtnReadCardTime ;
    startBtnReadCardTime = CACurrentMediaTime();
    
    NSMutableString *nsDataTxt = [[NSMutableString alloc]init];
    nres = [mNiOS getNIDTextNi :nsDataTxt];
    if( nres != 0)
    {

        nres = [ mNiOS disconnectCardNi];
        
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", NI_GET_TEXT_ERROR,@"NI_GET_TEXT_ERROR" ];
      
        return msg;
    }

    CFTimeInterval _t_getNIDTextNi = CACurrentMediaTime() - startBtnReadCardTime;
    
    int zPhoneSize = 1024*6;
    NSMutableData * dataPhoto = [NSMutableData   dataWithCapacity:zPhoneSize];
    nres = [ mNiOS getNIDPhotoNi :dataPhoto] ;
        
    if( nres != 0)
    {
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", NI_GET_PHOTO_ERROR,@"NI_GET_PHOTO_ERROR" ];
        
        nres = [ mNiOS disconnectCardNi];

        return msg;
   }


    CFTimeInterval _t_getNIDPhotoNi = CACurrentMediaTime() - startBtnReadCardTime;

    NSData *nsdata = [dataPhoto copy];
    
    NSString *base64Encoded = [nsdata base64EncodedStringWithOptions:0];
    
    
    NSString* msgtime =  [NSString stringWithFormat:@"%@ \\n\\n Read Text= %.2f s \\n Read Text + Photo= %.2f s",
                          nsDataTxt ,
                          _t_getNIDTextNi,
                          _t_getNIDPhotoNi
                      ];
    
     msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d, \"ResValue\" : \"%@\" , \"ResText\" : \"%@\" , \"ResPhoto\" : \"%@\",\"ResPhotoSize\" : %d} ", 0,@"",msgtime,base64Encoded,zPhoneSize ];
      
    nres = [ mNiOS disconnectCardNi];

 
    return msg;

}

-(NSString*)openNiOSLibNi: (NSString*) strLICPath
{
    NiOS *mNiOS =  [self getNiOS];
 
    NSMutableString *path;
    if( [strLICPath length]>0) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        path =  [NSMutableString stringWithFormat:@"%@/%@", paths [0] , strLICPath ];
    }
    else
    {
        path =  [NSMutableString stringWithFormat:@"%@",strLICPath ];
    }
     
     int nres = [ mNiOS openNiOSLibNi: path ];
     
     NSString* msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,@" " ];

    return msg;

}

-(NSString*)closeNiOSLibNi
{

    NiOS *mNiOS =  [self getNiOS];

    int nres = [ mNiOS closeNiOSLibNi ];
     
    NSString* msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,@" " ];

    return msg;

}


-(NSString*)updateLicenseFileNi
{

    NiOS *mNiOS =  [self getNiOS];

    int nres = [ mNiOS updateLicenseFileNi ];
     
    NSString* msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,@" " ];

    return msg;

}


-(NSString*)getReaderListNi
{

    NiOS *mNiOS =  [self getNiOS];

    int nres;
    NSString* msg;
    //
    NSMutableArray * readerList = [[NSMutableArray alloc] init];
    nres = [ mNiOS getReaderListNi:readerList];
    if(nres<=0)
    {
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,@" " ];

    }
    else
    {
        NSString * result = @"";
        for(int i=0; i < nres ; i++)
        {
            result = [result stringByAppendingString:readerList[i]];
            result = [result stringByAppendingString:@";"];

            
        }
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,result ];

    }
    

    return msg;
}

-(NSString*)scanReaderListBleNi:(SInt32)timeout
{
    NiOS *mNiOS =  [self getNiOS];

    int nres;
    NSString* msg;
    //
    NSMutableArray * readerList = [[NSMutableArray alloc] init];
    nres = [ mNiOS scanReaderListBleNi:readerList:timeout];
    if(nres<=0)
    {
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,@" " ];

    }
    else
    {
        NSString * result = @"";
        for(int i=0; i < nres ; i++)
        {
            result = [result stringByAppendingString:readerList[i]];
            result = [result stringByAppendingString:@";"];

            
        }
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,result ];

    }
    return msg;
}


-(NSString*)stopReaderListBleNi
{
    NiOS *mNiOS =  [self getNiOS];

    int nres;
    NSString* msg;
    //
    NSMutableArray * readerList = [[NSMutableArray alloc] init];
    nres = [ mNiOS stopReaderListBleNi];

    msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,@" " ];

    return msg;
}

-(NSString*)connectCardNi
{

    NiOS *mNiOS =  [self getNiOS];

    NSString* msg;
    int nres = [ mNiOS connectCardNi];
    msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,@" " ];

    return msg;
}

-(NSString*)disconnectCardNi
{

    NiOS *mNiOS =  [self getNiOS];

    NSString* msg;
    int nres = [ mNiOS disconnectCardNi];
    msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,@" " ];
    return msg;
}

-(NSString*)getNIDTextNi
{

    NiOS *mNiOS =  [self getNiOS];
    NSString* msg;
    
    NSMutableString *nsData = [[NSMutableString alloc]init];
    int nres = [mNiOS getNIDTextNi :nsData];
    if( nres == 0)
    {
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,nsData ];
    }
    else
    {
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,@" " ];
    }
    return msg;
}

-(NSString*)getNIDPhotoNi
{

    NiOS *mNiOS =  [self getNiOS];
    NSString* msg;
    
    int zPhoneSize = 1024*6;
    NSMutableData * dataPhoto = [NSMutableData   dataWithCapacity:zPhoneSize];
    int nres = [ mNiOS getNIDPhotoNi :dataPhoto] ;
        
    if( nres == 0)
    {
        NSData *nsdata = [dataPhoto copy];
        
        NSString *base64Encoded = [nsdata base64EncodedStringWithOptions:0];
        
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", zPhoneSize,base64Encoded ];
    }
    else
    {
        msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,@" " ];
    }
    return msg;
}




-(NSString*)selectReaderNi: (NSString*) _strReader
{

    NiOS *mNiOS =  [self getNiOS];

    int nres;
    NSString* msg;
    //
   // NSMutableString *strReader = [_strReader mutableCopy];
    
    NSMutableString *strReader  =  [NSMutableString stringWithFormat:@"%@",_strReader ];
    
    nres = [ mNiOS selectReaderNi:strReader];
    msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,@" " ];

    return msg;
}


-(NSString*)deselectReaderNi
{

    NiOS *mNiOS =  [self getNiOS];

    int nres;
    NSString* msg;
    //
    nres = [ mNiOS deselectReaderNi];
    msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,@" " ];

    return msg;
}


-(NSString*)getLicenseInfoNi
{

    NiOS *mNiOS =  [self getNiOS];

    NSMutableString*strLIC = [[NSMutableString alloc]init];
    int nres;
    NSString* msg;
    //
    nres = [mNiOS getLicenseInfoNi :strLIC];

    msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,strLIC ];

    return msg;
}


-(NSString*)getSoftwareInfoNi
{

    NiOS *mNiOS =  [self getNiOS];

    int nres;
    NSString* msg;
    //
    NSMutableString*ver = [[NSMutableString alloc]init];
    nres = [mNiOS getSoftwareInfoNi :ver];

    msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%@\"} ", nres,ver ];

    return msg;
}

-(NSString*)ExistApp {
    exit(0);
    return @"";
}

-(NSString*)getReaderInfoNi
{
    NSString* msg;
    char returnBuffer[1024];

    NiOS *mNiOS =  [self getNiOS];

    char *temp2;
    NSMutableString *nsData = [[NSMutableString alloc]init];
    SInt32 res = [mNiOS getReaderInfoNi :nsData];

    if(res==0){
        temp2 = (char*) [nsData UTF8String];
    }
    else {
        temp2 = returnBuffer;
        sprintf( temp2,"%d", (int)res);
    }

    msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%s\"} ", res,temp2 ];
    
    return msg;
}

char * bin2hex(unsigned char *bi,int bilen,char *res, char spc)
{
    const char hex[] = "0123456789ABCDEF";
    int j=0;
    for( int i=0 ; i < bilen ; i++ )
    {
        unsigned char c = bi[i];
        res[j++] = hex[c >> 4];
        res[j++]= hex[c & 0xf];
        if(spc!=0) {
            res[j++]= spc;
        }
    }
    res[j] = 0;
    return res;
}


-(NSString*)getRidNi
{
    NSString* msg;

    NiOS *mNiOS =  [self getNiOS];

    //Read RID
    char rID[1024]={0};
    char strrID[100]={0};
    int res = [mNiOS getRidNi: (unsigned char*)rID];
    
    if(res==16) {
        bin2hex( (unsigned char*)rID,16,strrID,(char)' ');
    }

    msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%s\"} ", res,strrID ];
    
    return msg;
}


-(NSString*)FtGetLibVersion {
    NSString* msg;
    char  libFTVersion[100] = {0};
    strcpy( libFTVersion , "function FtGetLibVersion (error)" );
    FtGetLibVersion ( libFTVersion );
    msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%s\"} ", 0,libFTVersion ];

    return msg;
}

-(NSString*)FtGetDevVer
{
    NSString* msg;

    NiOS *mNiOS =  [self getNiOS];

    char firmwareRevision[200]={0};
    char hardwareRevision[200]={0};
    SCARDCONTEXT hContext = (SCARDCONTEXT)[mNiOS getContextNi];
    int iRet = FtGetDevVer(  hContext,firmwareRevision,hardwareRevision);


    msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%s\", \"firmwareRevision\" : \"%s\",\"hardwareRevision\" : \"%s\" }", iRet,"",firmwareRevision,hardwareRevision ];
    
    return msg;
}


-(NSString*)FtGetSerialNum
{
    NSString* msg;
    char SN[100]={0};
    int lengthSN = sizeof(SN);
    
    NiOS *mNiOS =  [self getNiOS];
    SCARDCONTEXT hContext = (SCARDCONTEXT)[mNiOS getContextNi];

    int iRet = FtGetSerialNum(hContext, (unsigned int*)&lengthSN, SN);
   
    if(iRet != 0 ) {
      msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%s\"} ", iRet,"" ];

    }
    else{
        
            if( activeReaderTypeNi==READERTYPE_BLE)
            {
                //convert serial number to hex
                char strrID[100]={0};
                
                bin2hex( (unsigned char*)SN,lengthSN,strrID,0);
                
                msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%s\"} ", iRet,strrID ];
            }
            else
            {

                SN[lengthSN]='\0';
                msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%s\"} ", iRet,SN ];
            }
        }

    return msg;
}



+(NSString*) setReaderTypeNi:(SInt32) nReaderType
{
    static int runcount = 0;
    if(runcount==0)
    {
      activeReaderTypeNi = nReaderType;
      [NiOS setReaderTypeNi:nReaderType];
    }
    runcount++;

    NSString* msg;

    msg =  [NSString stringWithFormat:@"{  \"ResCode\" : %d , \"ResValue\" : \"%s\"} ", 0,"OK" ];

    return msg;
}

 
@synthesize description;

@end
