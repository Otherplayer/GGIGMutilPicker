//
//  GGCamera.m
//  __无邪_
//
//  Created by __无邪_ on 15/4/28.
//  Copyright (c) 2015年 __无邪_. All rights reserved.
//

#import "GGCamera.h"
#import "AGImagePickerController.h"

#import "AppDelegate.h"
#import <objc/runtime.h>


#define kTitle @"title"
#define kSourceType @"sourcetype"
static const char GGCameraDidFinishPickerImage;
static const char GGCameraDidFinishPickerImageUrl;

@interface GGCamera ()<UINavigationControllerDelegate,UIImagePickerControllerDelegate,UIActionSheetDelegate,AGImagePickerControllerDelegate>{
    AGImagePickerController *ipc;
}
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, assign) BOOL isMutableSelected;

@end

@implementation GGCamera

+ (instancetype)sharedInstance{
    static GGCamera *camera = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        camera = [[GGCamera alloc] init];
        camera.items = [[NSMutableArray alloc] init];
    });
    return camera;
}


#pragma mark - public

- (void)showCameraResult:(void (^)(UIImage *))resultBlock{
    
    [self showCameraSingleSelected:YES];
    objc_setAssociatedObject(self, &GGCameraDidFinishPickerImage, resultBlock, OBJC_ASSOCIATION_COPY);
    
}

- (void)showCameraResults:(void(^)(NSArray *images))resultBlock{
    [self showCameraSingleSelected:NO];
    objc_setAssociatedObject(self, &GGCameraDidFinishPickerImage, resultBlock, OBJC_ASSOCIATION_COPY);
}

- (void)showCameraResultWithUrl:(void (^)(NSString *imageurl))resultBlock{
    [self showCamera];
    objc_setAssociatedObject(self, &GGCameraDidFinishPickerImageUrl, resultBlock, OBJC_ASSOCIATION_COPY);
}


#pragma mark - Function

- (void)showCamera{
    [self showCameraSingleSelected:YES];
}

- (void)showCameraSingleSelected:(BOOL)flag{
    BOOL photoLibraryAvailable = [self isPhotoLibraryAvailable];
    BOOL rearCameraAvailable = [self isRearCameraAvailable];
    
    if (flag) {
        self.isMutableSelected = YES;
    }else{
        self.isMutableSelected = NO;
    }
    
    [self.items removeAllObjects];
    
    if (rearCameraAvailable) {
        [self.items addObject:@{kTitle:@"拍照",kSourceType:@(UIImagePickerControllerSourceTypeCamera)}];
    }
    if (photoLibraryAvailable) {
        if (flag) {
            [self.items addObject:@{kTitle:@"从相册选择",kSourceType:@(UIImagePickerControllerSourceTypePhotoLibrary)}];
        }else{
            [self.items addObject:@{kTitle:@"从相册选择",kSourceType:@(UIImagePickerControllerSourceTypeSavedPhotosAlbum)}];//2
        }
    }
    
    
    UIActionSheet *actionSheet;
    if (0 == self.items.count) {
        actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:@"Device Unavailable" otherButtonTitles:nil];
    }else if (1 == self.items.count){
        actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:[self.items[0] objectForKey:kTitle] otherButtonTitles:nil];
    }else{
        actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:[self.items[0] objectForKey:kTitle],[self.items[1] objectForKey:kTitle],nil];
    }
    
    UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
    [actionSheet setDelegate:self];
    [actionSheet showInView:window];
}


#pragma mark - Delegate ActionSheets
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    if (0 == self.items.count || buttonIndex >= self.items.count) {
        return;
    }
    
    NSDictionary *dic = [self.items objectAtIndex:buttonIndex];
    NSUInteger sourceType = [[dic objectForKey:kSourceType] integerValue];
    
    // 延迟3毫秒,iOS 7 bug of Snapshotting a view that has not been rendered results...
    double delayInSeconds = 0.15;
    dispatch_time_t delayInNanoSeconds =dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    // 得到全局队列
    dispatch_queue_t concurrentQueue = dispatch_get_main_queue();
    // 延期执行
    dispatch_after(delayInNanoSeconds, concurrentQueue, ^(void){
        [self showCameraWithSourceType:sourceType];
    });
    
}

- (void)showCameraWithSourceType:(NSUInteger)sourceType{
    
    if (sourceType == UIImagePickerControllerSourceTypeSavedPhotosAlbum) {
        //多选
        [self configureAGPicker];
        
    }else{
        // 跳转到相机或相册页面
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
        imagePickerController.delegate = self;
        // imagePickerController.allowsEditing = YES;
        imagePickerController.sourceType = sourceType;
        
        AppDelegate *appdelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        UIViewController *rootViewController = [[appdelegate window] rootViewController];
        [rootViewController presentViewController:imagePickerController animated:YES completion:^{}];
    }
}

