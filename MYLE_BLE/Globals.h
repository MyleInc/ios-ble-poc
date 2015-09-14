//
//  Globals.h
//  Myle
//
//  Created by Sergey Slobodenyuk on 25.09.14.
//  Copyright (c) 2014 Myle Electronics Corp. All rights reserved.
//

#import <Foundation/Foundation.h>


CGFloat iOSVersion();

/// right way to get path to Documents directory
NSString * DocumentsPath();


#define SETTINGS_PERIPHERAL_UUID @"PERIPHERAL_UUID"
#define SETTINGS_PERIPHERAL_PASS @"PERIPHERAL_PASS"

#define RecordFileFormat @"yyyy-MM-dd-HH-mm-ss"
#define TimeFormat @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

//string value to show the battery value has been read when the characteristic was discovered.
NSString* batteryValueStr;
