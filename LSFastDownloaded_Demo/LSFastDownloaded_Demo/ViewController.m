//
//  ViewController.m
//  LSFastDownloaded_Demo
//
//  Created by santhosh lakkanpalli on 06/01/15.
//  Copyright (c) 2015 com.santhosh. All rights reserved.
//

#import "ViewController.h"
#import "LSFastDownloadTask.h"

@interface ViewController ()
@property (nonatomic,strong) NSMutableArray *downloads;
@property (nonatomic,strong) UIImageView *imageView1;
@property (nonatomic,strong) UIImageView *imageView2;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.downloads = [NSMutableArray array];
    
    self.imageView1 = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0,[UIScreen mainScreen].bounds.size.width,200)];
    [self.view addSubview:self.imageView1];
    self.imageView1.backgroundColor = [UIColor blueColor];
    
    self.imageView2 = [[UIImageView alloc] initWithFrame:CGRectMake(0, 220,[UIScreen mainScreen].bounds.size.width,200)];
    [self.view addSubview:self.imageView2];
    self.imageView2.backgroundColor = [UIColor brownColor];
    
    
    NSURL *url1 = [NSURL URLWithString:@"http://intentblog.com/wp-content/uploads/2014/03/passion-to-purpose-to-profession.png"]; //170KB file
    LSFastDownloadTask *downloadTask1 = [[LSFastDownloadTask alloc] initWithURL:url1 completion:^(NSError *error, NSURL *fileLocation) {
        if (fileLocation) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *image = [UIImage imageWithContentsOfFile:[fileLocation path]];
                self.imageView1.image = image;
            });
        }
    }];
    [self.downloads addObject:downloadTask1];
    
    NSURL *url2 = [NSURL URLWithString:@"http://png-4.findicons.com/files/icons/2015/24x24_free_application/24/text.png"]; //10KB file
    LSFastDownloadTask *downloadTask2 = [[LSFastDownloadTask alloc] initWithURL:url2 completion:^(NSError *error, NSURL *fileLocation) {
        if (fileLocation) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *image = [UIImage imageWithContentsOfFile:[fileLocation path]];
                self.imageView2.image = image;
            });
        }
    }];
    [self.downloads addObject:downloadTask2];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
