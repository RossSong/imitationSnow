//
//  EffectCollectionViewCell.m
//  TEST2
//
//  Created by RossSong on 2017. 5. 10..
//
//

#import "EffectCollectionViewCell.h"

@implementation EffectCollectionViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)dealloc {
    [_imageView release];
    [super dealloc];
}

-(void)setupImage:(NSString *)stringImageName {
    NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:stringImageName];
    
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    self.imageView.image = image;
}

@end
