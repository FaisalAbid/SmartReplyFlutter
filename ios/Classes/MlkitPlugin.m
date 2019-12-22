#import "MlkitPlugin.h"
#import "Firebase/Firebase.h"
#import "AVFoundation/AVFoundation.h"
@import FirebaseMLCommon;

@implementation MlkitPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"plugins.flutter.io/mlkit"
                                     binaryMessenger:[registrar messenger]];
    MlkitPlugin* instance = [[MlkitPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    landmarkTypeMap = @{
                        @0:FIRFaceLandmarkTypeMouthBottom,
                        @1:FIRFaceLandmarkTypeLeftCheek,
                        @3:FIRFaceLandmarkTypeLeftEar,
                        @4:FIRFaceLandmarkTypeLeftEye,
                        @5:FIRFaceLandmarkTypeMouthLeft,
                        @6:FIRFaceLandmarkTypeNoseBase,
                        @7:FIRFaceLandmarkTypeRightCheek,
                        @9:FIRFaceLandmarkTypeRightEar,
                        @10:FIRFaceLandmarkTypeRightEye,
                        @11:FIRFaceLandmarkTypeMouthRight,
                        };
    localCustomModelMap = [NSMutableDictionary dictionary];
    remoteCustomModelMap = [NSMutableDictionary dictionary];
}

FIRVisionTextRecognizer *textDetector;
FIRVisionBarcodeDetector *barcodeDetector;
FIRVisionFaceDetector *faceDetector;
FIRVisionImageLabeler *labelDetector;

// android
//   https://firebase.google.com/docs/reference/android/com/google/firebase/ml/vision/face/FirebaseVisionFaceLandmark#BOTTOM_MOUTH
NSDictionary *landmarkTypeMap;
NSMutableDictionary *localCustomModelMap;
NSMutableDictionary *remoteCustomModelMap;
NSMutableArray *conversation;

- (instancetype)init {
    self = [super init];
    conversation =  [NSMutableArray array];
    if (self) {
        if (![FIRApp defaultApp]) {
            [FIRApp configure];
        }
    }
    return self;
}

UIImage* imageFromImageSourceWithData(NSData *data) {
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return image;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    FIRVision *vision = [FIRVision vision];
    NSMutableArray *ret = [NSMutableArray array];
    UIImage* uiImage = NULL;
    FIRVisionImage *image = NULL;

    if ([call.method hasSuffix:@"clear"]) {
        conversation =  [NSMutableArray array];
    }
    if ([call.method hasSuffix:@"createForLocalUser"]) {
// Then, for each message sent and received:
FIRTextMessage *message = [[FIRTextMessage alloc]
        initWithText:call.arguments[@"message"]
        timestamp:[NSDate date].timeIntervalSince1970
         userID:call.arguments[@"userId"]
        isLocalUser:NO];
[conversation addObject:message];
    }

     if ([call.method hasSuffix:@"createForRemoteUser"]) {
// Then, for each message sent and received:
FIRTextMessage *message = [[FIRTextMessage alloc]
        initWithText:call.arguments[@"message"]
        timestamp:[NSDate date].timeIntervalSince1970
        userID:call.arguments[@"userId"]
        isLocalUser:YES];
[conversation addObject:message];
     }


          if ([call.method hasSuffix:@"suggest"]) {
FIRNaturalLanguage *naturalLanguage = [FIRNaturalLanguage naturalLanguage];
FIRSmartReply *smartReply = [naturalLanguage smartReply];
[smartReply suggestRepliesForMessages:conversation
                           completion:^(FIRSmartReplySuggestionResult * _Nullable res,
                                        NSError * _Nullable error) {
  if (error || !res) {
   NSLog(@"Error: %@", error);
  result( [NSMutableArray array]);
    return;
  }
  if (res.status == FIRSmartReplyResultStatusNotSupportedLanguage) {
      // The conversation's language isn't supported, so the
      // the result doesn't contain any suggestions.
      NSLog(@"Nah");
      result( [NSMutableArray array]);
  } else if (res.status == FIRSmartReplyResultStatusSuccess) {
      NSLog(@"suggest");
      NSMutableArray *sugg = [NSMutableArray array];
      for (FIRSmartReplySuggestion *suggestion in res.suggestions) {
        [sugg addObject: suggestion.text];
        NSLog(@"Suggested reply: %@", suggestion.text);
      }
      result(sugg);
  }
}];
}
}

NSMutableArray *processList(NSObject * o) {
    __block NSMutableArray<NSObject *> *list =[NSMutableArray array];
    if ([o isKindOfClass:[NSArray class]]) {
        int length = [((NSArray *)o) count];
        for (int i = 0; i < length; i++) {
            NSObject *o2 = [((NSArray *)o) objectAtIndex:i];
            if ([o2 isKindOfClass:[NSArray class]]) {
                [list addObject:processList(o2)];
            } else {
                [list addObject:o2];
            }
        }
    } else {
        [list addObject:o];
    }
    return list;
}

NSDictionary *visionTextBlockToDictionary(FIRVisionTextBlock * visionTextBlock) {
    __block NSMutableArray<NSDictionary *> *points =[NSMutableArray array];
    [visionTextBlock.cornerPoints enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [points addObject:@{
                            @"x": @(((__bridge CGPoint *)obj)->x),
                            @"y": @(((__bridge CGPoint *)obj)->y),
                            }];
    }];
    NSMutableArray<NSDictionary *> *lines = [NSMutableArray array];
    for (FIRVisionTextLine *line in visionTextBlock.lines) {
        [lines addObject: visionTextLineToDictionary(line)];
    }
    return @{
             @"text" : visionTextBlock.text,
             @"rect_left": @(visionTextBlock.frame.origin.x),
             @"rect_top": @(visionTextBlock.frame.origin.y),
             @"rect_right": @(visionTextBlock.frame.origin.x + visionTextBlock.frame.size.width),
             @"rect_bottom": @(visionTextBlock.frame.origin.y + visionTextBlock.frame.size.height),
             @"lines": lines,
             @"points": points,
             };
}

