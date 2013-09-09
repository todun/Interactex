//
//  TFEditorToolsViewController.m
//  Tango
//
//  Created by Juan Haladjian on 11/26/12.
//  Copyright (c) 2012 Juan Haladjian. All rights reserved.
//

#import "TFEditorToolsViewController.h"
#import "TFEditor.h"
#import "THProjectViewController.h"
#import "THCustomEditor.h"
#import "THCustomSimulator.h"
#import "THDirector.h"

@implementation TFEditorToolsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {

        _barButtonItems = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _editingTools = [NSArray arrayWithObjects:self.connectButton,self.duplicateButton, self.removeButton,self.lilypadItem, nil];
    
    _lilypadTools = [NSArray arrayWithObjects:self.connectButton,self.duplicateButton, self.removeButton,self.tshirtItem, nil];
    
    _simulatingTools = [NSArray arrayWithObjects:self.pinsModeItem,self.pushItem,nil];
    
    [self addEditionButtons];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) unselectAllButtons{
    
    self.connectButton.tintColor = nil;
    self.duplicateButton.tintColor = nil;
    self.removeButton.tintColor = nil;
}

-(void) updateButtons{
    TFEditor * editor = (TFEditor*) [THDirector sharedDirector].currentLayer;
    
    [self unselectAllButtons];
    
    if(editor.state == kEditorStateConnect){
        self.connectButton.tintColor = [UIColor blueColor];
    } else if(editor.state == kEditorStateDuplicate){
        self.duplicateButton.tintColor = [UIColor blueColor];
    } else if(editor.state == kEditorStateDelete){
        self.removeButton.tintColor = [UIColor blueColor];
    }
}

-(void) checkSwitchToState:(TFEditorState) state{
    THProjectViewController * projectController = [THDirector sharedDirector].projectController;
    if(projectController.state == kAppStateEditor){
        TFEditor * editor = (TFEditor*) projectController.currentLayer;
        if(editor.state == state){
            editor.state = kEditorStateNormal;
        } else {
            editor.state = state;
        }
        [self updateButtons];
    }
}

- (IBAction)connectTapped:(id)sender {
    [self checkSwitchToState:kEditorStateConnect];
}

- (IBAction)duplicateTapped:(id)sender {
    
    [self checkSwitchToState:kEditorStateDuplicate];
}

- (IBAction)removeTapped:(id)sender {
    [self checkSwitchToState:kEditorStateDelete];
}

-(void) setHidden:(BOOL)hidden{
    if(!hidden){
        [self unselectAllButtons];
    }
    self.view.hidden = hidden;
}

-(BOOL) hidden{
    return self.view.hidden;
}

-(void) reloadBarButtonItems{
    
    UITabBar * tabBar = (UITabBar*) self.view;
    tabBar.items = _barButtonItems;
}


-(void) addCustomBarButtons {
    /*
     if(_barButtonItems.count <= 1){
     
     NSInteger count = [self.toolbarItems. numberOfToolbarButtonsForState:self.state];
     for (int i = 0; i < count; i++) {
     UIBarButtonItem * item = [dataSource toolbarButtonAtIdx:i forState:self.state];
     [_barButtonItems addObject:item];
     }
     }*/
}

-(void) addEditionButtons{

    self.toolBar.items = _editingTools;
}

-(void) addLilypadButtons{
    
    self.toolBar.items = _lilypadTools;
}

-(void) addSimulationButtons{
    
    self.toolBar.items = _simulatingTools;
}

- (IBAction)lilypadPressed:(id)sender {
    
    THCustomEditor * editor = (THCustomEditor*) [THDirector sharedDirector].currentLayer;
    if(!editor.isLilypadMode){
        [editor startLilypadMode];
        [self addLilypadButtons];
    }
}

- (IBAction)tshirtPressed:(id)sender {
    
    THCustomEditor * editor = (THCustomEditor*) [THDirector sharedDirector].currentLayer;
    if(editor.isLilypadMode){
        [editor stopLilypadMode];
        [self addEditionButtons];
    }
}

- (IBAction)pinsModePressed:(id)sender {
    THCustomSimulator * simulator = (THCustomSimulator*) [THDirector sharedDirector].currentLayer;
    
    if(simulator.state == kSimulatorStateNormal){
        [simulator addPinsController];
    } else {
        [simulator removePinsController];
    }
}

- (IBAction)pushPressed:(id)sender {
    THServerController * serverController = [THDirector sharedDirector].serverController;
    if([serverController serverIsRunning]){
        THCustomProject * project = (THCustomProject*) [THDirector sharedDirector].currentProject;
        [serverController pushProjectToAllClients:project];
    }
}

@end