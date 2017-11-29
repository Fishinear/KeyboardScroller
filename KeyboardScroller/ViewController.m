//
//  ViewController.m
//  KeyboardScroller
//
//  Created by René Dekker on 2017-11-29.
//  Copyright © 2017 René Dekker. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewWillAppear:(BOOL)animated
{
    // just set a default size for this demo. In reality it should be set properly
    self.scrollView.contentSize = self.contentView.frame.size;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
