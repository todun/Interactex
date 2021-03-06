/*
IFPinsController.m
iFirmata

Created by Juan Haladjian on 28/06/2013.

iFirmata is an App to control an Arduino board over Bluetooth 4.0. iFirmata uses the Firmata protocol: www.firmata.org

www.interactex.org

Copyright (C) 2013 TU Munich, Munich, Germany; DRLab, University of the Arts Berlin, Berlin, Germany; Telekom Innovation Laboratories, Berlin, Germany
	
Contacts:
juan.haladjian@cs.tum.edu
katharina.bredies@udk-berlin.de
opensource@telekom.de

    
It has been created with funding from EIT ICT, as part of the activity "Connected Textiles".


This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 
You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#import "IFPinsController.h"
#import "IFPin.h"
#import "BLEService.h"
#import "BLEHelper.h"
#import "IFI2CComponent.h"
#import "IFI2CRegister.h"
#import "IFFirmata.h"
#import "IFI2CComponentProxy.h"

@implementation IFPinsController

-(id) init{
    self = [super init];
    if(self){
        
        self.firmataController = [[IFFirmata alloc] init];
        self.firmataController.delegate = self;
        
        self.digitalPins = [NSMutableArray array];
        self.analogPins = [NSMutableArray array];
        self.i2cComponents = [NSMutableArray array];
        self.i2cComponentProxies = [NSMutableArray array];
        
        
        [self addLsmCompass];
        [self addGenericProxy];
    }
    return self;
}

-(void) addLsmCompass{
    IFI2CComponent * component = [[IFI2CComponent alloc] init];
    component.name = @"LSM303 Breakout";
    component.address = 24;
    
    IFI2CRegister * reg = [[IFI2CRegister alloc] init];
    reg.number = 32;
    [component addRegister:reg];
    
    IFI2CRegister * reg2 = [[IFI2CRegister alloc] init];
    reg2.number = 40;
    reg2.size = 6;
    [component addRegister:reg2];
    
    component.continousReadingRegister = reg2;
    
    [self addI2CComponent:component];
    
    IFI2CComponentProxy * proxy = [[IFI2CComponentProxy alloc] init];
    proxy.component = component;
    proxy.name = component.name;
    proxy.image = [UIImage imageNamed:@"LSMCompass"];
    [self.i2cComponentProxies addObject:proxy];
}

-(void) addGenericProxy{
    
    IFI2CComponentProxy * proxy = [[IFI2CComponentProxy alloc] init];

    proxy.name = @"I2C Component";
    proxy.image = [UIImage imageNamed:@"i2c"];
    [self.i2cComponentProxies addObject:proxy];
}

-(void) reset {
    
    for (IFPin * pin in self.digitalPins) {
        [pin removeObserver:self forKeyPath:@"mode"];
        [pin removeObserver:self forKeyPath:@"value"];
    }
    
    for (IFPin * pin in self.analogPins) {
        [pin removeObserver:self forKeyPath:@"mode"];
        [pin removeObserver:self forKeyPath:@"value"];
        [pin removeObserver:self forKeyPath:@"updatesValues"];
    }
    /*
    for (IFI2CComponent * component in self.i2cComponents) {
        [component removeObserver:self forKeyPath:@"notifies"];
    }*/
    
    [self.digitalPins removeAllObjects];
    [self.analogPins removeAllObjects];
    
    [self.delegate firmataDidUpdateDigitalPins:self];
    [self.delegate firmataDidUpdateAnalogPins:self];
    
    [self resetBuffers];
    
    numDigitalPins = 0;
    numAnalogPins = 0;
    numPins = 0;
    
    self.firmataName = @"iFirmata";
}

-(void) resetBuffers {
    
    for (int i = 0; i < IFPinInfoBufSize; i++) {
        pinInfo[i].analogChannel = 127;
        pinInfo[i].supportedModes = 0;
    }
}

-(void) sendDigitalOutputForPin:(IFPin*) pin{
    if(self.digitalPins.count == 0) return;
    
    IFPin * firstPin = [self.digitalPins objectAtIndex:0];
    NSInteger firstPinIdx = firstPin.number;
    
    NSInteger port = pin.number / 8;
    int value = 0;
    for (int i=0; i < 8; i++) {
        NSInteger pinIdx = port * 8 + i - firstPinIdx;
//        NSLog(@"%d %d",pinIdx,self.digitalPins.count);
        if(pinIdx >= (int)self.digitalPins.count){
            break;
        }
        if(pinIdx >= 0){
            IFPin * pin = [self.digitalPins objectAtIndex:pinIdx];
            if (pin.mode == IFPinModeInput || pin.mode == IFPinModeOutput) {
                if (pin.value) {
                    value |= (1<<i);
                }
            }
        }
    }
    
    [self.firmataController sendDigitalOutputForPort:port value:value];
    
}

