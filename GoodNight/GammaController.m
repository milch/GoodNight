//
//  GammaController.m
//  GoodNight
//
//  Created by Anthony Agatiello on 6/22/15.
//  Copyright © 2015 ADA Tech, LLC. All rights reserved.
//

#import "GammaController.h"

#import "NSDate+Extensions.h"
#include <dlfcn.h>

#import "Solar.h"
#import "Brightness.h"
#import "IOMobileFramebufferClient.h"

@implementation GammaController

+ (IOMobileFramebufferClient *)framebufferClient {
    static IOMobileFramebufferClient *_client = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _client = IOMobileFramebufferClient.new;
    });

    return _client;
}

+ (BOOL)invertScreenColours:(BOOL)invert {
    IOMobileFramebufferColorRemapMode mode = [self.framebufferClient colorRemapMode];

    [self.framebufferClient setColorRemapMode:invert ? IOMobileFramebufferColorRemapModeInverted : IOMobileFramebufferColorRemapModeNormal];

    return invert ? mode != IOMobileFramebufferColorRemapModeInverted : mode != IOMobileFramebufferColorRemapModeNormal;
}

+ (void)setDarkroomEnabled:(BOOL)enable {
    if (enable) {
        if ([self invertScreenColours:YES]) {
            [self setGammaWithRed:1.0f green:0.0f blue:0.0f];
        }
    }
    else {
        if ([self invertScreenColours:NO]) {
            [self setGammaWithRed:1.0f green:1.0f blue:1.0f];
            [userDefaults setFloat:1.0f forKey:@"currentOrange"];
            [self autoChangeOrangenessIfNeededWithTransition:NO];
        }
    }
}
double s1516tofloat(s1516 f) {
    return (double)((f-0.5f) / 65536.);
}

+ (void)setGammaWithRed:(float)red green:(float)green blue:(float)blue {
    
    IOMobileFramebufferGamutMatrix gamutMatrix;
    memset(&gamutMatrix, 0, sizeof(gamutMatrix));
    
    gamutMatrix.content.matrix[0][0] = GamutMatrixValue(red);
    gamutMatrix.content.matrix[1][1] = GamutMatrixValue(green);
    gamutMatrix.content.matrix[2][2] = GamutMatrixValue(blue);
    
    NSLog(@"Before save: -------");
    NSLog(@"Red: %f", s1516tofloat(gamutMatrix.content.matrix[0][0]));
    NSLog(@"Green: %f", s1516tofloat(gamutMatrix.content.matrix[1][1]));
    NSLog(@"Blue: %f", s1516tofloat(gamutMatrix.content.matrix[2][2]));
    
    [self.framebufferClient setGamutMatrix:&gamutMatrix];
    [self.framebufferClient gamutMatrix:&gamutMatrix];
    
    NSLog(@"After save: -------");
    NSLog(@"Red: %f", s1516tofloat(gamutMatrix.content.matrix[0][0]));
    NSLog(@"Green: %f", s1516tofloat(gamutMatrix.content.matrix[1][1]));
    NSLog(@"Blue: %f", s1516tofloat(gamutMatrix.content.matrix[2][2]));
    
}

+ (void)setGammaWithOrangeness:(float)percentOrange {
    if (percentOrange > 1 || percentOrange < 0) {
        return;
    }
    
    float hectoKelvin = percentOrange * 45 + 20;
    float red = 255.0;
    float green = -155.25485562709179 + -0.44596950469579133 * (hectoKelvin - 2) + 104.49216199393888 * log(hectoKelvin - 2);
    float blue = -254.76935184120902 + 0.8274096064007395 * (hectoKelvin - 10) + 115.67994401066147 * log(hectoKelvin - 10);
    
    if (percentOrange == 1) {
        green = 255.0;
        blue = 255.0;
    }
    
    red /= 255.0;
    green /= 255.0;
    blue /= 255.0;
    
    [self setGammaWithRed:red green:green blue:blue];
}

