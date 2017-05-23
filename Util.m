//
//  Util.m
//  TEST2
//
//  Created by RossSong on 2017. 5. 23..
//
//

#import "Util.h"

@implementation Util

+ (UIColor *)colorWithRGBHex:(NSUInteger)RGBHex {
    CGFloat red = ((CGFloat)((RGBHex & 0xFF0000) >> 16)) / 255.0f;
    CGFloat green = ((CGFloat)((RGBHex & 0xFF00) >> 8)) / 255.0f;
    CGFloat blue = ((CGFloat)((RGBHex & 0xFF))) / 255.0f;
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.0f];
}

@end