#pragma mark - Delegate Methods of imagePicker
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    double delayInSeconds = 0.15;
    dispatch_time_t delayInNanoSeconds =dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    // 得到全局队列
    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    // 延期执行
    dispatch_after(delayInNanoSeconds, concurrentQueue, ^(void){
        if (self.isMutableSelected) {
            NSMutableArray *images = [[NSMutableArray alloc] initWithObjects:image, nil];
            void (^block)(NSArray *imgs) = objc_getAssociatedObject(self, &GGCameraDidFinishPickerImage);
            if (block) block(images);
        }else{
            
            void (^block)(UIImage *img) = objc_getAssociatedObject(self, &GGCameraDidFinishPickerImage);
            if (block) block(image);
        }
        
        
        // 拍照时保存
        /*if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
         UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
         }*/
        
        NSDate *date = [NSDate date];
        NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyyMMddHHMMSS"];
        NSString* imageName = [formatter stringFromDate:date];
        [self saveImage:image withName:imageName];
        
    });
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}


- (void)imageSavedToPhotosAlbum:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo{
    NSString *message = @"保存失败";
    if (!error) {
        message = @"保存图片成功";
    }else{
        message = [error description];
    }
//    [HYQShowTip showTipTextOnly:message dealy:1.2];
}

#pragma mark - private

// 保存到本地
- (void)saveImageToAlbum:(UIImage *)image{
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(imageSavedToPhotosAlbum:didFinishSavingWithError:contextInfo:), nil);
}
// 实现imageSavedToPhotosAlbum:didFinishSavingWithError:contextInfo:方法
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo{
    NSLog(@"%@",error);
}


- (void)saveImage:(UIImage *)currentImage withName:(NSString *)imageName{
    NSData *imageData = UIImagePNGRepresentation(currentImage);
    // 获取沙盒目录
    NSString *fullPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:imageName];
    // 将图片写入文件
    [imageData writeToFile:fullPath atomically:YES];
    
    void (^block)(NSString *imgurl) = objc_getAssociatedObject(self, &GGCameraDidFinishPickerImageUrl);
    if (block) block(imageName);
}



#pragma mark - AGImagePickerControllerDelegate
- (void)configureAGPicker{
    AppDelegate *appdelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    UIViewController *rootViewController = [[appdelegate window] rootViewController];
    
    __weak __typeof(&*self)fuckSelf = self;

    ipc = [AGImagePickerController sharedInstance:self];
    ipc.didFailBlock = ^(NSError *error) {
        NSLog(@"Fail. Error: %@", error);
        
        if (error == nil) {
            NSLog(@"User has cancelled.");
            [rootViewController dismissViewControllerAnimated:YES completion:nil];
        } else {
            
            // We need to wait for the view controller to appear first.
            double delayInSeconds = 0.5;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [rootViewController dismissViewControllerAnimated:YES completion:nil];
            });
        }
        
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
        
    };
    ipc.didFinishBlock = ^(NSArray *info) {
        
        NSMutableArray *images = [[NSMutableArray alloc] init];
        for (int i = 0; i < info.count; i++) {
            ALAsset *asset=[info objectAtIndex:i];
            UIImage *image=[UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage];
            [images addObject:image];
        }
        
        void (^block)(NSArray *imgs) = objc_getAssociatedObject(fuckSelf, &GGCameraDidFinishPickerImage);
        if (block) block(images);

        [rootViewController dismissViewControllerAnimated:YES completion:nil];
        
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
    };
    
    // Show saved photos on top
    ipc.shouldShowSavedPhotosOnTop = NO;
    ipc.shouldChangeStatusBarStyle = YES;
    ipc.maximumNumberOfPhotosToBeSelected = 6;
    
    // Custom toolbar items
    //    AGIPCToolbarItem *selectAll = [[AGIPCToolbarItem alloc] initWithBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:@"+ Select All" style:UIBarButtonItemStyleBordered target:nil action:nil] andSelectionBlock:^BOOL(NSUInteger index, ALAsset *asset) {
    //        return YES;
    //    }];
    //    AGIPCToolbarItem *flexible = [[AGIPCToolbarItem alloc] initWithBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] andSelectionBlock:nil];
    //    AGIPCToolbarItem *selectOdd = [[AGIPCToolbarItem alloc] initWithBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:@"+ Select Odd" style:UIBarButtonItemStyleBordered target:nil action:nil] andSelectionBlock:^BOOL(NSUInteger index, ALAsset *asset) {
    //        return !(index % 2);
    //    }];
    //    AGIPCToolbarItem *deselectAll = [[AGIPCToolbarItem alloc] initWithBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:@"- Deselect All" style:UIBarButtonItemStyleBordered target:nil action:nil] andSelectionBlock:^BOOL(NSUInteger index, ALAsset *asset) {
    //        return NO;
    //    }];
    //    ipc.toolbarItemsForManagingTheSelection = @[selectAll, flexible, selectOdd, flexible, deselectAll];
    
    [rootViewController presentViewController:ipc animated:YES completion:nil];
    
    // Show first assets list, modified by springox(20140503)
    [ipc showFirstAssetsController];
    
    //// Show assets list with name, added by springox(20150719)
    //[ipc showAssetsControllerWithName:@"Camera Roll"];
    
    
}