-(void) sendOutputForPin:(IFPin*) pin{
    
    if(pin.mode == IFPinModeOutput){
        
        [self sendDigitalOutputForPin:pin];
        
    } else if(pin.mode == IFPinModePWM || pin.mode == IFPinModeServo){
        
        [self.firmataController sendAnalogOutputForPin:pin.number value:pin.value];
        
    }
}

-(void) stopReportingI2CComponent:(IFI2CComponent*) component{
    [self sendStopReportingMessageForI2CComponent:component];
    
    for (IFI2CRegister * reg in component.registers) {
        if(reg.notifies){
            [reg removeObserver:self forKeyPath:@"notifies"];
            reg.notifies = NO;
            [reg addObserver:self forKeyPath:@"notifies" options:NSKeyValueObservingOptionNew context:nil];
        }
    }
}

-(void) sendStopReportingMessageForI2CComponent:(IFI2CComponent*) component{
    for (IFI2CRegister * reg in component.registers) {
        if(reg.notifies){
            [self.firmataController sendI2CStopReadingAddress:component.address];
        }
    }
}

-(void) stopReportingI2CComponents{
    for (IFI2CComponent * component in self.i2cComponents) {
        [self stopReportingI2CComponent:component];
    }
}

-(void) stopReportingAnalogPins{
    for (IFPin * pin in self.analogPins) {
        pin.updatesValues = NO;
    }
}



/*
-(void) sendTestData{
    
    uint8_t buf[16];
    //int len = 0;
    for (int i = 0; i < 16; i++) {
        
        buf[i] = i+100;
        
    }
    [self.bleService sendData:buf count:16];
}*/


-(void) createAnalogPinsFromBuffer:(uint8_t*) buffer length:(NSInteger) length{
    
    NSInteger firstAnalog = numDigitalPins;
    for (; firstAnalog < IFPinInfoBufSize; firstAnalog++) {
        if(pinInfo[firstAnalog].supportedModes & (1<<IFPinModeAnalog)){
            break;
        }
    }
    
    //NSLog(@"first analog at pos: %d",firstAnalog);
    for (int i = 0; i < numAnalogPins; i++) {
                
        IFPin * pin = [IFPin pinWithNumber:i type:IFPinTypeAnalog mode:IFPinModeAnalog];
        pin.analogChannel = pinInfo[i+firstAnalog].analogChannel;
        [self.analogPins addObject:pin];
        
        int value = buffer[4];
        if (length > 6) value |= (buffer[5] << 7);
        if (length > 7) value |= (buffer[6] << 14);
        pin.value = value;
        
        [pin addObserver:self forKeyPath:@"mode" options:NSKeyValueObservingOptionNew context:nil];
        [pin addObserver:self forKeyPath:@"value" options:NSKeyValueObservingOptionNew context:nil];
        [pin addObserver:self forKeyPath:@"updatesValues" options:NSKeyValueObservingOptionNew context:nil];
        
        [self.delegate firmataDidUpdateAnalogPins:self];
    }
}

-(void) countPins{
    numPins = 0;
    numAnalogPins = 0;
    
    for (int pin=0; pin < 128; pin++) {
        if(pinInfo[pin].supportedModes ){
            numPins++;            
            
            if(pinInfo[pin].supportedModes & (1<<IFPinModeAnalog)){
                numAnalogPins++;
            }
        }
    }
    numDigitalPins = numPins - numAnalogPins;
    
    //NSLog(@"NumPins: %d, Digital: %d, Analog: %d",self.numPins,self.numDigitalPins,self.numAnalogPins);
}

#pragma mark - Firmata Message Handles

-(void) firmataController:(IFFirmata*) firmataController didReceiveFirmwareName:(NSString*) name{
    
    self.firmataName = name;
    [self.delegate firmata:self didUpdateTitle:self.firmataName];
    if(self.digitalPins.count == 0 && self.analogPins.count == 0){
        NSLog(@"sending analog msg");
        [self.firmataController sendAnalogMappingRequest];
    }
}

-(void) firmataController:(IFFirmata*) firmataController didReceiveAnalogMessageOnChannel:(NSInteger) channel value:(NSInteger) value{
    
    for (IFPin * pin in self.analogPins) {
        if (pin.analogChannel == channel) {
            pin.value = value;
            return;
        }
    }
}

-(void) firmataController:(IFFirmata*) firmataController didReceiveDigitalMessageForPort:(NSInteger) portNumber value:(NSInteger) value{
    if(self.digitalPins.count > 0){
        
        IFPin * firstPin = (IFPin*) [self.digitalPins objectAtIndex:0];

        NSInteger pinNumber = portNumber * 8;
        for (int mask = 1; mask & 0xFF ; mask <<= 1, pinNumber++) {
            NSInteger pinIdx = pinNumber - firstPin.number;
            if(pinIdx >= 0 && pinIdx < self.digitalPins.count){
                IFPin * pinObj = [self.digitalPins objectAtIndex:pinNumber - firstPin.number];

                if (pinObj.mode == IFPinModeInput) {
                    uint32_t val = (value & mask) ? 1 : 0;
                    if (pinObj.value != val) {
                        pinObj.value = val;
                    }
                }
            }
        }
    }
}

