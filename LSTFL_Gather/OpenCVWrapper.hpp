//
//  OpenCVWrapper.hpp
//  LSTFL_Gather
//
//  Created by Jeremy Feldman on 15/2/19.
//  Copyright © 2019 Jeremy Feldman. All rights reserved.
//

#ifdef __cplusplus
#undef NO
#undef YES
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#endif

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>



NS_ASSUME_NONNULL_BEGIN


@interface OpenCVWrapper : NSObject

+ (NSString*)customStringFromFile:(NSString *)fileNameBase andExtension:(NSString *)fileNameExtension;
+ (NSString*)FilePathForResourceName:(NSString *)name andExtension:(NSString *)extension;
+ (BOOL)performObjectDetectionInitialiseWrapper;
+ (BOOL)performObjectDetectionInitialiseWrapperWithModel:(NSString *)modelPath labels:(NSString *)labelsPath quantized:(BOOL)isQuantized;
+ (BOOL)performObjectDetection:(UIImage **)uiImage;
+ (NSString*)performObjectDetection2:(cv::Mat &)uiImage;

@end

NS_ASSUME_NONNULL_END
