//
//  THGestures.m
//  TangoHapps
//
//  Created by Timm Beckmann on 03/04/14.
//  Copyright (c) 2014 Technische Universität München. All rights reserved.
//

#import "THGestureEditableObject.h"
#import "THHardwareComponentEditableObject.h"
#import "THGesturePaletteItem.h"
#import "THCustomPaletteItem.h"
#import "THGestureProperties.h"
#import "THGesture.h"

@implementation THGestureEditableObject

-(void) load{
    
    self.simulableObject = [[THGesture alloc] init];
    
    self.sprite = [CCSprite spriteWithFile:@"gesture.png"];
    [self addChild:self.sprite];
        
    self.canBeAddedToPalette = YES;
    self.canBeAddedToGesture = YES;
    self.acceptsConnections = NO;
    
    self.scale = 1;
    
    self.count = 0;
    
    
    _layer = [CCLayerColor node];
    _layer.color = ccc3(200, 200, 200);
    _layer.opacity = 255;
    _layer.contentSize = self.sprite.boundingBox.size;
    _layer.visible = false;
    [self addChild:_layer];
    
    _outputs = [NSMutableArray array];

}

-(id) initWithName:(NSString*) name{
    self = [super init];
    if(self){
        self.name = name;
        
        [self load];
    }
    return self;
}


#pragma mark - Archiving

-(id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if(self){
        
        self.name = [decoder decodeObjectForKey:@"name"];
        self.saveName = [decoder decodeObjectForKey:@"saveName"];
        
        [self load];

        NSArray * attachments = [decoder decodeObjectForKey:@"attachments"];
        for (TFEditableObject * attachment in attachments) {
            [self attachGestureObject:attachment];
        }
        
        NSArray * outputs = [decoder decodeObjectForKey:@"outputs"];
        for (THOutputEditable * obj in outputs) {
            [self attachOutput:obj];
        }
        
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:self.name forKey:@"name"];
    
    [coder encodeObject:self.saveName forKey:@"saveName"];
    
    [coder encodeObject:[self getAttachments] forKey:@"attachments"];
    
    [coder encodeObject:[self outputs] forKey:@"outputs"];

}

-(id)copyWithZone:(NSZone *)zone {
    THGestureEditableObject * copy = [super copyWithZone:zone];
    
    copy.name = self.name;
    copy.saveName = self.saveName;

    [copy load];
    
    for (TFEditableObject * attachment in [self getAttachments]) {
        [copy attachGestureObject:[attachment copy]];
    }
    
    for (THOutputEditable * obj in _outputs) {
        [copy attachOutput:[obj copy]];
    }
    
    return copy;
}


#pragma mark - Property Controllers

-(NSArray*)propertyControllers {
    NSMutableArray *controllers = [NSMutableArray array];
    [controllers addObject:[THGestureProperties properties]];
    [controllers addObjectsFromArray:[super propertyControllers]];
    return controllers;
}

#pragma mark - World and Layer

-(void) addToWorld{
    THProject * project = (THProject*) [THDirector sharedDirector].currentProject;
    [project addGesture:self];
    
    for (TFEditableObject * attachment in [self getAttachments]) {
        [attachment addToWorld];
    }
}

-(void) removeFromWorld{
    NSMutableArray * attachments = [NSMutableArray arrayWithArray:[self getAttachments]];
    for (TFEditableObject * object in attachments) {
        [object removeFromWorld];
    }
    
    THProject * project = (THProject*) [THDirector sharedDirector].currentProject;
    [project removeGesture:self];
    [super removeFromWorld];
}

-(void) addToLayer:(TFLayer*) layer{
    [layer addEditableObject:self];
}

-(void) removeFromLayer:(TFLayer*) layer{
    [layer removeEditableObject:self];
}

#pragma mark - Methods

-(THPaletteItem*) paletteItem{
    THGesturePaletteItem * paletteItem = [THCustomPaletteItem customPaletteItemWithName:self.name object:self];
    paletteItem.saveName = _saveName;
    return paletteItem;
}

-(void) objectRemoved:(NSNotification*) notification{
    TFEditableObject * object = notification.object;
    THGesture* gest = (THGesture *) self.simulableObject;
    [gest deattachGestureObject:object];
}

-(void) attachGestureObject:(TFEditableObject*) object{
    THGesture* gest = (THGesture *) self.simulableObject;
    [gest attachGestureObject:object];
    [self addChild:object z:1];
    if (object.scale ==1) object.scale /= 15;
    if (!_layer.visible) object.visible = false;
    object.attachedToGesture = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(objectRemoved:) name:kNotificationObjectRemoved object:object];
}

-(void) deattachGestureObject:(TFEditableObject*) object{
    THGesture* gest = (THGesture *) self.simulableObject;
    [gest deattachGestureObject:object];
    [object removeFromParentAndCleanup:YES];
    object.scale = 1;
    object.attachedToGesture = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationObjectRemoved object:object];
}

-(void) openClose {
    _isOpen = !_isOpen;
    
    THGesture* gest = (THGesture *) self.simulableObject;
    if (_isOpen) {
        _layer.visible = true;
        self.scale = 10;
        self.z = kGestureZ;
        [gest visible];
        for (THOutputEditable* obj in _outputs) {
            obj.visible = true;
        }
    } else {
        _layer.visible = false;
        self.scale = 1;
        self.z = kGestureObjectZ;
        [gest invisible];
        for (THOutputEditable* obj in _outputs) {
            obj.visible = false;
        }
    }
}

-(void) outputAmountChanged:(int)count {
    if (count > _count) {
        _count++;
        [self addOutput];
    }
    else if (count < _count) {
        _count--;
        [self deleteOutput];
    }
}

-(void) attachOutput:(THOutputEditable *)object {
    [self addChild:object z:1];
    if (object.scale ==1) object.scale /= 15;
    if (!_layer.visible) object.visible = false;
    object.attachedToGesture = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outputRemoved:) name:kNotificationObjectRemoved object:object];
    
    [_outputs addObject:object];
    
}

-(void) addOutput {
    THOutputEditable * object = [[THOutputEditable alloc] init];
    
    CGPoint position = [self.parent convertToWorldSpace:self.position];
    
    position.y -= self.boundingBox.size.height/2.2f;
    position.x += (_count -3) * self.boundingBox.size.width/5.f;
    
    object.position = [self convertToNodeSpace:position];
    
    [self addChild:object z:1];
    if (object.scale ==1) object.scale /= 15;
    //if (!_layer.visible) object.visible = false;
    object.attachedToGesture = self;
    
    [_outputs addObject:object];

    THProject * project = (THProject*) [THDirector sharedDirector].currentProject;
    [project addGesture:object];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outputRemoved:) name:kNotificationObjectRemoved object:object];
    
}

-(void) outputRemoved:(NSNotification*) notification{

}

-(void) deleteOutput {
    THOutputEditable * object = [_outputs lastObject];
    [_outputs removeObject:object];
    [object removeFromParentAndCleanup:YES];
    object.scale = 1;
    object.attachedToGesture = nil;
    
    THProject * project = (THProject*) [THDirector sharedDirector].currentProject;
    [project removeGesture:object];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationObjectRemoved object:object];
    
}

-(NSMutableArray*) getAttachments {
    THGesture * gest = (THGesture *) self.simulableObject;
    return gest.attachments;
}

-(NSString*) description{
    return @"Gesture";
}

-(void) prepareToDie{
    THGesture* gest = (THGesture *) self.simulableObject;
    [gest emptyAttachments];
    [super prepareToDie];
}

@end