NSDictionary *visionTextLineToDictionary(FIRVisionTextLine * visionTextLine) {
    __block NSMutableArray<NSDictionary *> *points =[NSMutableArray array];
    [visionTextLine.cornerPoints enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [points addObject:@{
                            @"x": @(((__bridge CGPoint *)obj)->x),
                            @"y": @(((__bridge CGPoint *)obj)->y),
                            }];
    }];
    
    NSMutableArray<NSDictionary *> *elements = [NSMutableArray array];
    for (FIRVisionTextElement *element in visionTextLine.elements) {
        [elements addObject: visionTextElementToDictionary(element)];
    }
    return @{
             @"text" : visionTextLine.text,
             @"rect_left": @(visionTextLine.frame.origin.x),
             @"rect_top": @(visionTextLine.frame.origin.y),
             @"rect_right": @(visionTextLine.frame.origin.x + visionTextLine.frame.size.width),
             @"rect_bottom": @(visionTextLine.frame.origin.y + visionTextLine.frame.size.height),
             @"elements": elements,
             @"points": points,
             };
}

NSDictionary *visionTextElementToDictionary(FIRVisionTextElement * visionTextElement) {
    __block NSMutableArray<NSDictionary *> *points =[NSMutableArray array];
    [visionTextElement.cornerPoints enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [points addObject:@{
                            @"x": @(((__bridge CGPoint *)obj)->x),
                            @"y": @(((__bridge CGPoint *)obj)->y),
                            }];
    }];
    return @{
             @"text" : visionTextElement.text,
             @"rect_left": @(visionTextElement.frame.origin.x),
             @"rect_top": @(visionTextElement.frame.origin.y),
             @"rect_right": @(visionTextElement.frame.origin.x + visionTextElement.frame.size.width),
             @"rect_bottom": @(visionTextElement.frame.origin.y + visionTextElement.frame.size.height),
             @"points": points,
             };
}

