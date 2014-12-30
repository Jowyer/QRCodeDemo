//
//  ViewController.m
//  TestQRCode
//
//  Created by Jowyer on 14/12/29.
//  Copyright (c) 2014年 Gosstech. All rights reserved.
//

#import "ViewController.h"
@import AVFoundation;

@interface ViewController () <AVCaptureMetadataOutputObjectsDelegate>
@property (weak, nonatomic) IBOutlet UIView *previewView;
@property (weak, nonatomic) IBOutlet UIImageView *scanView;
@property (weak, nonatomic) IBOutlet UIImageView *scanLine;
@end

@implementation ViewController {
    AVCaptureSession *session;
    AVCaptureVideoPreviewLayer *previewLayer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    session = [[AVCaptureSession alloc] init];
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                        error:&error];
    if (input && [session canAddInput:input]) {
        [session addInput:input];
    } else {
        NSLog(@"Error: %@", error);
    }
    
    /* AV Foundation is designed for high throughput and low latency;
     therefore any processing and analysis tasks should be
     moved off of the main thread if at all possible.
     */
    dispatch_queue_t metadataQueue = dispatch_queue_create("com.jw.metadata", 0);
    
    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
    [output setMetadataObjectsDelegate:self queue:metadataQueue];
    if ([session canAddOutput:output]) {
        [session addOutput:output];
    }
    output.metadataObjectTypes = output.availableMetadataObjectTypes;
    
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    previewLayer.frame = self.view.bounds;
    [self.previewView.layer addSublayer:previewLayer];
    
    [session startRunning];
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self performMaskLayer];
    
    [self addAnimation];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Private Methods
- (void)performMaskLayer {
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:self.scanView.frame];
    [path appendPath:[UIBezierPath bezierPathWithRect:self.view.frame]];
    
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.view.frame;
    maskLayer.fillColor = [UIColor colorWithWhite:0 alpha:.7].CGColor;
    
    maskLayer.path = path.CGPath;
    maskLayer.fillRule = kCAFillRuleEvenOdd;
    
    [self.view.layer addSublayer:maskLayer];
}

- (void)addAnimation {
    CABasicAnimation *yAnimation = [CABasicAnimation animationWithKeyPath:@"position.y"];
    yAnimation.duration = 2;
    yAnimation.repeatCount = CGFLOAT_MAX;
    yAnimation.fromValue = [NSNumber numberWithFloat:self.scanLine.layer.position.y];
    yAnimation.toValue = [NSNumber numberWithFloat:self.scanLine.layer.position.y + self.scanView.frame.size.height - self.scanLine.frame.size.height/2];
    [self.scanLine.layer addAnimation:yAnimation forKey:nil];
}

#pragma mark - AVCaptureMetadataOupputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    for (AVMetadataObject *metadata in metadataObjects) {
        if ([metadata isKindOfClass: [AVMetadataMachineReadableCodeObject class]]) {
            // Transform coordinates
            AVMetadataMachineReadableCodeObject *code = (AVMetadataMachineReadableCodeObject *)[previewLayer transformedMetadataObjectForMetadataObject:metadata];
            
            // Check if top-left and bottom-right points are in the scan frame
            CGPoint point0, point3;
            CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)code.corners[0], &point0);
            CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)code.corners[3], &point3);
            
            if (CGRectContainsPoint(self.scanView.frame, point0) &&
                CGRectContainsPoint(self.scanView.frame, point3)) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [session stopRunning];
                    
                    // Show alert
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Catch U" message:code.stringValue preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                        [session startRunning];
                    }];
                    [alertController addAction:okAction];
                    [self presentViewController:alertController animated:YES completion:nil];
                });
                
            }
            break;
        }
    }
}

@end
