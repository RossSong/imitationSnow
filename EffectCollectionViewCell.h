//
//  EffectCollectionViewCell.h
//  TEST2
//
//  Created by RossSong on 2017. 5. 10..
//
//

#import <UIKit/UIKit.h>

@interface EffectCollectionViewCell : UICollectionViewCell
@property (retain, nonatomic) IBOutlet UIImageView *imageView;

-(void)setupImage:(NSString *)stringImageName;
@end
