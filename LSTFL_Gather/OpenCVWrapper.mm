//
//  OpenCVWrapper.mm
//  LSTFL_Gather
//
//  Created by Jeremy Feldman on 15/2/19.
//  Copyright © 2019 Jeremy Feldman. All rights reserved.
//


#import "OpenCVWrapper.hpp"

#ifdef __cplusplus
#undef NO
#undef YES
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#endif

#include "object_detect_lite-ios.hpp"

#define SSD_NEURAL_NETWORK_TENSORFLOW_LITE_MODEL_IS_QUANTIZED false
#define SSD_NEURAL_NETWORK_TENSORFLOW_LITE_MODEL_FILE_NAME "coco10.tflite"
#define SSD_NEURAL_NETWORK_TENSORFLOW_LITE_MODEL_FILE_NAME_BASE "coco10"
#define SSD_NEURAL_NETWORK_TENSORFLOW_LITE_MODEL_FILE_NAME_EXTENSION "tflite"
#define SSD_NEURAL_NETWORK_TENSORFLOW_LITE_LABELS_FILE_NAME "coco10_labels.txt"
#define SSD_NEURAL_NETWORK_TENSORFLOW_LITE_LABELS_FILE_NAME_BASE "coco10_labels"
#define SSD_NEURAL_NETWORK_TENSORFLOW_LITE_LABELS_FILE_NAME_EXTENSION "txt"
#define SSD_NEURAL_NETWORK_TENSORFLOW_LITE_MIN_DETECTION_PROBABILITY (0.6)


ObjDetector* objDetector;



@implementation OpenCVWrapper


+ (NSString*)customStringFromFile:(NSString *)fileNameBase andExtension:(NSString *)fileNameExtension
{
	NSString *path = [OpenCVWrapper FilePathForResourceName:fileNameBase andExtension:fileNameExtension];
	//NSString *path = [[NSBundle mainBundle] pathForResource:fileNameBase ofType:fileNameExtension];	//FilePathForResourceName
	NSString* fileContentNS = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];

	NSLog(@"\n fileContentNS = %@", fileContentNS);
	return fileContentNS;
}

+ (NSString*)FilePathForResourceName:(NSString *)name andExtension:(NSString *)extension;
{
	NSString* file_path = [[NSBundle mainBundle] pathForResource:name ofType:extension];
	if (file_path == NULL) {
		NSLog(@"Couldn't find '%@.%@' in bundle.", name, extension);
		exit(-1);
	}
	return file_path;
}

+ (BOOL)performObjectDetectionInitialiseWrapper
{
	bool result = true;
	
	objDetector = new ObjDetector();
	std::string modelFileName = SSD_NEURAL_NETWORK_TENSORFLOW_LITE_MODEL_FILE_NAME;
	std::string labelsFileName = SSD_NEURAL_NETWORK_TENSORFLOW_LITE_LABELS_FILE_NAME;
	bool modelIsQuantized = SSD_NEURAL_NETWORK_TENSORFLOW_LITE_MODEL_IS_QUANTIZED;
	std::vector<std::string> labels;
	int numberOfLinesInLabelsFile;

	NSString* graph = @SSD_NEURAL_NETWORK_TENSORFLOW_LITE_MODEL_FILE_NAME_BASE;
	const NSString* graph_path = [OpenCVWrapper FilePathForResourceName:graph andExtension:@SSD_NEURAL_NETWORK_TENSORFLOW_LITE_MODEL_FILE_NAME_EXTENSION];
	
	NSString* labelsContentNS = [OpenCVWrapper customStringFromFile:@SSD_NEURAL_NETWORK_TENSORFLOW_LITE_LABELS_FILE_NAME_BASE andExtension:@SSD_NEURAL_NETWORK_TENSORFLOW_LITE_LABELS_FILE_NAME_EXTENSION];
	std::string labelsContent = std::string([labelsContentNS UTF8String]);
	objDetector->getLinesFromFile(&labelsContent, &labels, &numberOfLinesInLabelsFile);
	
	if(!(objDetector->init([graph_path UTF8String], modelIsQuantized, labels)))
	{
		printf("\nfailed to load model");
		result = false;
	}
	
	return result;
}

+ (BOOL)performObjectDetectionInitialiseWrapperWithModel:(NSString *)modelPath labels:(NSString *)labelsPath quantized:(BOOL)isQuantized {
    bool result = true;

    objDetector = new ObjDetector();
    
    // Convert NSString to std::string
    std::string modelPathStd = std::string([modelPath UTF8String]);
    std::string labelsPathStd = std::string([labelsPath UTF8String]);

    // Read labels
    std::string labelsContent = std::string([labelsPath UTF8String]);
    std::vector<std::string> labels;
    int numberOfLinesInLabelsFile;
    
    objDetector->getLinesFromFile(&labelsContent, &labels, &numberOfLinesInLabelsFile);
    
    // Initialize the object detector with the model, quantized flag, and labels
    if (!(objDetector->init(modelPathStd.c_str(), isQuantized, labels))) {
        printf("\nFailed to load model");
        result = false;
    }
    
    return result;
}


+ (NSString*)performObjectDetection2:(cv::Mat &)uiImage
{
    BOOL foundObject = false;
    NSMutableString *annots = [NSMutableString stringWithFormat:@""];
    
    std::vector<Object> objects;
    objDetector->runImage(uiImage, uiImage, objects);
    
    if(objects.size() > 0)
    {
        foundObject = true;
        for (int i=0; i<objects.size(); i++) {
            Object object = objects[i];
            int class_id = object.class_id;
            int minx = object.rec.x;
            int miny = object.rec.y;
            int width = object.rec.width;
            int height = object.rec.height;
            float prob = object.prob*100;
            NSString *annot = [NSString stringWithFormat:@"%i_%i_%i_%i_%i_%.0f", class_id, minx, miny, width, height, prob];
            if (i==0) {
                [annots appendFormat:@"%@",annot];
            } else {
                [annots appendFormat:@",%@",annot];
            }
        }
    }
    
    return annots;
}

+ (BOOL)performObjectDetection:(UIImage **)uiImage
{
	BOOL foundObject = false;
	
	cv::Mat imageMatIn;
	cv::Mat imageMatOut;
	UIImageToMat(*uiImage, imageMatIn);
	cvtColor(imageMatIn, imageMatIn, CV_BGRA2BGR);
	
	std::vector<Object> objects;
	objDetector->runImage(imageMatIn, imageMatOut, objects);
	
	*uiImage = MatToUIImage(imageMatOut);
	
	if(objects.size() > 0)
	{
		foundObject = true;
	}
	
	return foundObject;
}





@end
