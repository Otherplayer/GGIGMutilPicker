//
//  GGCamera.h
//  __无邪_
//
//  Created by __无邪_ on 15/4/28.
//  Copyright (c) 2015年 __无邪_. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface GGCamera : NSObject
+ (instancetype)sharedInstance;

- (void)showCameraResult:(void(^)(UIImage *image))resultBlock; /*  */
- (void)showCameraResults:(void(^)(NSArray *images))resultBlock; /*  */
- (void)showCameraResultWithUrl:(void (^)(NSString *imageurl))resultBlock;

- (void)saveImageToAlbum:(UIImage *)image;

@end