//makes the pin query for the initial pins. The other queries happen later
-(void) sendInitialPinStateQuery{
    
    NSInteger buf[4];
    int len = 0;
    for (int pin=0; pin < IFPinInfoBufSize; pin++) {
        if((pinInfo[pin].supportedModes & (1<<IFPinModeInput)) && (pinInfo[pin].supportedModes & (1<<IFPinModeOutput)) && !(pinInfo[pin].supportedModes & (1<<IFPinModeAnalog))){
            
            buf[len++] = pin;
            
            if(len == 4){
                break;
            }
        }
    }
    
    [self.firmataController sendPinQueryForPinNumbers:buf length:len];
}

-(void) firmataController:(IFFirmata*) firmataController didReceiveAnalogMappingResponse:(uint8_t*) buffer length:(NSInteger) length {
    
    int pin=0;
    for (int i=2; i<length-1; i++) {
        
        pinInfo[pin].analogChannel = buffer[i];
        pin++;
    }
    
    [self.firmataController sendCapabilitiesRequest];
}

-(void) firmataController:(IFFirmata*) firmataController didReceiveCapabilityResponse:(uint8_t*) buffer length:(NSInteger) length{
    
    for (int i=2, n=0, pin=0; i<length; i++) {
        if (buffer[i] == 127) {
            pin++;
            n = 0;
            continue;
        }
        if (n == 0) {
            pinInfo[pin].supportedModes |= (1<<buffer[i]);
        }
        n = n ^ 1;
    }
    
    [self countPins];
    [self createAnalogPinsFromBuffer:buffer length:length];
    [self sendInitialPinStateQuery];
}

-(void) makePinQueryForSubsequentPinsStartingAtPin:(int) pin{
    
    NSInteger numPinsToSend = 0;
    NSInteger pinNumbers[4];
    
    for(int i = pin ; i < pin + 4; i++){

        if((pinInfo[i].supportedModes & (1<<IFPinModeInput)) && (pinInfo[i].supportedModes & (1<<IFPinModeOutput)) && !(pinInfo[i].supportedModes & (1<<IFPinModeAnalog))){
            pinNumbers[numPinsToSend++] = i;
            
        }
    }
    if(numPinsToSend > 0){
        [self.firmataController sendPinQueryForPinNumbers:pinNumbers length:numPinsToSend];
    }
}

-(void) firmataController:(IFFirmata*) firmataController didReceivePinStateResponse:(uint8_t*) buffer length:(NSInteger) length {

    int pinNumber = buffer[2];
    int mode = buffer[3];
    
    //NSLog(@"Handles PinState Response %d %d",pinNumber,mode);
    
    if((pinInfo[pinNumber].supportedModes & (1<<IFPinModeInput) || pinInfo[pinNumber].supportedModes & (1<<IFPinModeOutput)) && !(pinInfo[pinNumber].supportedModes & (1<<IFPinModeAnalog))){
        
        IFPin * pin = [IFPin pinWithNumber:pinNumber type:IFPinTypeDigital mode:mode];
        [self.digitalPins addObject:pin];
        
        int value = buffer[4];
        if (length > 6) value |= (buffer[5] << 7);
        if (length > 7) value |= (buffer[6] << 14);
        pin.value = value;
        
        [pin addObserver:self forKeyPath:@"mode" options:NSKeyValueObservingOptionNew context:nil];
        [pin addObserver:self forKeyPath:@"value" options:NSKeyValueObservingOptionNew context:nil];
        
        [self.delegate firmataDidUpdateDigitalPins:self];
        
        if(self.digitalPins.count % 4 == 0){
            [self makePinQueryForSubsequentPinsStartingAtPin:pinNumber+1];
        } else {
            [self.firmataController sendReportRequestsForDigitalPins];
        }
        
    } else {
        
       // NSLog(@"pin %d is in mode: %d",pinNumber,mode);
        
    }
}