NSDictionary *visionBarcodeToDictionary(FIRVisionBarcode * barcode) {
    __block NSMutableArray<NSDictionary *> *points =[NSMutableArray array];
    [barcode.cornerPoints enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [points addObject:@{
                            @"x": @(((__bridge CGPoint *)obj)->x),
                            @"y": @(((__bridge CGPoint *)obj)->y),
                            }];
    }];
    return @{
             @"raw_value" : barcode.rawValue,
             @"display_value": barcode.displayValue ? barcode.displayValue : [NSNull null],
             @"rect_left": @(barcode.frame.origin.x),
             @"rect_top": @(barcode.frame.origin.y),
             @"rect_top": @(barcode.frame.origin.y),
             @"rect_right": @(barcode.frame.origin.x + barcode.frame.size.width),
             @"rect_bottom": @(barcode.frame.origin.y + barcode.frame.size.height),
             @"format": @(barcode.format),
             @"value_type": @(barcode.valueType),
             @"points": points,
             @"wifi": barcode.wifi ? visionBarcodeWiFiToDictionary(barcode.wifi) : [NSNull null],
             @"email": barcode.email ? visionBarcodeEmailToDictionary(barcode.email) : [NSNull null],
             @"phone": barcode.phone ? visionBarcodePhoneToDictionary(barcode.phone) : [NSNull null],
             @"sms": barcode.sms ? visionBarcodeSMSToDictionary(barcode.sms) : [NSNull null],
             @"url": barcode.URL ? visionBarcodeURLToDictionary(barcode.URL) : [NSNull null],
             @"geo_point": barcode.geoPoint ? visionBarcodeGeoPointToDictionary(barcode.geoPoint) : [NSNull null],
             @"contact_info": barcode.contactInfo ? visionBarcodeContactInfoToDictionary(barcode.contactInfo) : [NSNull null],
             @"calendar_event": barcode.calendarEvent ? visionBarcodeCalendarEventToDictionary(barcode.calendarEvent) : [NSNull null],
             @"driver_license": barcode.driverLicense ? visionBarcodeDriverLicenseToDictionary(barcode.driverLicense) : [NSNull null],
             };
}

NSDictionary *visionBarcodeWiFiToDictionary(FIRVisionBarcodeWiFi* wifi){
    return @{@"ssid": wifi.ssid,
             @"password": wifi.password,
             @"encryption_type": @(wifi.type),
             };
}

NSDictionary *visionBarcodeEmailToDictionary(FIRVisionBarcodeEmail* email){
    return @{@"address": email.address,
             @"body": email.body,
             @"subject": email.subject,
             @"type": @(email.type),
             };
}

NSDictionary *visionBarcodePhoneToDictionary(FIRVisionBarcodePhone* phone){
    return @{@"number": phone.number,
             @"type": @(phone.type),
             };
}

NSDictionary *visionBarcodeSMSToDictionary(FIRVisionBarcodeSMS* sms){
    return @{@"phone_number": sms.phoneNumber,
             @"message": sms.message,
             };
}

NSDictionary *visionBarcodeURLToDictionary(FIRVisionBarcodeURLBookmark* url){
    return @{@"title": url.title,
             @"url": url.url,
             };
}

NSDictionary *visionBarcodeGeoPointToDictionary(FIRVisionBarcodeGeoPoint* geo){
    return @{@"longitude": @(geo.longitude),
             @"latitude": @(geo.latitude),
             };
}

NSDictionary *visionBarcodeContactInfoToDictionary(FIRVisionBarcodeContactInfo* contact){
    __block NSMutableArray<NSDictionary *> *addresses =[NSMutableArray array];
    [contact.addresses enumerateObjectsUsingBlock:^(FIRVisionBarcodeAddress * _Nonnull address, NSUInteger idx, BOOL * _Nonnull stop) {
        __block NSMutableArray<NSString *> *addressLines =[NSMutableArray array];
        [address.addressLines enumerateObjectsUsingBlock:^(NSString * _Nonnull addressLine, NSUInteger idx, BOOL * _Nonnull stop) {
            [addressLines addObject:addressLine];
        }];
        [addresses addObject:@{
                               @"address_lines": addressLines,
                               @"type": @(address.type),
                               }];
    }];
    
    __block NSMutableArray<NSDictionary *> *emails =[NSMutableArray array];
    [contact.emails enumerateObjectsUsingBlock:^(FIRVisionBarcodeEmail * _Nonnull email, NSUInteger idx, BOOL * _Nonnull stop) {
        [emails addObject:@{
                            @"address": email.address,
                            @"body": email.body,
                            @"subjec": email.subject,
                            @"type": @(email.type),
                            }];
    }];
    
    __block NSMutableArray<NSDictionary *> *phones =[NSMutableArray array];
    [contact.phones enumerateObjectsUsingBlock:^(FIRVisionBarcodePhone * _Nonnull phone, NSUInteger idx, BOOL * _Nonnull stop) {
        [phones addObject:@{
                            @"number": phone.number,
                            @"type": @(phone.type),
                            }];
    }];
    
    __block NSMutableArray<NSString *> *urls =[NSMutableArray array];
    [contact.urls enumerateObjectsUsingBlock:^(NSString * _Nonnull url, NSUInteger idx, BOOL * _Nonnull stop) {
        [urls addObject:url];
    }];
    return @{@"addresses": addresses,
             @"emails": emails,
             @"name": @{
                     @"formatted_name": contact.name.formattedName,
                     @"first": contact.name.first,
                     @"last": contact.name.last,
                     @"middle": contact.name.middle,
                     @"prefix": contact.name.prefix,
                     @"pronounciation" : contact.name.pronounciation,
                     @"suffix": contact.name.suffix,
                     },
             @"phones": phones,
             @"urls": urls,
             @"job_title": contact.jobTitle,
             @"organization": contact.organization,
             };
}