#pragma mark - AGImagePickerControllerDelegate methods

//- (NSUInteger)agImagePickerController:(AGImagePickerController *)picker
//         numberOfItemsPerRowForDevice:(AGDeviceType)deviceType
//              andInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
//{
//    if (deviceType == AGDeviceTypeiPad)
//    {
//        if (UIInterfaceOrientationIsLandscape(interfaceOrientation))
//            return 11;
//        else
//            return 8;
//    } else {
//        if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
//            if (480 == self.view.bounds.size.width) {
//                return 6;
//            }
//            return 7;
//        } else
//            return 4;
//    }
//}
//
//- (BOOL)agImagePickerController:(AGImagePickerController *)picker shouldDisplaySelectionInformationInSelectionMode:(AGImagePickerControllerSelectionMode)selectionMode
//{
//    return (selectionMode == AGImagePickerControllerSelectionModeSingle ? NO : YES);
//}
//
//- (BOOL)agImagePickerController:(AGImagePickerController *)picker shouldShowToolbarForManagingTheSelectionInSelectionMode:(AGImagePickerControllerSelectionMode)selectionMode{
//    return (selectionMode == AGImagePickerControllerSelectionModeSingle ? NO : YES);
//}
//
//- (AGImagePickerControllerSelectionBehaviorType)selectionBehaviorInSingleSelectionModeForAGImagePickerController:(AGImagePickerController *)picker{
//    return AGImagePickerControllerSelectionBehaviorTypeRadio;
//}








#pragma mark - 摄像头和相册相关的公共类

// 判断设备是否有摄像头
- (BOOL) isCameraAvailable{
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}

// 前面的摄像头是否可用
- (BOOL) isFrontCameraAvailable{
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];
}

// 后面的摄像头是否可用
- (BOOL) isRearCameraAvailable{
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear];
}


// 判断是否支持某种多媒体类型：拍照，视频
- (BOOL) cameraSupportsMedia:(NSString *)paramMediaType sourceType:(UIImagePickerControllerSourceType)paramSourceType{
    __block BOOL result = NO;
    if ([paramMediaType length] == 0){
        NSLog(@"Media type is empty.");
        return NO;
    }
    NSArray *availableMediaTypes =[UIImagePickerController availableMediaTypesForSourceType:paramSourceType];
    [availableMediaTypes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL*stop) {
        NSString *mediaType = (NSString *)obj;
        if ([mediaType isEqualToString:paramMediaType]){
            result = YES;
            *stop= YES;
        }
        
    }];
    return result;
}

//// 检查摄像头是否支持录像
//- (BOOL) doesCameraSupportShootingVideos{
//    return [self cameraSupportsMedia:(NSString *)kUTTypeMoviesourceType:UIImagePickerControllerSourceTypeCamera];
//}
//
//// 检查摄像头是否支持拍照
//- (BOOL) doesCameraSupportTakingPhotos{
//    return [self cameraSupportsMedia:(NSString *)kUTTypeImagesourceType:UIImagePickerControllerSourceTypeCamera];
//}

#pragma mark - 相册文件选取相关
// 相册是否可用
- (BOOL) isPhotoLibraryAvailable{
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary] || [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
}


// 是否可以在相册中选择视频
//- (BOOL) canUserPickVideosFromPhotoLibrary{
//    return [self cameraSupportsMedia:(NSString *)kUTTypeMovie sourceType:UIImagePickerControllerSourceTypePhotoLibrary];
//}

// 是否可以在相册中选择视频
//- (BOOL) canUserPickPhotosFromPhotoLibrary{
//    return [self cameraSupportsMedia:kCIAttributeTypeImage sourceType:UIImagePickerControllerSourceTypePhotoLibrary];
//
//    return [self cameraSupportsMedia:( NSString *)kUTTypeImage sourceType:UIImagePickerControllerSourceTypePhotoLibrary];
//}





@end
