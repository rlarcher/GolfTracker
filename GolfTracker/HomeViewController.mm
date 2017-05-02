//
//  HomeViewController.m
//  GolfTracker
//
//  Created by Ryan Archer on 5/1/17.
//  Copyright © 2017 CMU_16623. All rights reserved.
//

#import "HomeViewController.h"
#import "CameraViewController.h"

@interface HomeViewController ()

@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"ShowCamera"]) {
        CameraViewController *destinationController = (CameraViewController*)[segue destinationViewController];
        destinationController.finding_speed = self.finding_speed;
    }
}

- (IBAction)calculate_speed:(id)sender {
    self.finding_speed = true;
    [self performSegueWithIdentifier:@"ShowCamera" sender:self];
}

- (IBAction)trace_ball:(id)sender {
    self.finding_speed = false;
    [self performSegueWithIdentifier:@"ShowCamera" sender:self];
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
