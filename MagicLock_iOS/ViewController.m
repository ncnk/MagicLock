//
//  ViewController.m
//  MagicLock_iOS
//
//  Created by 程启航 on 2017/5/8.
//  Copyright © 2017年 NcnkCheng. All rights reserved.
//

#import "ViewController.h"
#import "NCCentralManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    [[NCCentralManager sharedInstance] start];
}

@end
