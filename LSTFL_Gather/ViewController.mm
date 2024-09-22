//
//  ViewController.m
//  LSTFL_Gather
//
//  Created by Jeremy Feldman on 15/2/19.
//  Copyright © 2019 Jeremy Feldman. All rights reserved.
//

#import <opencv2/opencv.hpp>

#import "ViewController.hpp"

#import "OpenCVWrapper.hpp"
#import <opencv2/videoio/cap_ios.h>
#include "opencv2/imgproc/imgproc.hpp"
#include "opencv2/highgui/highgui.hpp"

#import "AWSCognitoIdentityProvider/AWSCognitoIdentityProvider.h"
#import "LSTFL_Gather-Swift.h"

@interface ViewController () <CapturesViewControllerDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIImage *lastImage;
@property (nonatomic, retain) CvVideoCamera* videoCamera;
@property (weak, nonatomic) IBOutlet UILabel *fpsLabel;
@property (weak, nonatomic) IBOutlet UIButton *captureButton;
@property (weak, nonatomic) IBOutlet UIButton *viewImagesButton;
@property (nonatomic, readonly) UIViewController *presentedViewController;
@property (nonatomic,strong) AWSCognitoIdentityUserGetDetailsResponse * response;
@property (nonatomic, strong) AWSCognitoIdentityUser * user;
@property (nonatomic, strong) AWSCognitoIdentityUserPool * pool;
@property (assign) BOOL result;
@property NSString *textLabel;
@property (weak, nonatomic) IBOutlet UIButton *modelSelectPopupButton;
@end

@implementation ViewController
CvVideoCamera* videoCamera;

//BOOL result;

double start = 0;
BOOL foundObjects = false;
NSString *annots;
double end = 0;
NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
NSString *directory = [paths objectAtIndex:0];

BOOL isFltr1On = false;
BOOL isFltr2On = false;
BOOL isCaptureOn = false;
float frameRate = 0.0;

NSFileManager *annotFileManager = [NSFileManager defaultManager];
NSString *annotPathForFile = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"captures_annotations.csv"]];

NSFileManager *dataFileManager = [NSFileManager defaultManager];
NSString *dataPathForFile = [[NSBundle mainBundle] pathForResource:@"coco10_labels" ofType:@"txt"];
NSArray *classListArray = [[NSArray alloc] init];
NSMutableDictionary *tfliteFiles = [[NSMutableDictionary alloc] init];

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view.
    self.textLabel = @"";
    self.pool = [AWSCognitoIdentityUserPool CognitoIdentityUserPoolForKey:@"UserPool"];
    //on initial load set the user and refresh to get attributes
    if(!self.user)
        self.user = [self.pool currentUser];
    [self refresh];
    
    _captureButton.layer.cornerRadius = 5;
    _captureButton.layer.backgroundColor = [UIColor clearColor].CGColor;
    _captureButton.layer.borderColor = [UIColor colorWithRed:84/255.0 green:161/255.0 blue:255/255.0 alpha:1.0].CGColor;
    _captureButton.layer.borderWidth = 2;
    _captureButton.clipsToBounds = true;
    
    _viewImagesButton.layer.cornerRadius = 5;
    _viewImagesButton.layer.backgroundColor = [UIColor clearColor].CGColor;
    _viewImagesButton.layer.borderColor = [UIColor colorWithRed:84/255.0 green:161/255.0 blue:255/255.0 alpha:1.0].CGColor;
    _viewImagesButton.layer.borderWidth = 2;
    _viewImagesButton.clipsToBounds = true;
    
//    self.captureButton.layer.backgroundColor = [UIColor greenColor].CGColor;
    
