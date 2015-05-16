//
//  Globals.m
//  Myle
//
//  Created by Sergey Slobodenyuk on 25.09.14.
//  Copyright (c) 2014 Myle Electronics Corp. All rights reserved.
//

#import "Globals.h"


/// right way to get path to Documents directory
NSString * DocumentsPath()
{
    static NSString *path;
    if (!path) {
        NSArray *cachesDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        path = cachesDirs[0];
    }
    return path;
}