NSDictionary  * visionBarcodeCalendarEventToDictionary(FIRVisionBarcodeCalendarEvent* calendar){
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'";
    dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    return @{@"event_description": calendar.eventDescription,
             @"location": calendar.location,
             @"organizer": calendar.organizer,
             @"status": calendar.status,
             @"summary": calendar.summary,
             @"start": [dateFormatter stringFromDate:calendar.start],
             @"end": [dateFormatter stringFromDate:calendar.end],
             };
}

NSDictionary *visionBarcodeDriverLicenseToDictionary(FIRVisionBarcodeDriverLicense* license){
    return @{@"first_name": license.firstName,
             @"middle_name": license.middleName,
             @"last_name": license.lastName,
             @"gender": license.gender,
             @"address_city": license.addressCity,
             @"address_state": license.addressState,
             @"address_zip": license.addressZip,
             @"birth_date": license.birthDate,
             @"document_type": license.documentType,
             @"license_number": license.licenseNumber,
             @"expiry_date": license.expiryDate,
             @"issuing_date": license.issuingDate,
             @"issuing_country": license.issuingCountry,
             };
}

NSDictionary *visionFaceToDictionary(FIRVisionFace* face){
    __block NSMutableDictionary *landmarks = [NSMutableDictionary dictionary];
    for (id key in landmarkTypeMap){
        FIRVisionFaceLandmark *landmark = [face landmarkOfType:landmarkTypeMap[key]];
        if(landmark != nil){
            NSDictionary *_landmark =@{
                                       @"position": @{
                                               @"x": landmark.position.x,
                                               @"y": landmark.position.y,
                                               @"z": landmark.position.z ? landmark.position.z : [NSNull null],
                                               },
                                       @"type": key,
                                       };
            [landmarks setObject:_landmark forKey:key];
        }
    }
    return @{
             @"rect_left": @(face.frame.origin.x),
             @"rect_top": @(face.frame.origin.y),
             @"rect_right": @(face.frame.origin.x + face.frame.size.width),
             @"rect_bottom": @(face.frame.origin.y + face.frame.size.height),
             @"has_tracking_id": @(face.hasTrackingID),
             @"tracking_id": @(face.trackingID),
             @"has_head_euler_angle_y": @(face.hasHeadEulerAngleY),
             @"head_euler_angle_y": @(face.headEulerAngleY),
             @"has_head_euler_angle_z": @(face.hasHeadEulerAngleZ),
             @"head_euler_angle_z": @(face.headEulerAngleZ),
             @"has_smiling_probability": @(face.hasSmilingProbability),
             @"smiling_probability": @(face.smilingProbability),
             @"has_right_eye_open_probability": @(face.hasRightEyeOpenProbability),
             @"right_eye_open_probability": @(face.rightEyeOpenProbability),
             @"has_left_eye_open_probability": @(face.hasLeftEyeOpenProbability),
             @"left_eye_open_probability": @(face.leftEyeOpenProbability),
             @"landmarks": landmarks,
             };
}

NSDictionary *visionLabelToDictionary(FIRVisionImageLabel *label){
    return @{@"label" : label.text,
             @"entityID" : label.entityID,
             @"confidence" : label.confidence,
             };
}

@end