//    self.result = [OpenCVWrapper performObjectDetectionInitialiseWrapper];
    
    NSString *appPath = [[NSBundle mainBundle] bundlePath];    
    NSArray *dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appPath error:NULL];
    NSArray *sortedDirs = [dirs sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSMutableArray *tfliteFileNames = [[NSMutableArray alloc] init];
    __block NSInteger includFileCount = 0;
    [sortedDirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *filename = (NSString *)obj;
        NSString *extension = [[filename pathExtension] lowercaseString];
        if ([extension isEqualToString:@"tflite"]) {
            NSLog(@"found filename: %@", filename);
            NSString *filePath = [appPath stringByAppendingPathComponent:filename];
            NSString *labelsPath = [appPath stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@_labels", [filename stringByDeletingPathExtension]] stringByAppendingPathExtension:@"txt"]];
            // only include in file list if the labels file is found also
            if ([[NSFileManager defaultManager] fileExistsAtPath:labelsPath]) {
                includFileCount = includFileCount + 1;
                [tfliteFileNames addObject:[filename stringByDeletingPathExtension]];
                BOOL hasQ = [[filename stringByDeletingPathExtension] hasSuffix:@"_q"];
                NSDictionary *fileInfo = @{
                    @"path" : filePath,
                    @"isQuantized" : @(hasQ),  // Use the determined value for isQuantized
                    @"idx" : @(includFileCount)
                };
                [tfliteFiles setObject:fileInfo forKey:filename];
            }
        }
    }];
//    NSLog(@"tfliteFiles: %@", tfliteFiles);
    
    NSString *defaultOption = tfliteFileNames[0];
    
    // Set up the camera and object detector with default values
    NSString *defaultModelName = [defaultOption stringByDeletingPathExtension];
    NSString *defaultLabelsName = [NSString stringWithFormat:@"%@_labels", defaultModelName];
    BOOL isQuantized = [[defaultModelName stringByDeletingPathExtension] hasSuffix:@"_q"]; // Assuming the default model is not quantized
    
    self.result = [self initializeObjectDetectorWithModel:defaultModelName labels:defaultLabelsName quantized:isQuantized];
    
    //@[@"Model 1", @"Model 2", @"Model 3"];
    [self updateModelSelectPopupMenuWithOptions:tfliteFileNames];
    NSString *shortenedTitle = @"M1";
    [self.modelSelectPopupButton setTitle:shortenedTitle forState:UIControlStateNormal];

    dataPathForFile = [[NSBundle mainBundle] pathForResource:defaultLabelsName ofType:@"txt"];
    if (![dataFileManager fileExistsAtPath:dataPathForFile]){
        NSLog(@"Model class list file does not exist...");
    } else {
        NSLog(@"Found the model class list file...");
        NSString *getClassListfileContents = [NSString stringWithContentsOfFile:dataPathForFile encoding:NSUTF8StringEncoding error:nil];
        classListArray = [getClassListfileContents componentsSeparatedByString:@"\n"];
        NSLog(@"Class list count: %lu",(unsigned long)classListArray.count);
    }
    
    // remove (reset) the saved file(s)
//    [annotFileManager removeItemAtPath:annotPathForFile error:nil];
//    NSString *folderPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
//    for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folderPath error:nil]) {
//        [[NSFileManager defaultManager] removeItemAtPath:[folderPath stringByAppendingPathComponent:file] error:nil];
//    }
    
    if (![annotFileManager fileExistsAtPath:annotPathForFile]){
        NSLog(@"File does not exist...");
        [annotFileManager createFileAtPath:annotPathForFile contents:nil attributes:nil];
        [self writeToAnnotFile:@"filename,width,height,class,xmin,ymin,xmax,ymax"];
    } else {
        NSLog(@"Found the annotations file...");
    }
    
}

- (void)viewWillAppear:(BOOL)animated {
    TimeOfActiveUser = [NSTimer scheduledTimerWithTimeInterval:0.1  target:self selector:@selector(actionTimer) userInfo:nil repeats:true];
    
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:_imageView];
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset1280x720;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 30;
    self.videoCamera.grayscaleMode = false;
    self.videoCamera.delegate = self;
    
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
}