-(void) firmataController:(IFFirmata*) firmataController didReceiveI2CReply:(uint8_t*) buffer length:(NSInteger)length {
    
    uint8_t address = buffer[2] + (buffer[3] << 7);
    //NSInteger registerNumber = buffer[4] + 128;
    NSInteger registerNumber = buffer[4];
    //NSLog(@"addr: %d reg %d ",address,registerNumber);
    if(!self.firmataController.startedI2C){
        
        NSLog(@"reporting but i2c did not start");
        [self.firmataController sendI2CStopReadingAddress:address];
        
    } else {
        
        IFI2CComponent * component = nil;
        for (IFI2CComponent * aComponent in self.i2cComponents) {
            if(aComponent.address == address){
                component = aComponent;
                break;
            }
        }
        
        IFI2CRegister * reg = [component registerWithNumber:registerNumber];
        if(reg){
            uint8_t values[reg.size];
            NSInteger parseBufCount = 6;
            for (int i = 0; i < reg.size; i++) {
                
                uint8_t byte1 = buffer[parseBufCount++];
                uint8_t value = byte1 + (buffer[parseBufCount++] << 7);
                values[i] = value;
            }

            NSData * data = [NSData dataWithBytes:values length:reg.size];
            reg.value = data;
            
        }
        
        NSData * data = [NSData dataWithBytes:buffer length:length];
        
        NSString * dataStr = [BLEHelper DataToString:data];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNewI2CData object:dataStr];
    }
}


#pragma mark -- Pin Delegate

-(IFI2CComponent*) componentForRegister:(IFI2CRegister*) reg{
    for (IFI2CComponent * component in self.i2cComponents) {
        for (IFI2CRegister * aRegister in component.registers) {
            if(aRegister == reg){
                return component;
            }
        }
    }
    return nil;
}

-(void) sendI2CStartStopReportingRequestForRegister:(IFI2CRegister*) reg fromComponent:(IFI2CComponent*) component{
    
    if(reg.notifies){
        [self.firmataController sendI2CStartReadingAddress:component.address reg:reg.number size:reg.size];
        
    } else {
        [self.firmataController sendI2CStopReadingAddress:component.address];
        
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath  ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if ([keyPath isEqual:@"mode"]) {
        
        IFPin * pin = object;
        [self.firmataController sendPinModeForPin:pin.number mode:pin.mode];
        
        if(pin.mode == IFPinModeInput){
            [self.firmataController sendReportRequestsForDigitalPin:pin.number reports:YES];
        }
        
    } else if([keyPath isEqual:@"value"]){
        
        [self sendOutputForPin:object];
        
    } else if([keyPath isEqual:@"updatesValues"]){
        
        IFPin * pin = object;
        [self.firmataController sendReportRequestForAnalogPin:pin.number reports:pin.updatesValues];
        
    } else if([keyPath isEqual:@"notifies"]){
        
        IFI2CComponent * component = [self componentForRegister:object];
        [self sendI2CStartStopReportingRequestForRegister:object fromComponent:component];
        
    }
}

#pragma mark -- I2C Components

-(void) addObserversForI2CComponent:(IFI2CComponent*) component{
    
    for (IFI2CRegister * reg in component.registers) {
        [reg addObserver:self forKeyPath:@"notifies" options:NSKeyValueObservingOptionNew context:nil];
    }
}

-(void) addObserversForI2CComponents{
    for (IFI2CComponent * component in self.i2cComponents) {
        [self addObserversForI2CComponent:component];
    }
}

-(void) removeObserversForI2CComponent:(IFI2CComponent*) component{
    for (IFI2CRegister * reg in component.registers) {
        [reg removeObserver:self forKeyPath:@"notifies"];
    }
}

-(void) removeObserversForI2CComponents{
    for (IFI2CComponent * component in self.i2cComponents) {
        [self removeObserversForI2CComponent:component];
    }
}

-(void) setI2cComponents:(NSMutableArray *)i2cComponents{
    if(_i2cComponents != i2cComponents){
        
        [self removeObserversForI2CComponents];
        
        _i2cComponents = i2cComponents;
        
        [self addObserversForI2CComponents];
        
        [self.delegate firmataDidUpdateI2CComponents:self];
    }
}

-(void) addI2CComponent:(IFI2CComponent*) component{
    [self addObserversForI2CComponent:component];
    
    [self.i2cComponents addObject:component];
    [self.delegate firmataDidUpdateI2CComponents:self];
}

-(void) removeI2CComponent:(IFI2CComponent*) component{
    [self removeObserversForI2CComponent:component];
    
    [self sendStopReportingMessageForI2CComponent:component];
    
    [self.i2cComponents removeObject:component];
    [self.delegate firmataDidUpdateI2CComponents:self];
}

-(void) addI2CRegister:(IFI2CRegister*) reg toComponent:(IFI2CComponent*) component{
    [reg addObserver:self forKeyPath:@"notifies" options:NSKeyValueObservingOptionNew context:nil];
    [component addRegister:reg];
}

-(void) removeI2CRegister:(IFI2CRegister*) reg fromComponent:(IFI2CComponent*) component{
    if(reg.notifies){
        [self.firmataController sendI2CStopReadingAddress:component.address];
    }
    
    [reg removeObserver:self forKeyPath:@"notifies"];
    [component removeRegister:reg];
}

@end
