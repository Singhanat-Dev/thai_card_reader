//
//  Created by R&D Computer System Co., Ltd.
//  Copyright 2017 R&D Computer System Co., Ltd. All rights reserved.
//

#ifndef _NiOS_H_

#import <Foundation/Foundation.h>

#define  _NiOS_H_



#define     NI_SUCCESS                  0
#define     NI_INTERNAL_ERROR           -1
#define     NI_INVALID_LICENSE          -2
#define     NI_READER_NOT_FOUND         -3
#define     NI_CONNECTION_ERROR         -4
#define     NI_GET_PHOTO_ERROR          -5
#define     NI_GET_TEXT_ERROR           -6
#define     NI_INVALID_CARD             -7
#define     NI_UNKNOWN_CARD_VERSION     -8
#define     NI_DISCONNECTION_ERROR      -9
#define     NI_INIT_ERROR               -10
#define     NI_READER_NOT_SUPPORTED     -11
#define     NI_LICENSE_FILE_ERROR       -12
#define     NI_PARAMETER_ERROR          -13
#define     NI_INTERNET_ERROR           -15
#define     NI_CARD_NOT_FOUND           -16
#define     NI_LICENSE_UPDATE_ERROR     -18




#define  NiOS_NotifyMessage   @"9b23321d-5cdf-4d26-b4c6-5fc08d98ec99"
#define  READERTYPE_USB_LTN     0x001
#define  READERTYPE_BLT         0x002
#define  READERTYPE_BLE         0x004
#define  READERTYPE_BUL         (READERTYPE_BLT|READERTYPE_USB_LTN)



@interface NiOS : NSObject  {
}



- (id) init;

-(SInt32)   openNiOSLibNi:(NSMutableString*) LICfile;
-(SInt32)   closeNiOSLibNi;
-(SInt32)   getReaderListNi:(NSMutableArray *)readerList;

-(SInt32)   selectReaderNi:(NSMutableString*) reader;
-(SInt32)   deselectReaderNi;
-(SInt32)   connectCardNi;
-(SInt32)   disconnectCardNi;
-(SInt32)   getNIDNumberNi:(NSMutableString*)strcardData;
-(SInt32)   getNIDPhotoNi:(NSMutableData *) strcardData;
-(SInt32)   getSoftwareInfoNi:(NSMutableString*) strcardData;
-(SInt32)   getLicenseInfoNi:(NSMutableString*) strcardData;
-(SInt32)   getNIDTextNi:(NSMutableString *) strcardData;
-(SInt32)   updateLicenseFileNi;
-(UInt32)   getContextNi;
-(UInt32)   getCardHandleNi;
-(SInt32)   attachContextNi:(UInt32) _hContextHandle;
-(SInt32)   detachContextNi;
-(SInt32)   getCardStatusNi;
-(SInt32)   getRidNi :(unsigned char *)strRidNi;



-(SInt32)   getReaderInfoNi:(NSMutableString*) strcardData;

-(SInt32)   scanReaderListBleNi:(NSMutableArray *)strReaderList : (SInt32)timeout;
-(SInt32)   stopReaderListBleNi;

-(SInt32)   getATextNi:(NSMutableString *) strcardData;


+(void)     setReaderTypeNi:(SInt32) nReaderType;


@end


#endif