+ (void)autoChangeOrangenessIfNeededWithTransition:(BOOL)transition {
    if (![userDefaults boolForKey:@"colorChangingEnabled"] && ![userDefaults boolForKey:@"colorChangingLocationEnabled"]) {
        return;
    }
    
    BOOL nightModeWasEnabled = NO;
    
    if ([userDefaults boolForKey:@"colorChangingNightEnabled"] && [userDefaults boolForKey:@"enabled"]) {
        TimeBasedAction nightAction = [self timeBasedActionForPrefix:@"night"];
        switch (nightAction) {
            case SwitchToOrangeness:
                [self enableOrangenessWithDefaults:YES transition:YES orangeLevel:[userDefaults floatForKey:@"nightOrange"]];
                [userDefaults setBool:NO forKey:@"dimEnabled"];
                [userDefaults setBool:NO forKey:@"rgbEnabled"];
            case KeepOrangenessEnabled:
                nightModeWasEnabled = YES;
                break;
            default:
                break;
        }
    }

    if (!nightModeWasEnabled){
        if ([userDefaults boolForKey:@"colorChangingLocationEnabled"]) {
            [self switchScreenTemperatureBasedOnLocation];
        }
        else if ([userDefaults boolForKey:@"colorChangingEnabled"]){
            TimeBasedAction autoAction = [self timeBasedActionForPrefix:@"auto"];
            
            switch (autoAction) {
                case SwitchToOrangeness:
                    [self enableOrangenessWithDefaults:YES transition:YES];
                    [userDefaults setBool:NO forKey:@"dimEnabled"];
                    [userDefaults setBool:NO forKey:@"rgbEnabled"];
                    break;
                case SwitchToStandard:
                    [self disableOrangeness];
                    [userDefaults setBool:NO forKey:@"dimEnabled"];
                    [userDefaults setBool:NO forKey:@"rgbEnabled"];
                    break;
                default:
                    break;
            }
        }
    }
    
    [userDefaults setObject:[NSDate date] forKey:@"lastAutoChangeDate"];
    [userDefaults synchronize];
}

+ (void)enableOrangenessWithDefaults:(BOOL)defaults transition:(BOOL)transition {
    float orangeLevel = [userDefaults floatForKey:@"maxOrange"];
    [self enableOrangenessWithDefaults:defaults transition:transition orangeLevel:orangeLevel];
}

+ (void)enableOrangenessWithDefaults:(BOOL)defaults transition:(BOOL)transition orangeLevel:(float)orangeLevel {
    float currentOrangeLevel = [userDefaults floatForKey:@"currentOrange"];
    if (currentOrangeLevel == orangeLevel) {
        return;
    }
    
    [self wakeUpScreenIfNeeded];
    if (transition == YES) {
        [self setGammaWithTransitionFrom:currentOrangeLevel to:orangeLevel];
    }
    else {
        [self setGammaWithOrangeness:orangeLevel];
    }
    if (defaults == YES) {
        [userDefaults setObject:[NSDate date] forKey:@"lastAutoChangeDate"];
        [userDefaults setBool:YES forKey:@"enabled"];
    }
    
    [userDefaults setObject:@"0" forKey:@"keyEnabled"];
    [userDefaults setFloat:orangeLevel forKey:@"currentOrange"];
    [userDefaults synchronize];
}

+ (void)setGammaWithTransitionFrom:(float)oldPercentOrange to:(float)newPercentOrange {
    static NSOperationQueue *queue = nil;

    if (!queue) {
        queue = [NSOperationQueue new];
    }
    
    [queue cancelAllOperations];
    
    NSBlockOperation *operation = [[NSBlockOperation alloc] init];
    __weak NSBlockOperation *weakOperation = operation;
    [operation addExecutionBlock:^{
        if (newPercentOrange > oldPercentOrange) {
            for (float i = oldPercentOrange; i <= newPercentOrange; i = i + 0.01) {
                if (weakOperation.isCancelled) break;
                if (i > 0.99) {
                    i = 1.0f;
                }
                [NSThread sleepForTimeInterval:0.02];
                [self setGammaWithOrangeness:i];
            }
        }
        else {
            for (float i = oldPercentOrange; i >= newPercentOrange; i = i - 0.01) {
                if (weakOperation.isCancelled) break;
                if (i < 0.01) {
                    i = 0.0f;
                }
                [NSThread sleepForTimeInterval:0.02];
                [self setGammaWithOrangeness:i];
            }
        }
    }];
    
    if ([operation respondsToSelector:@selector(setQualityOfService:)]) {
        [operation setQualityOfService:NSQualityOfServiceUserInteractive];
    }
    else {
        [operation setThreadPriority:1.0f];
    }
    operation.queuePriority = NSOperationQueuePriorityVeryHigh;
    [queue addOperation:operation];
}

