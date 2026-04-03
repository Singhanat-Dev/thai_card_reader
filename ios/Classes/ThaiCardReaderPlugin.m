#import "ThaiCardReaderPlugin.h"
#import "NidLib.h"
#import <UIKit/UIKit.h>

@interface ThaiCardReaderPlugin ()
@property (nonatomic, strong) NidLib *nidLib;
@end

@implementation ThaiCardReaderPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    ThaiCardReaderPlugin *instance = [[ThaiCardReaderPlugin alloc] init];

    // ── Method Channel: Flutter → Native ──
    FlutterMethodChannel *methodChannel = [FlutterMethodChannel
        methodChannelWithName:@"NiosLib/Api"
        binaryMessenger:[registrar messenger]];
    [registrar addMethodCallDelegate:instance channel:methodChannel];

    // ── BasicMessageChannel: NidLib progress events → Flutter ──
    FlutterBasicMessageChannel *messageChannel = [FlutterBasicMessageChannel
        messageChannelWithName:@"NiosLib/message"
        binaryMessenger:[registrar messenger]
        codec:[FlutterStringCodec sharedInstance]];

    instance.nidLib = [[NidLib alloc] init];
    [instance.nidLib bindMessageChannel:messageChannel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NidLib *lib = self.nidLib;

    // NidLib calls may block — run on a background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *method = call.method;
        NSDictionary *args = call.arguments;

        if ([method isEqualToString:@"openNiOSLibNi"]) {
            result([lib openNiOSLibNi:args[@"path"] ?: @""]);

        } else if ([method isEqualToString:@"updateLicenseFileNi"]) {
            result([lib updateLicenseFileNi]);

        } else if ([method isEqualToString:@"closeNiOSLibNi"]) {
            result([lib closeNiOSLibNi]);

        } else if ([method isEqualToString:@"getReaderListNi"]) {
            result([lib getReaderListNi]);

        } else if ([method isEqualToString:@"scanReaderListBleNi"]) {
            SInt32 timeout = [args[@"timeout"] intValue];
            result([lib scanReaderListBleNi:timeout]);

        } else if ([method isEqualToString:@"stopReaderListBleNi"]) {
            result([lib stopReaderListBleNi]);

        } else if ([method isEqualToString:@"selectReaderNi"]) {
            result([lib selectReaderNi:args[@"reader"] ?: @""]);

        } else if ([method isEqualToString:@"deselectReaderNi"]) {
            result([lib deselectReaderNi]);

        } else if ([method isEqualToString:@"readAllData"]) {
            result([lib readAllData]);

        } else if ([method isEqualToString:@"ExistApp"]) {
            result([lib ExistApp]);

        } else if ([method isEqualToString:@"getSoftwareInfoNi"]) {
            result([lib getSoftwareInfoNi]);

        } else if ([method isEqualToString:@"FtGetLibVersion"]) {
            result([lib FtGetLibVersion]);

        } else if ([method isEqualToString:@"FtGetDevVer"]) {
            result([lib FtGetDevVer]);

        } else if ([method isEqualToString:@"getReaderInfoNi"]) {
            result([lib getReaderInfoNi]);

        } else if ([method isEqualToString:@"FtGetSerialNum"]) {
            result([lib FtGetSerialNum]);

        } else if ([method isEqualToString:@"getRidNi"]) {
            result([lib getRidNi]);

        } else if ([method isEqualToString:@"getLicenseInfoNi"]) {
            result([lib getLicenseInfoNi]);

        } else if ([method isEqualToString:@"setReaderType"]) {
            SInt32 type = [args[@"readerType"] intValue];
            result([NidLib setReaderTypeNi:type]);

        } else if ([method isEqualToString:@"connectCardNi"]) {
            result([lib connectCardNi]);

        } else if ([method isEqualToString:@"getNIDTextNi"]) {
            result([lib getNIDTextNi]);

        } else if ([method isEqualToString:@"getNIDPhotoNi"]) {
            result([lib getNIDPhotoNi]);

        } else if ([method isEqualToString:@"disconnectCardNi"]) {
            result([lib disconnectCardNi]);

        } else if ([method isEqualToString:@"getBatteryLevel"]) {
            int level = [self getBatteryLevel];
            if (level == -1) {
                result([FlutterError errorWithCode:@"UNAVAILABLE"
                                           message:@"Battery level not available."
                                           details:nil]);
            } else {
                result(@(level));
            }

        } else {
            NSString *msg = [NSString stringWithFormat:@"{ \"ResCode\" : -999 , \"ResValue\" : \"%@\"} ", method];
            result(msg);
        }
    });
}

- (int)getBatteryLevel {
    UIDevice *device = UIDevice.currentDevice;
    device.batteryMonitoringEnabled = YES;
    if (device.batteryState == UIDeviceBatteryStateUnknown) return -1;
    return (int)(device.batteryLevel * 100);
}

@end
