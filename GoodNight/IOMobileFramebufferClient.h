//
//  IOMobileFramebufferClient.h
//  GoodNight
//
//  Created by Manu Wallner on 11.12.2015.
//  Copyright © 2015 ADA Tech, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, IOMobileFramebufferColorRemapMode) {
    IOMobileFramebufferColorRemapModeError = -1,
    IOMobileFramebufferColorRemapModeNormal = 0,
    IOMobileFramebufferColorRemapModeInverted = 1,
    IOMobileFramebufferColorRemapModeGrayscale = 2,
    IOMobileFramebufferColorRemapModeGrayscaleIncreaseContrast = 3,
    IOMobileFramebufferColorRemapModeInvertedGrayscale = 4
};

typedef struct {
    uint32_t values[0xc0c/sizeof(uint32_t)];
} IOMobileFramebufferGammaTable;

typedef long s1516;  // 32bit 2's complement signed integer

typedef struct {
    s1516 matrix[9];
    
    char unknown[9 * sizeof(uint32_t)];
//    union {
//        uint64_t asInteger;
//        struct {
//            char padding[2];
//            uint32_t high;
//            uint16_t low;
//        } real;
//        struct {
//            char padding[2];
//            s1516 num;
//            char padding2[2];
//        } pads15f16pad;
//        struct {
//            s1516 num;
//            char padding[2];
//            char padding2[2];
//        } s15f16padpad;
//        struct {
//            char padding[2];
//            char padding2[2];
//            s1516 num;
//        } padpads15f16;
//    } values[5];
//    
//    char unknown[4*sizeof(uint64_t)];
} IOMobileFramebufferGamutMatrix;

@interface IOMobileFramebufferClient : NSObject

- (IOMobileFramebufferColorRemapMode)colorRemapMode;
- (void)setColorRemapMode:(IOMobileFramebufferColorRemapMode)mode;

- (void)gammaTable:(IOMobileFramebufferGammaTable *)table;
- (void)setGammaTable:(IOMobileFramebufferGammaTable *)table;

- (void)gamutMatrix:(IOMobileFramebufferGamutMatrix *)matrix;
- (void)setGamutMatrix:(IOMobileFramebufferGamutMatrix *)matrix;

@end
