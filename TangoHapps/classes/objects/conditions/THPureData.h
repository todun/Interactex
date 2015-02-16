//
//  THPureData.h
//  TangoHapps
//
//  Created by Juan Haladjian on 4/23/13.
//  Copyright (c) 2013 Technische Universität München. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PdAudioController.h"
#import "PdBase.h"
#import "PdDispatcher.h"
#import "THProgrammingElement.h"

@interface THPureData : THProgrammingElement
{
}

@property (nonatomic) BOOL on;
@property (nonatomic) NSInteger variable1;
@property (nonatomic) NSInteger variable2;

-(void) turnOn;
-(void) turnOff;

@property (strong, nonatomic) PdAudioController *audioController;
@property (strong, nonatomic) PdDispatcher *dispatcher;

@end