- (void)actionTimer {
    [self.fpsLabel setText:[NSString stringWithFormat:@"FPS: %.2f", frameRate]];
}

- (void)startCamera {
    [self.videoCamera start];
}

- (void)stopCamera {
    [self.videoCamera stop]; // Stop the camera
}

- (BOOL)initializeObjectDetectorWithModel:(NSString *)modelFileName
                                   labels:(NSString *)labelsFileName
                                quantized:(BOOL)isQuantized {
    // Stop the current object detector if it is running
    if (self.videoCamera.running) {
        [self stopCamera];
    }

    // Get the paths for the model and labels
    NSString *modelPath = [OpenCVWrapper FilePathForResourceName:modelFileName andExtension:@"tflite"];
    NSString *labelsPath = [OpenCVWrapper customStringFromFile:labelsFileName andExtension:@"txt"];
    
    // Initialize object detector with the model, labels, and quantization flag
    BOOL result = [OpenCVWrapper performObjectDetectionInitialiseWrapperWithModel:modelPath labels:labelsPath quantized:isQuantized];
    if (!result) {
        NSLog(@"Failed to initialize object detector with model: %@", modelFileName);
    } else {
        NSLog(@"Object detector initialized successfully with model: %@", modelFileName);
    }
    
    // Start the video camera
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self startCamera];
    });
    
    return result;
}

- (void)setModelSelectPopupMenu:(UIMenu *)menu {
    [self.modelSelectPopupButton setMenu:menu]; // Set the menu for the UIButton
    [self.modelSelectPopupButton setShowsMenuAsPrimaryAction:true]; // Make the button show the menu on tap
}

- (void)updateModelSelectPopupMenuWithOptions:(NSArray<NSString *> *)options {
    // Create an array of UIActions for the menu items
    NSMutableArray<UIAction *> *actions = [NSMutableArray array];
    
    for (NSString *option in options) {
        // Create a UIAction for each option
        UIAction *action = [UIAction actionWithTitle:option
                                               image:nil
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
            // Handle menu item selection
            NSLog(@"Selected model: %@", action.title);
            [self handleModelSelection:action.title]; // Call your custom method on selection
            
            // Set a shortened version of the selected option (e.g., first 10 characters)
            NSString *filenameWithExtension = [action.title stringByAppendingPathExtension:@"tflite"];
            NSString *indexString = [tfliteFiles[filenameWithExtension][@"idx"] stringValue];
            NSString *shortenedTitle = [NSString stringWithFormat:@"M%@", indexString];
            [self.modelSelectPopupButton setTitle:shortenedTitle forState:UIControlStateNormal];
        }];
        [actions addObject:action];
    }
    
    // Create the UIMenu with the actions
    UIMenu *menu = [UIMenu menuWithTitle:@"Select Model" children:actions];
    
    // Set the menu using the setter method
    [self setModelSelectPopupMenu:menu];
}

- (NSString *)shortenText:(NSString *)text toMaxLength:(NSInteger)maxLength {
    NSArray *components = [text componentsSeparatedByString:@": "];
    NSString *firstPart = components.count > 0 ? components[0] : text;
    if (firstPart.length > maxLength) {
        return [[firstPart substringToIndex:maxLength] stringByAppendingString:@""];
    }
    return firstPart;
}

