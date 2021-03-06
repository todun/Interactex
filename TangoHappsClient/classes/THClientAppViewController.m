/*
THClientAppViewController.m
Interactex Client

Created by Juan Haladjian on 10/07/2013.

Interactex Designer is a configuration tool to easily setup, simulate and connect e-Textile hardware with smartphone functionality. Interactex Client is an app to store and replay projects made with Interactex Designer.

www.interactex.org

Copyright (C) 2013 TU Munich, Munich, Germany; DRLab, University of the Arts Berlin, Berlin, Germany; Telekom Innovation Laboratories, Berlin, Germany
	
Contacts:
juan.haladjian@cs.tum.edu
katharina.bredies@udk-berlin.de
opensource@telekom.de

    
The first version of the software was designed and implemented as part of "Wearable M2M", a joint project of UdK Berlin and TU Munich, which was founded by Telekom Innovation Laboratories Berlin. It has been extended with funding from EIT ICT, as part of the activity "Connected Textiles".

Interactex is built using the Tango framework developed by TU Munich.

In the Interactex software, we use the GHUnit (a test framework for iOS developed by Gabriel Handford) and cocos2D libraries (a framework for building 2D games and graphical applications developed by Zynga Inc.). 
www.cocos2d-iphone.org
github.com/gabriel/gh-unit

Interactex also implements the Firmata protocol. Its software serial library is based on the original Arduino Firmata library.
www.firmata.org

All hardware part graphics in Interactex Designer are reproduced with kind permission from Fritzing. Fritzing is an open-source hardware initiative to support designers, artists, researchers and hobbyists to work creatively with interactive electronics.
www.frizting.org

Martijn ten Bhömer from TU Eindhoven contributed PureData support. Contact: m.t.bhomer@tue.nl.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 
You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

#import "THClientAppViewController.h"
#import "THSimulableWorldController.h"
#import "THClientProject.h"

#import "THView.h"
#import "THiPhone.h"
#import "THClientProjectProxy.h"

#import "THLilyPad.h"
#import "THBoardPin.h"
#import "THPinValue.h"
#import "THElementPin.h"
#import "THCompassLSM303.h"
#import "THI2CComponent.h"
#import "THI2CRegister.h"

#import "THLabel.h"
#import "THBLECommunicationModule.h"
#import "IFFirmata.h"
#import "THI2CMessage.h"

//remove
#import "THSwitch.h"
#import "THMusicPlayer.h"
#import "THButton.h"
#import "THDeviceViewController.h"


@implementation THClientAppViewController

-(NSString*) title{
    THClientProject * project = [THSimulableWorldController sharedInstance].currentProject;
    return project.name;
}

-(void) loadUIObjects{
        
    THiPhone * iPhone = self.currentProject.iPhone;
    
    [iPhone.currentView loadView];
    
    CGSize size = iPhone.currentView.view.frame.size;
    
    self.view = iPhone.currentView.view;
    self.view.backgroundColor = [UIColor whiteColor];
    self.view.alpha = 1.0f;
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    
    THIPhoneType type = screenHeight < 500;
    CGFloat viewHeight = self.view.bounds.size.height;
    
    for (THView * object in self.currentProject.iPhoneObjects) {
        
        float relx = (object.position.x - iPhone.position.x + size.width/2.0f) / kiPhoneFrames[type].size.width;
        float rely = (object.position.y - iPhone.position.y + size.height/2.0f) / kiPhoneFrames[type].size.height;
        
        CGPoint translatedPos = CGPointMake(relx * screenWidth ,rely * viewHeight);
        
        //if(object.view == nil){
            [object loadView];
            [object addToView:self.view];
        //}
        
        if(!self.showingPreset){
            
            object.position = translatedPos;
        }
    }
}

-(void) stopActivityIndicator {
    
    self.view.userInteractionEnabled = YES;
    //self.view.alpha = 1.0f;
    if(_activityIndicator != nil){
        [_activityIndicator removeFromSuperview];
        _activityIndicator = nil;
    }
}

-(void) startActivityIndicator {
    
    self.view.userInteractionEnabled = NO;
    
    //self.view.alpha = 0.5f;
    
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    
    _activityIndicator.center = self.view.center;
    [_activityIndicator startAnimating];
    
    [self.view addSubview:_activityIndicator];
}

-(void) viewDidLoad{
    
    [super viewDidLoad];
    
    self.firmataController = [[IFFirmata alloc] init];
    self.firmataController.delegate = self;
    
}

-(void) viewWillAppear:(BOOL)animated{
    
    if(!self.currentProject){
        
        self.currentProject = [THSimulableWorldController sharedInstance].currentProject;
        
        if([BLEDiscovery sharedInstance].currentPeripheral.state == CBPeripheralStateConnected){
            [self updateStartButtonToStop];
        } else {
            [self updateStartButtonToScan];
        }
        
        [self setTitle:self.currentProject.name];
        
        [self loadUIObjects];
        
        //[self updateStartButton];
    }
    
    [self addPinObservers];
}

-(void) viewWillDisappear:(BOOL)animated{
    
    [self removePinObservers];
}

-(void) disconnect{

    [[BLEDiscovery sharedInstance] disconnectCurrentPeripheral];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

#pragma mark Pins Observing

-(void) addPinObservers{
    
    THClientProject * project = [THSimulableWorldController sharedInstance].currentProject;
    
    for (THBoardPin * pin in project.currentBoard.pins) {
        [pin addObserver:self forKeyPath:@"value" options:NSKeyValueObservingOptionNew context:nil];
    }
}

-(void) removePinObservers{
    THClientProject * project = [THSimulableWorldController sharedInstance].currentProject;
    
    for (THBoardPin * pin in project.currentBoard.pins) {
        [pin removeObserver:self forKeyPath:@"value"];
    }
}

-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    
    if([keyPath isEqualToString:@"value"]){
        
        THBoardPin * pin = object;
                
        if(pin.mode == kPinModeDigitalOutput){
            
            [self sendDigitalOutputForPin:pin];
            
        } else if(pin.mode == kPinModePWM){
            
            [self sendAnalogOutputForPin:pin];
        }
    }
}

#pragma mark BleServiceProtocol

-(void) updateStartButtonToScan{
    
    self.startButton.tintColor = nil;
    self.startButton.title = @"Connect";
    self.startButton.enabled = YES;
}

-(void) updateStartButtonToStop{
    
    self.startButton.tintColor = [UIColor redColor];
    self.startButton.title = @"Stop";
    self.startButton.enabled = YES;
}

-(void) bleDeviceDisconnected:(BLEService *)service{
    [self updateStartButtonToScan];
}

-(void) bleDeviceConnected:(BLEService *) service{
    
    [self updateStartButtonToStop];
    
    isConnecting = NO;
    
    THBLECommunicationModule * bleCommunicationModule = [[THBLECommunicationModule alloc] init];
    bleCommunicationModule.bleService = service;
    bleCommunicationModule.firmataController = self.firmataController;
    
    service.dataDelegate = bleCommunicationModule;
    
    self.firmataController.communicationModule = bleCommunicationModule;
    
    self.isRunningProject = YES;
    
    [self.currentProject startSimulating];
    [self.firmataController sendFirmwareRequest];
}

-(void) bleServiceDidReset {
   //_bleService = nil;
}

#pragma mark Sending

-(NSMutableArray*) digitalPinsForBoard:(THBoard*) board{
    NSMutableArray * array = [NSMutableArray array];
    for (THBoardPin * pin in board.pins) {
        if(pin.type == kPintypeDigital){
            [array addObject:pin];
        }
    }
    return array;
}

-(void) sendDigitalOutputForPin:(THBoardPin*) pin{
    
    THBoard * board = [self.currentProject.boards objectAtIndex:0];
    NSMutableArray * digitalPins = [self digitalPinsForBoard:board];
    
    THBoardPin * firstPin = [digitalPins objectAtIndex:0];
    NSInteger firstPinIdx = firstPin.number;
    
    NSInteger port = pin.number / 8;
    NSInteger value = 0;
    for (NSInteger i = 0; i < 8; i++) {
        NSInteger pinIdx = port * 8 + i - firstPinIdx;

        if(pinIdx >= (NSInteger)digitalPins.count){
            break;
        }
        if(pinIdx >= 0){
            THBoardPin * pin = [digitalPins objectAtIndex:pinIdx];
            if (pin.mode == IFPinModeInput || pin.mode == IFPinModeOutput) {
                if (pin.value) {
                    value |= (1<<i);
                }
            }
        }
    }
    
    [self.firmataController sendDigitalOutputForPort:port value:value];
}

-(void) sendAnalogOutputForPin:(THBoardPin*) pin{
    [self.firmataController sendAnalogOutputForPin:pin.number value:pin.value];
}

-(void) sendPinModes{
    
    THClientProject * project = [THSimulableWorldController sharedInstance].currentProject;
    
    for (THBoardPin * pin in project.currentBoard.pins) {
        
        if(pin.type == kPintypeDigital && pin.mode != kPinModeUndefined && pin.attachedElementPins.count > 0){
            
            [self.firmataController sendPinModeForPin:pin.number mode:pin.mode];
        }
    }
}

//let the accelerometer send over gmp
-(void) sendI2CRequests{
    
    THClientProject * project = [THSimulableWorldController sharedInstance].currentProject;
    
    for (id<THI2CProtocol> component in project.currentBoard.i2cComponents) {

        NSMutableArray * i2cMessages = [component startI2CMessages];
        
        for (THI2CMessage * i2cMessage in i2cMessages) {
            
            switch (i2cMessage.type) {
                    
                case kI2CComponentMessageTypeWrite:

                    [self.firmataController sendI2CWriteToAddress:component.i2cComponent.address reg:i2cMessage.reg bytes:(uint8_t*)i2cMessage.bytes.bytes numBytes:i2cMessage.bytes.length];
                    break;
                    
                case kI2CComponentMessageTypeStartReading:
                    
                    [self.firmataController sendI2CStartReadingAddress:component.i2cComponent.address reg:i2cMessage.reg size:i2cMessage.readSize];
                    break;
                    
                default:
                    break;
            }
        }
    }
}

-(void) sendInputRequests{
    
    THClientProject * project = [THSimulableWorldController sharedInstance].currentProject;
    
    BOOL shouldSendDigitalPinReportRequest = NO;
    
    for (THBoardPin * pin in project.currentBoard.pins) {
        
        if(pin.attachedElementPins.count > 0){
            
            if(pin.mode == kPinModeDigitalInput){
                
                shouldSendDigitalPinReportRequest = YES;
                
            } else if(pin.mode == kPinModeAnalogInput){
                
                [self.firmataController sendReportRequestForAnalogPin:pin.number reports:YES];
            }
        }
    }
    
    if(shouldSendDigitalPinReportRequest){
        
        [self.firmataController sendReportRequestsForDigitalPins];
    }
}

#pragma mark - Firmata Message Handles

-(void) firmataController:(IFFirmata*) firmataController didReceiveFirmwareName:(NSString*) name{
    
    //if([name isEqualToString:kFirmataFirmwareName]){
        [self.firmataController sendResetRequest];
        
        [self sendPinModes];
        [self sendInputRequests];
        [self sendI2CRequests];
    //}
}

-(void) firmataController:(IFFirmata*) firmataController didReceivePinStateResponseForPin:(NSInteger) pin mode:(IFPinMode) mode{
    
    NSLog(@"received mode %ld %d",(long)pin,mode);
}

-(void) firmataController:(IFFirmata*) firmataController didReceiveDigitalMessageForPort:(NSInteger) port value:(NSInteger) value{
    if(self.currentProject.boards.count > 0){
        THBoard * board = [self.currentProject.boards objectAtIndex:0];
        NSMutableArray * digitalPins = [self digitalPinsForBoard:board];
        if(digitalPins.count > 0){
            THBoardPin * firstPin = [digitalPins objectAtIndex:0];
            
            int mask = 1;
            NSInteger pinNumber = port * 8;
            for (mask <<= firstPin.number; pinNumber < digitalPins.count; mask <<= 1, pinNumber++) {
                NSInteger pinIdx = pinNumber - firstPin.number;
                if(pinIdx > 0){
                    THBoardPin * pinObj = [digitalPins objectAtIndex:pinIdx];
                    if (pinObj.mode == IFPinModeInput) {
                        uint32_t val = (value & mask) ? 1 : 0;
                        if (pinObj.value != val) {
                            [pinObj removeObserver:self forKeyPath:@"value"];
                            pinObj.value = val;
                            [pinObj addObserver:self forKeyPath:@"value" options:NSKeyValueObservingOptionNew context:nil];
                        }
                    }
                }
            }
        }
    }
}

-(void) firmataController:(IFFirmata *)firmataController didReceiveAnalogMessageOnChannel:(NSInteger)channel value:(NSInteger)value{

   // NSLog(@"analog msg for pin: %d %d",channel,value);
    
    THClientProject * project = [THSimulableWorldController sharedInstance].currentProject;
    THBoardPin * pinObj = [project.currentBoard analogPinWithNumber:channel];//TODO do the mapping channel - pin
    
    [pinObj removeObserver:self forKeyPath:@"value"];
    pinObj.value = value;
    [pinObj addObserver:self forKeyPath:@"value" options:NSKeyValueObservingOptionNew context:nil];
}

-(void) firmataController:(IFFirmata*) firmataController didReceiveI2CReply:(uint8_t*) buffer length:(NSInteger) length{
    
    uint8_t address = buffer[2] + (buffer[3] << 7);
    NSInteger registerNumber = buffer[4];
    
    THClientProject * project = [THSimulableWorldController sharedInstance].currentProject;
    
    if(!self.firmataController.startedI2C){
        
        NSLog(@"reporting but i2c did not start");
        [self.firmataController sendI2CStopReadingAddress:address];
        
    } else {
        
        id<THI2CProtocol> component = [project.currentBoard I2CComponentWithAddress:address];
        
        THI2CRegister * reg = [component.i2cComponent registerWithNumber:registerNumber];
                
        if(reg){
            /*
            NSLog(@"%d %d %d %d %d %d %d %d",buffer[0],buffer[1],buffer[2],buffer[3],buffer[4],buffer[5],buffer[6],buffer[7]);*/
            
            [component setValuesFromBuffer:buffer+6 length:length-6];
            
            //NSData * data = [NSData dataWithBytes:values length:size];
            //reg.value = data;
        }
    }
}

#pragma mark UI Interaction

-(IBAction)startButtonTapped:(id)sender {
    
    if([BLEDiscovery sharedInstance].connectedService){
        
        [self.currentProject stopSimulating];
        
        [self.deviceController disconnect];
        
    } else {
        
        [self performSegueWithIdentifier:@"segueToDevicesList" sender:self];
        
        //[self updateStartButtonToStarting];
        //[self connectToBle];
    }
}

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if([segue.identifier isEqualToString:@"segueToDevicesList"]){
        
        self.deviceController = segue.destinationViewController;
        self.deviceController.delegate = self;
    }
}
@end
