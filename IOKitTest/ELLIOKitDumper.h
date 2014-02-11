//
//  ELLIOKitDumper.h
//  IOKitTest
//
//  Created by Christopher Anderson on 10/02/2014.
//  Copyright (c) 2014 Electric Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ELLIOKitNodeInfo;

@interface ELLIOKitDumper : NSObject

- (ELLIOKitNodeInfo *)dumpIOKitTree;

@end