+ (void)disableOrangenessWithDefaults:(BOOL)defaults key:(NSString *)key transition:(BOOL)transition {

    [self wakeUpScreenIfNeeded];
    if (transition == YES) {
        float currentOrangeLevel = [userDefaults floatForKey:@"currentOrange"];
        [self setGammaWithTransitionFrom:currentOrangeLevel to:1.0];
    }
    else {
        [self setGammaWithOrangeness:1.0];
    }
    if (defaults == YES) {
        [userDefaults setObject:[NSDate date] forKey:@"lastAutoChangeDate"];
        [userDefaults setBool:NO forKey:key];
    }
    [userDefaults setFloat:1.0 forKey:@"currentOrange"];
    [userDefaults synchronize];
}

+ (BOOL)wakeUpScreenIfNeeded {
    void *SpringBoardServices = dlopen(SBS_PATH, RTLD_LAZY);
    NSParameterAssert(SpringBoardServices);
    mach_port_t (*SBSSpringBoardServerPort)() = dlsym(SpringBoardServices, "SBSSpringBoardServerPort");
    NSParameterAssert(SBSSpringBoardServerPort);
    mach_port_t sbsMachPort = SBSSpringBoardServerPort();
    BOOL isLocked, passcodeEnabled;
    void *(*SBGetScreenLockStatus)(mach_port_t port, BOOL *isLocked, BOOL *passcodeEnabled) = dlsym(SpringBoardServices, "SBGetScreenLockStatus");
    NSParameterAssert(SBGetScreenLockStatus);
    SBGetScreenLockStatus(sbsMachPort, &isLocked, &passcodeEnabled);
    
    if (isLocked) {
        void *(*SBSUndimScreen)() = dlsym(SpringBoardServices, "SBSUndimScreen");
        NSParameterAssert(SBSUndimScreen);
        SBSUndimScreen();
    }
    
    dlclose(SpringBoardServices);
    return !isLocked;
    
}

+ (BOOL)checkCompatibility {
    
    BOOL compatible = YES;
    
    void *libMobileGestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_GLOBAL | RTLD_LAZY);
    NSParameterAssert(libMobileGestalt);
    CFStringRef (*MGCopyAnswer)(CFStringRef model) = dlsym(libMobileGestalt, "MGCopyAnswer");
    NSParameterAssert(MGCopyAnswer);
    NSString *hwModelStr = CFBridgingRelease(MGCopyAnswer(CFSTR("HWModelStr")));
    
    if ([hwModelStr isEqualToString:@"J98aAP"] || [hwModelStr isEqualToString:@"J99aAP"]) {
        compatible = NO;
    }

    dlclose(libMobileGestalt);
    
    return compatible;
}

+ (void)enableDimness {
    float dimLevel = [userDefaults floatForKey:@"dimLevel"];
    [self setGammaWithRed:dimLevel green:dimLevel blue:dimLevel];
    [userDefaults setBool:YES forKey:@"dimEnabled"];
    [userDefaults setObject:@"0" forKey:@"keyEnabled"];
    [userDefaults synchronize];
}

+ (void)setGammaWithCustomValues {
    float redValue = [userDefaults floatForKey:@"redValue"];
    float greenValue = [userDefaults floatForKey:@"greenValue"];
    float blueValue = [userDefaults floatForKey:@"blueValue"];
    [self setGammaWithRed:redValue green:greenValue blue:blueValue];
    [userDefaults setBool:YES forKey:@"rgbEnabled"];
    [userDefaults setObject:@"0" forKey:@"keyEnabled"];

    [userDefaults synchronize];
}

+ (void)disableColorAdjustment {
    [self disableOrangenessWithDefaults:YES key:@"rgbEnabled" transition:NO];
}

+ (void)disableDimness {
    [self disableOrangenessWithDefaults:YES key:@"dimEnabled" transition:NO];
}

+ (void)disableOrangeness {
    float currentOrangeLevel = [userDefaults floatForKey:@"currentOrange"];
    if (!(currentOrangeLevel < 1.0f)) {
        return;
    }
    [self disableOrangenessWithDefaults:YES key:@"enabled" transition:YES];
}