- (void)handleModelSelection:(NSString *)selectedModel {
    NSLog(@"You selected: %@", selectedModel);
    // Perform additional logic based on the selected model
    NSString *modelName = [selectedModel stringByDeletingPathExtension];
    NSString *labelsName = [NSString stringWithFormat:@"%@_labels", modelName];
    BOOL isQuantized = [[modelName stringByDeletingPathExtension] hasSuffix:@"_q"];
    self.result = [self initializeObjectDetectorWithModel:modelName labels:labelsName quantized:isQuantized];
    
    // update the clasListArray on model change
    dataPathForFile = [[NSBundle mainBundle] pathForResource:labelsName ofType:@"txt"];
    if (![dataFileManager fileExistsAtPath:dataPathForFile]){
        NSLog(@"Model class list file does not exist...");
    } else {
        NSLog(@"Found the model class list file...");
        NSString *getClassListfileContents = [NSString stringWithContentsOfFile:dataPathForFile encoding:NSUTF8StringEncoding error:nil];
        classListArray = [getClassListfileContents componentsSeparatedByString:@"\n"];
        NSLog(@"Class list count: %lu",(unsigned long)classListArray.count);
    }
}

- (void)modalDidClose {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self startCamera];
    });
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showCapturesModal"]) {
        CapturesViewController *capturesVC = (CapturesViewController *)segue.destinationViewController;
        capturesVC.delegate = self;
    }
}

- (IBAction)captureButtonAction:(id)sender {
    NSLog(@"captureButtonAction");
    
    if (isCaptureOn) {
        isCaptureOn = false;
        [self.captureButton setBackgroundColor:[UIColor clearColor]];
        return;
    }
    
    UIAlertController *alert = [
        UIAlertController alertControllerWithTitle:@"Object Label"
        message:@"Please enter a value"
        preferredStyle:UIAlertControllerStyleAlert
    ];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Enter object label here";
    }];
    
    UIAlertAction *acceptAction = [
        UIAlertAction actionWithTitle:@"Accept"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * _Nonnull action) {
            UITextField *textField = alert.textFields.firstObject;
            self.textLabel = textField.text;
            NSLog(@"textLabel: %@", self.textLabel);
            
            isCaptureOn = true;
            [self.captureButton setBackgroundColor:[UIColor colorWithRed:76/255.0 green:217/255.0 blue:100/255.0 alpha:8.0]];
            
        }
    ];
    
    UIAlertAction *cancelAction = [
        UIAlertAction actionWithTitle:@"Cancel"
        style:UIAlertActionStyleCancel
        handler:nil
    ];
    
    [alert addAction:acceptAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:true completion:nil];
    
}

- (IBAction)logoutCloseButtonAction:(id)sender {
    NSLog(@"logout button pressed");
    if(self.result) {
        [self.videoCamera stop];
    }
    [self.user signOut];
    self.title = nil;
    self.response = nil;
    [self refresh];
}

- (IBAction)viewImagesButtonAction:(id)sender {
    [self stopCamera];
}

-(void) refresh {
    [[self.user getDetails] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityUserGetDetailsResponse *> * _Nonnull task) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(task.error){
                self.title = task.error.userInfo[@"__type"];
                if(self.title == nil){
                    self.title = task.error.userInfo[NSLocalizedDescriptionKey];
                }
                NSLog(@"%@", self.title);
            }else {
                self.response = task.result;
                self.title = self.user.username;
                if(self.result) {
                    [self.videoCamera start];
                }
            }
        });
        
        return nil;
    }];
}

-(void) writeToAnnotFile:(NSString*)content{
    content = [NSString stringWithFormat:@"%@\n",content];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:annotPathForFile];
    if (fileHandle){
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    }
    else{
        [content writeToFile:annotPathForFile
                  atomically:false
                    encoding:NSStringEncodingConversionAllowLossy
                       error:nil];
    }
}