+ (void)switchScreenTemperatureBasedOnLocation {
    float latitude = [userDefaults floatForKey:@"colorChangingLocationLatitude"];
    float longitude = [userDefaults floatForKey:@"colorChangingLocationLongitude"];
    
    double solarAngularElevation = solar_elevation([[NSDate date] timeIntervalSince1970], latitude, longitude);
    float maxOrange = [userDefaults floatForKey:@"maxOrange"];
    float maxOrangePercentage = maxOrange * 100;
    float orangeness = (calculate_interpolated_value(solarAngularElevation, 0, maxOrangePercentage) / 100);
    
    if(orangeness > 0) {
        float percent = orangeness / maxOrange;
        float diff = 1.0f - maxOrange;
        [self enableOrangenessWithDefaults:YES transition:YES orangeLevel:MIN(1.0f-percent*diff, 1.0f)];
    }
    else if (orangeness <= 0) {
        [self disableOrangeness];
    }
}

+ (TimeBasedAction)timeBasedActionForPrefix:(NSString*)autoOrNightPrefix{
    if (!autoOrNightPrefix || (![autoOrNightPrefix isEqualToString:@"auto"] && ![autoOrNightPrefix isEqualToString:@"night"])){
        autoOrNightPrefix = @"auto";
    }
    
    NSDate *currentDate = [NSDate date];
    NSDateComponents *autoOnOffComponents = [[NSCalendar currentCalendar] components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:[NSDate date]];
    autoOnOffComponents.hour = [userDefaults integerForKey:[autoOrNightPrefix stringByAppendingString:@"StartHour"]];
    autoOnOffComponents.minute = [userDefaults integerForKey:[autoOrNightPrefix stringByAppendingString:@"StartMinute"]];
    NSDate *turnOnDate = [[NSCalendar currentCalendar] dateFromComponents:autoOnOffComponents];
    
    autoOnOffComponents.hour = [userDefaults integerForKey:[autoOrNightPrefix stringByAppendingString:@"EndHour"]];
    autoOnOffComponents.minute = [userDefaults integerForKey:[autoOrNightPrefix stringByAppendingString:@"EndMinute"]];
    NSDate *turnOffDate = [[NSCalendar currentCalendar] dateFromComponents:autoOnOffComponents];
    
    if ([turnOnDate isLaterThan:turnOffDate]) {
        if ([currentDate isEarlierThan:turnOnDate] && [currentDate isEarlierThan:turnOffDate]) {
            autoOnOffComponents.day = autoOnOffComponents.day - 1;
            turnOnDate = [[NSCalendar currentCalendar] dateFromComponents:autoOnOffComponents];
        }
        else if ([turnOnDate isEarlierThan:currentDate] && [turnOffDate isEarlierThan:currentDate]) {
            autoOnOffComponents.day = autoOnOffComponents.day + 1;
            turnOffDate = [[NSCalendar currentCalendar] dateFromComponents:autoOnOffComponents];
        }
    }
    
    if ([turnOnDate isEarlierThan:currentDate] && [turnOffDate isLaterThan:currentDate]) {
        if ([turnOnDate isLaterThan:[userDefaults objectForKey:@"lastAutoChangeDate"]]) {
            return SwitchToOrangeness;
        }
        return KeepOrangenessEnabled;
    }
    else {
        if ([turnOffDate isLaterThan:[userDefaults objectForKey:@"lastAutoChangeDate"]]) {
            return SwitchToStandard;
        }
        return KeepStandardEnabled;
    }
}

+ (void)suspendApp {
    void *SpringBoardServices = dlopen(SBS_PATH, RTLD_LAZY);
    NSParameterAssert(SpringBoardServices);
    mach_port_t (*SBSSpringBoardServerPort)() = dlsym(SpringBoardServices, "SBSSpringBoardServerPort");
    NSParameterAssert(SBSSpringBoardServerPort);
    SpringBoardServicesReturn (*SBSuspend)(mach_port_t port) = dlsym(SpringBoardServices, "SBSuspend");
    NSParameterAssert(SBSuspend);
    mach_port_t sbsMachPort = SBSSpringBoardServerPort();
    SBSuspend(sbsMachPort);
    dlclose(SpringBoardServices);
}

+ (BOOL)adjustmentForKeysEnabled:(NSString *)firstKey, ... {
    
    BOOL adjustmentsEnabled = NO;
    
    va_list args;
    va_start(args, firstKey);
    for (NSString *arg = firstKey; arg != nil; arg = va_arg(args, NSString*))
    {
        if ([userDefaults boolForKey:arg]){
            adjustmentsEnabled = YES;
            break;
        }
    }
    va_end(args);

    return adjustmentsEnabled;
}

@end