#pragma mark - Protocol CvVideoCameraDelegate
#ifdef __cplusplus
- (void)processImage:(cv::Mat &)image {
    start = [[NSDate new] timeIntervalSince1970];
    cv::Mat blur;
    cv::Mat image_copy;
    cv::Mat image_save_copy;
    
    cvtColor(image, image_save_copy, CV_BGR2BGRA);
//    cvtColor(image_save_copy, image_save_copy, CV_BGRA2BGR);
    
    if(isFltr1On) {
        cv::GaussianBlur(image, blur, cv::Size(15,15), 5);
        cvtColor(blur, image, CV_BGR2BGRA);
    }
    
    if(isFltr2On) {
        // invert image
        bitwise_not(image, image_copy);
        cvtColor(image_copy, image_copy, CV_BGR2GRAY);
        //Convert BGR to BGRA (three channel to four channel)
        cv::Mat bgr;
        cvtColor(image_copy, bgr, CV_GRAY2BGR);
        cvtColor(bgr, image, CV_BGR2BGRA);
    }

//    if(!self.subImageView.hidden) {
//        UIImage* uiImage = MatToUIImage(image);
//        dispatch_async(dispatch_get_main_queue(), ^{
//            self.subImageView.image = uiImage;
//        });
//    }
    
    UIImage* uiImage = MatToUIImage(image);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = uiImage;
    });
    
    if (!image.empty() && image.cols > 0 && image.rows > 0) {
        annots = [OpenCVWrapper performObjectDetection2:image];
        NSArray *annotsArray = [annots componentsSeparatedByString: @","];
        
//        if(![annotsArray[0]  isEqual: @""]) {
//            NSLog(@"annots: %@", annotsArray[0]);
//        }
        
        if(annotsArray.count > 0 && ![annotsArray[0] isEqual: @""]) {
            NSLog(@"foundObjects...");
            if (isCaptureOn) {
                NSString *imageName = [NSString stringWithFormat:@"capture_%.0f.jpg", CFAbsoluteTimeGetCurrent() * 100000000000];
                NSString *filePath = [directory stringByAppendingPathComponent:imageName];
                const char* filePathC = [filePath cStringUsingEncoding:NSMacOSRomanStringEncoding];
                const cv::String thisPath = (const cv::String)filePathC;
                
                // save annotations //8_245_157_233_305_68, (class_id, minx, miny, width, height, prob)
                for (int i=0; i<annotsArray.count; i++) {
                    NSString *annot = [NSString stringWithFormat:@"%@", annotsArray[i]];
                    NSArray *annotVals = [annot componentsSeparatedByString: @"_"];
                    NSString *className = classListArray[[annotVals[0] intValue]];
                    NSString *newClassName = [NSString stringWithFormat:@"%@:%@", className, self.textLabel];
                    [self writeToAnnotFile:[NSString stringWithFormat:@"%@,%i,%i,%@,%@,%@,%i,%i", imageName, image_save_copy.size().width, image_save_copy.size().height, newClassName, annotVals[1], annotVals[2], [annotVals[1] intValue] + [annotVals[3] intValue], [annotVals[2] intValue] + [annotVals[4] intValue] ]];
                }
                
                //Save image
                imwrite(thisPath, image_save_copy);
                
            }
        }
    }
    
    end = [[NSDate new] timeIntervalSince1970];
//    NSLog(@"Time: %.4lf", 1/(end - start) );
    
    frameRate = 1/(end - start);
}

//- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
//    <#code#>
//}
//
//- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection {
//    <#code#>
//}
//
//- (void)preferredContentSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container {
//    <#code#>
//}
//
//- (CGSize)sizeForChildContentContainer:(nonnull id<UIContentContainer>)container withParentContainerSize:(CGSize)parentSize {
//    <#code#>
//}
//
//- (void)systemLayoutFittingSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container {
//    <#code#>
//}
//
//- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator {
//    <#code#>
//}
//
//- (void)willTransitionToTraitCollection:(nonnull UITraitCollection *)newCollection withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator {
//    <#code#>
//}
//
//- (void)didUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context withAnimationCoordinator:(nonnull UIFocusAnimationCoordinator *)coordinator {
//    <#code#>
//}
//
//- (void)setNeedsFocusUpdate {
//    <#code#>
//}
//
//- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context {
//    <#code#>
//}
//
//- (void)updateFocusIfNeeded {
//    <#code#>
//}
#endif

@end
