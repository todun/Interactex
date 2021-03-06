/*
THProjectViewController.m
Interactex Designer

Created by Juan Haladjian on 05/10/2013.

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

#import "THProjectViewController.h"
#import "THProjectViewController.h"
#import "THTabbarViewController.h"
#import "THMenubarViewController.h"
#import "THSimulator.h"
#import "THEditor.h"
#import "THiPhoneEditableObject.h"
#import "THProjectProxy.h"
#import "THViewEditableObject.h"

#import "THCustomComponent.h"

@implementation THProjectViewController

float const kPalettePullY = 0;
float const kToolsTabMargin = 5;

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
    
    CCDirector * ccDirector = [CCDirector sharedDirector];
    
    ccDirector.delegate = self;
    
    [self addChildViewController:ccDirector];
    [self.view addSubview:ccDirector.view];
    [self.view sendSubviewToBack:ccDirector.view];
    [ccDirector didMoveToParentViewController:self];
    
    [THDirector sharedDirector].projectController = self;
    
    [self loadTools];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    //tbaControler
    _tabController = [[THTabbarViewController alloc] initWithNibName:@"THTabbar" bundle:nil];
    [_tabController.view setFrame:CGRectMake(0, 0, kPaletteSectionWidth, 722.0f)];
    [self.view addSubview:_tabController.view];
    
    
    //menu bar
    CGRect menuMainViewFrame = CGRectMake(0, 0, 1024.0f, kMenuBarHeight);
    _menuView = [[UIView alloc] initWithFrame:menuMainViewFrame];
    _menuButtonsView = [[UIView alloc] initWithFrame:menuMainViewFrame];
    _menuButtonsView.layer.masksToBounds = NO;
    _menuButtonsView.layer.shadowOffset = CGSizeMake(0, -5);
    _menuButtonsView.layer.shadowRadius = 4;
    _menuButtonsView.layer.shadowOpacity = 0.5;
    [_menuView addSubview:_menuButtonsView];
    [self.view insertSubview:_menuView belowSubview:_tabController.view];

    //zoom slider
    _zoomSlider = [[UISlider alloc] initWithFrame:CGRectMake(412.0, 688.0, 200.0, 32.0)];
    [_zoomSlider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
    [_zoomSlider setBackgroundColor:[UIColor clearColor]];
    [_zoomSlider setMinimumValueImage:[UIImage imageNamed:@"zoomMinus.png"]];
    [_zoomSlider setMaximumValueImage:[UIImage imageNamed:@"zoomPlus.png"]];
    [_zoomSlider setMinimumTrackTintColor:[UIColor blackColor]];
    _zoomSlider.minimumValue = kLayerMinScale;
    _zoomSlider.maximumValue = kLayerMaxScale;
    _zoomSlider.continuous = YES;
    _zoomSlider.value = 1.0;
    [self.view addSubview:_zoomSlider];
    
    
    [self registerAppNotifications];
    
    _state = kAppStateEditor;
    
    [self addEditionButtons];
    
    [self showTabBar];
    
    [self updateEditingButtonsTint];
    
    [self reloadContent];
    
    THProject * project = [THDirector sharedDirector].currentProject;
    self.navigationItem.title = project.name;
    self.title = project.name;
    
    _currentProjectName = [THDirector sharedDirector].currentProject.name;
    
    [self startWithEditor];
}

-(void) viewDidAppear:(BOOL)animated{
    
}

-(void) viewWillDisappear:(BOOL)animated {
    
    [self saveCurrentProjectAndPalette];
    
    NSNotificationCenter * center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationSignificantTimeChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationEditorZoomReset object:nil];
    
    [self.currentLayer prepareToDie];
    [[THDirector sharedDirector].currentProject prepareToDie];
    
    [_currentLayer removeFromParentAndCleanup:YES];
    
    _currentLayer = nil;
    _currentScene = nil;
    
    [THDirector sharedDirector].currentProject = nil;
    [THDirector sharedDirector].currentProxy = nil;   
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    [[CCDirector sharedDirector] setDelegate:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    [[CCDirector sharedDirector] purgeCachedData];
}

#pragma mark - Saving and restoring projects

-(void) registerAppNotifications{
    // Observe some notifications so we can properly instruct the director.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationSignificantTimeChange:)
                                                 name:UIApplicationSignificantTimeChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateEditorZoomSlider:)
                                                 name:kNotificationEditorZoomReset
                                               object:nil];
}

-(void) saveCurrentProjectAndPalette{
    
    THDirector * director = [THDirector sharedDirector];
    if(!director.currentProject.isEmpty){
        [self saveCurrentProject];
    }
    [self.tabController.paletteController save];
}

-(void) saveCurrentProject{
    THDirector * director = [THDirector sharedDirector];
    THProject * currentProject = director.currentProject;
        
    UIImage * image = [TFHelper screenshot];
    
    if(![THProject doesProjectExistWithName:currentProject.name]){ // if it is a new project
        
        THProjectProxy * proxy = [THProjectProxy proxyWithName:director.currentProject.name];
        proxy.image = image;
        if(![director.projectProxies containsObject:proxy]){
            [director.projectProxies addObject:proxy];
            [director saveProjectProxies];
        }
    } else { //if it already existed, its name may have changed
        director.currentProxy.name = director.currentProject.name;
        director.currentProxy.image = image;
    }
    
    [director.currentProject save];
    
    //[self storeImageForCurrentProject:image];
}

-(void) restoreCurrentProject{
    
    THDirector * director = [THDirector sharedDirector];
    
    [director.currentProject prepareToDie];
    
    if(_currentProjectName != nil){
        director.currentProject = [THProject projectSavedWithName:_currentProjectName];
    }
}

#pragma mark - Notification handlers

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [[CCDirector sharedDirector] pause];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [[CCDirector sharedDirector] resume];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [[CCDirector sharedDirector] stopAnimation];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [[CCDirector sharedDirector] startAnimation];
}


- (void)applicationWillTerminate:(NSNotification *)notification
{
    [[CCDirector sharedDirector] end];
}

- (void)applicationSignificantTimeChange:(NSNotification *)notification
{
    [[CCDirector sharedDirector] setNextDeltaTimeZero:YES];
}

#pragma mark - PalettePull

-(void) addPalettePullGestureRecognizer{
    
    self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moved:)];
    self.panRecognizer.delegate = self;
    self.panRecognizer.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.panRecognizer];
}

-(void) removePalettePullRecognizer{
    [self.view removeGestureRecognizer:self.panRecognizer];
    self.panRecognizer = nil;
}

-(void) updatePalettePullVisibility{
    self.palettePullImageView.hidden = self.state;
}

-(void) addPalettePull{
    UIImage * image = [UIImage imageNamed:@"palettePull"];
    self.palettePullImageView = [[UIImageView alloc] initWithImage:image];
    
    CGRect paletteFrame = self.tabController.view.frame;
    self.palettePullImageView.frame = CGRectMake(paletteFrame.origin.x + paletteFrame.size.width, kPalettePullY, image.size.width, image.size.height);
    
    [self.view addSubview:self.palettePullImageView];
    
    //[self addPalettePullGestureRecognizer]; // Nazmus commented 12 Feb - to remove palette pull functionality
}

-(void) moved:(UIPanGestureRecognizer*) sender{
    if(sender.state == UIGestureRecognizerStateBegan){
        
        CGPoint location = [sender locationInView:self.view];
        if(CGRectContainsPoint(self.palettePullImageView.frame,location)){
            self.movingTabBar = YES;
            
            THEditor * editor = (THEditor*) self.currentLayer;
            editor.shouldRecognizePanGestures = NO;
            
        } else {
            self.movingTabBar = NO;
        }
        
    } else if(sender.state == UIGestureRecognizerStateChanged){
        if(self.movingTabBar){
            
            CGPoint translation = [sender translationInView:self.view];
            
            //set palette frame
            CGRect paletteFrame = self.tabController.view.frame;
            paletteFrame.origin.x = paletteFrame.origin.x + translation.x;
            if(paletteFrame.origin.x > 0){
                paletteFrame.origin.x = 0;
            }
            self.tabController.view.frame = paletteFrame;
            
            //set 
            CGRect imageViewFrame = self.palettePullImageView.frame;
            imageViewFrame.origin.x = paletteFrame.origin.x + paletteFrame.size.width;
            if(imageViewFrame.origin.x < 0){
                imageViewFrame.origin.x = 0;
            }
            self.palettePullImageView.frame = imageViewFrame;
            
            [sender setTranslation:CGPointMake(0, 0) inView:self.view];
        }
    } else {
        
        /// Nazmus 28 June 14
        if(self.movingTabBar){
            CGPoint velocity = [sender velocityInView:self.view];
            if(velocity.x > 0)
            {
                //NSLog(@"Final gesture went right");
                //set palette frame
                CGRect paletteFrame = self.tabController.view.frame;
                paletteFrame.origin.x = 0;
                self.tabController.view.frame = paletteFrame;
                
                //set palette pull icon frame
                CGRect imageViewFrame = self.palettePullImageView.frame;
                imageViewFrame.origin.x = paletteFrame.size.width;;
                self.palettePullImageView.frame = imageViewFrame;
            }
            else
            {
                //NSLog(@"Final gesture went left");
                //set palette frame
                CGRect paletteFrame = self.tabController.view.frame;
                paletteFrame.origin.x = -paletteFrame.size.width;
                self.tabController.view.frame = paletteFrame;
                
                //set palette pull icon frame
                CGRect imageViewFrame = self.palettePullImageView.frame;
                imageViewFrame.origin.x = 0;
                self.palettePullImageView.frame = imageViewFrame;
            }
        }
        ///
        
        self.movingTabBar = NO;
        
        THEditor * editor = (THEditor*) self.currentLayer;
        editor.shouldRecognizePanGestures = YES;
    }
}

#pragma mark - Methods

-(void)hideTabBar
{
    _tabController.hidden = YES;
}

-(void)showTabBar
{
    _tabController.hidden = NO;
}

-(void)hideMenuBar
{
    _menuView.hidden = YES;
}

-(void)showMenuBar
{
    _menuView.hidden = NO;
}

-(void)hideZoomBar
{
    _zoomSlider.hidden = YES;
}

-(void)showZoomBar
{
    _zoomSlider.hidden = NO;
}

#pragma mark - Simulation

//XXX check
-(void) startWithEditor{
    
    THEditor * editor = [THEditor node];
    editor.dragDelegate = self.tabController.paletteController;
    _currentLayer = editor;
    CCScene * scene = [CCScene node];

    [scene addChild:_currentLayer];
    
    if([CCDirector sharedDirector].runningScene){
        [[CCDirector sharedDirector] replaceScene:scene];
    } else {
        [[CCDirector sharedDirector] runWithScene:scene];
    }
    
    [_currentLayer willAppear];
    
    _tabController.paletteController.delegate = editor;
    _state = kAppStateEditor;
    
    [self updateEditingButtonsTint];
}

-(void) switchToLayer:(TFLayer*) layer{
    [_currentLayer willDisappear];
    _currentLayer = layer;
    [_currentLayer willAppear];
    
    CCScene * scene = [CCScene node];
    [scene addChild:_currentLayer];
    
    [[CCDirector sharedDirector] replaceScene:scene];
}

-(void) startSimulation {
    if(_state == kAppStateEditor){

        _state = kAppStateSimulator;
        
        [self saveCurrentProject];
        
        THEditor * editor = (THEditor*) [THDirector sharedDirector].currentLayer;
        THSimulator * simulator = [THSimulator node];
        
        [self switchToLayer:simulator];
        
        lastEditorZoomableLayerPosition = editor.zoomableLayer.position;
        lastEditorZoom = editor.zoomLevel;
        
        simulator.zoomLevel = editor.zoomLevel;
        simulator.zoomableLayer.position = editor.zoomableLayer.position;
        
        [self hideTabBar];
        [self hideMenuBar];
        [self hideZoomBar];
        
        [self addSimulationButtons];
        
        THProject * project = (THProject*) [THDirector sharedDirector].currentProject;
        project.iPhone.visible = YES;

        [self updatePinsModeItemTint];
    }
}

-(void) endSimulation {
    if(_state == kAppStateSimulator){
        
        _state = kAppStateEditor;
        
        [self restoreCurrentProject];
        
        THEditor * editor = [THEditor node];
        
        editor.dragDelegate = self.tabController.paletteController;
        [self switchToLayer:editor];
        
        editor.zoomableLayer.position = lastEditorZoomableLayerPosition;
        editor.zoomLevel = lastEditorZoom;
        
        [self updateEditingButtonsTint];
        
        _tabController.paletteController.delegate = editor;
        
        [self showTabBar];
        [self showMenuBar];
        [self.tabController showTab:0];
        [self showZoomBar];
        
        self.editingTools = self.editingToolsWithVPmode;
        [self addEditionButtons];
        //[self updatePalettePullVisibility]; //Nazmus 12 Feb commented
        //[self removePalettePullRecognizer];
        [self updateHideIphoneButtonTint];
    }
}

- (void)toggleAppState {
    if(_state == kAppStateEditor){
        [self startSimulation];
    } else{
        [self endSimulation];
    }
}

#pragma mark - View Lifecycle

-(void) reloadContent{
    [self.tabController.paletteController reloadPalettes];
}

-(void) addBarButtonWithImageName:(NSString*) imageName{
    
    //UIImage * image = [UIImage imageNamed:@"play.png"];
}

#pragma mark - Gesture Recognizer

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft);
}

-(BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer{
    return YES;
}

#pragma mark - Tools

//Nazmus added
-(UILabel*) createDivider{
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, kMenuBarButtonHeight)];
    label.backgroundColor = [UIColor colorWithRed:200/255.0f green:198/255.0f blue:195/255.0f alpha:1.0f];
    return label;
}

-(UILabel*) createEmptyItem{
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 65, kMenuBarButtonHeight)];
    label.backgroundColor = [UIColor clearColor];
    return label;
}

-(UIButton*) createItemWithImageName:(NSString*) imageName action:(SEL) selector{
    
    UIImage * connectButtonImage = [UIImage imageNamed:imageName];
    UIButton *retButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 64, kMenuBarButtonHeight)];
    if ([imageName isEqualToString:@"vpmode.png"]) {
        [retButton setFrame:CGRectMake(0, 0, 330, kMenuBarVPLabelHeight)];
    }
    [retButton setImage:connectButtonImage forState:UIControlStateNormal];
    [retButton addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    
    return retButton;
}

-(void) loadTools{
    
    //load colors
    self.highlightedItemTintColor = [UIColor colorWithRed:240/255.0f green:240/255.0f blue:240/255.0f alpha:1.0f];
    self.hideiPhoneButton.backgroundColor = self.highlightedItemTintColor;
    self.unselectedTintColor = [UIColor whiteColor];
    
    //load dividers and empty items
    self.divider = [self createDivider];
    self.divider2 = [self createDivider];
    self.emptyItem1 = [self createEmptyItem];
    self.emptyItem2 = [self createEmptyItem];
    
    //buttons
    self.connectButton = [self createItemWithImageName:@"connect.png" action:@selector(connectPressed:)];
    self.duplicateButton = [self createItemWithImageName:@"duplicate.png" action:@selector(duplicatePressed:)];
    self.removeButton = [self createItemWithImageName:@"delete.png" action:@selector(removePressed:)];
    self.pushButton = [self createItemWithImageName:@"push.png" action:@selector(pushPressed:)];
    self.pushButton.backgroundColor = self.unselectedTintColor;
    self.lilypadButton = [self createItemWithImageName:@"lilypadmode.png" action:@selector(lilypadPressed:)];
    self.pinsModeButton = [self createItemWithImageName:@"pinsmode.png" action:@selector(pinsModePressed:)];
    self.hideiPhoneButton = [self createItemWithImageName:@"hideVPmode.png" action:@selector(hideiPhonePressed:)];
    self.hidePaletteButton = [self createItemWithImageName:@"palettePull.png" action:@selector(hidePalettePressed:)];
    self.vpmodeButton = [self createItemWithImageName:@"vpmode.png" action:nil];
    [self.vpmodeButton setUserInteractionEnabled:NO];
    
    self.playButton = [[UIBarButtonItem alloc]
                       initWithImage:[UIImage imageNamed:@"playicon.png"]
                       style:UIBarButtonItemStylePlain
                       target:self
                       action:@selector(startSimulation)];
    
    self.stopButton = [[UIBarButtonItem alloc]
                       initWithImage:[UIImage imageNamed:@"stopicon.png"]
                       style:UIBarButtonItemStylePlain
                       target:self
                       action:@selector(endSimulation)];
    
    //item arrays
    self.editingToolsWithVPmode = [NSArray arrayWithObjects: self.vpmodeButton, self.hideiPhoneButton, self.lilypadButton, self.divider, self.pushButton, self.removeButton, self.duplicateButton, self.connectButton, self.hidePaletteButton, nil];
    
    self.editingToolsWithoutVPmode = [NSArray arrayWithObjects: self.hideiPhoneButton, self.lilypadButton, self.divider, self.pushButton, self.removeButton, self.duplicateButton, self.connectButton, self.hidePaletteButton, nil];
    
    self.editingTools = self.editingToolsWithVPmode;
    
    self.simulatingTools = [[NSArray alloc ] init];
    
    self.lilypadTools = [NSArray arrayWithObjects: self.lilypadButton, self.divider, self.pushButton, self.removeButton, self.duplicateButton, self.connectButton, self.hidePaletteButton, nil];
    
    
    id c = [NSNotificationCenter defaultCenter];
    [c addObserver:self selector:@selector(handleEditableObjectAdded:) name:kNotificationObjectAdded object:nil];
    
}

#pragma mark -- Switch Edition <--> Simulation

-(void) checkSwitchToState:(TFEditorState) state{
    THProjectViewController * projectController = [THDirector sharedDirector].projectController;
    if(projectController.state == kAppStateEditor){
        THEditor * editor = (THEditor*) projectController.currentLayer;
        if(editor.state == state){
            editor.state = kEditorStateNormal;
        } else {
            editor.state = state;
        }
        [self updateEditingButtonsTint];
    }
}

#pragma mark -- UI setup

-(void) addEditionButtons{
    
    [self addButtonsToMenubar:self.editingTools];
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObject:self.playButton];
}

-(void) addLilypadButtons{
    
    [self addButtonsToMenubar:self.lilypadTools];
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObject:self.playButton];
}

-(void) addSimulationButtons{
    
    [self addButtonsToMenubar:self.simulatingTools];
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObject:self.stopButton];
}

-(void) addButtonsToMenubar:(NSArray *) tools {
    [[_menuButtonsView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    float totalWidth = [_menuButtonsView frame].size.width;
    float offset = 0;
    float xPos = 0;
    
    for (int i = 0; i < tools.count; i++) {
        CGRect itemFrame = [[tools objectAtIndex:i] frame];
        offset += itemFrame.size.width;
        xPos = totalWidth - offset;
        if ([[tools objectAtIndex:i] isEqual:self.hidePaletteButton]) {
            xPos = self.tabController.view.frame.origin.x + self.tabController.view.frame.size.width;
        }
        [[tools objectAtIndex:i] setFrame:CGRectMake(xPos,
                                                                 itemFrame.origin.y,
                                                                 itemFrame.size.width,
                                                                 itemFrame.size.height)];
        

        UIView * toolView = [tools objectAtIndex:i];
        [_menuButtonsView addSubview:toolView];
    }
}

#pragma mark -- UI state

-(void) handleEditableObjectAdded:(NSNotification*) notification{
    TFEditableObject * object = notification.object;
    
    if([object isKindOfClass:[THiPhoneEditableObject class]]){
        
        [self updateHideIphoneButtonTint];
    }
}

-(void) unselectAllEditingButtons{

    self.connectButton.backgroundColor = self.unselectedTintColor;
    self.duplicateButton.backgroundColor = self.unselectedTintColor;
    self.removeButton.backgroundColor = self.unselectedTintColor;
    self.hideiPhoneButton.backgroundColor = self.unselectedTintColor;
    self.lilypadButton.backgroundColor = self.unselectedTintColor;
}

-(void) updateEditingButtonsTint{
    THEditor * editor = (THEditor*) [THDirector sharedDirector].currentLayer;
    
    [self unselectAllEditingButtons];

    if(editor.state == kEditorStateConnect){
        self.connectButton.backgroundColor = self.highlightedItemTintColor;
    } else if(editor.state == kEditorStateDuplicate){
        self.duplicateButton.backgroundColor = self.highlightedItemTintColor;
    } else if(editor.state == kEditorStateDelete){
        self.removeButton.backgroundColor = self.highlightedItemTintColor;
    }
    
    [self updatePushButtonState];
    [self updateHideIphoneButtonTint];
    [self updateLilypadTint];
}

-(void) updatePushButtonState{
    //self.pushButton.enabled = YES;
    
    THDirector * director = [THDirector sharedDirector];
    self.pushButton.enabled = director.serverController.isConnected;
    [self.pushButton setNeedsDisplay];
}

-(void) updateHideIphoneButtonTint{
    
    THProject * project = (THProject*) [THDirector sharedDirector].currentProject;
    self.hideiPhoneButton.backgroundColor = (project.iPhone.visible ? self.highlightedItemTintColor : self.unselectedTintColor);
}

-(void) updateLilypadTint{
    
    THEditor * editor = (THEditor*) [THDirector sharedDirector].currentLayer;
    self.lilypadButton.backgroundColor = (editor.isLilypadMode ? self.highlightedItemTintColor : self.unselectedTintColor);
}

-(void) updatePinsModeItemTint{
    
    THSimulator * simulator = (THSimulator*) [THDirector sharedDirector].currentLayer;
    self.pinsModeButton.backgroundColor = (simulator.state == kSimulatorStatePins ? self.highlightedItemTintColor : self.unselectedTintColor);
}

#pragma mark -- Toolbar Buttons

- (void)connectPressed:(id)sender {
    [self checkSwitchToState:kEditorStateConnect];
}

- (void)duplicatePressed:(id)sender {
    [self checkSwitchToState:kEditorStateDuplicate];
}

- (void)removePressed:(id)sender {
    [self checkSwitchToState:kEditorStateDelete];
}

- (void) lilypadPressed:(id)sender {
    /*
    THCustomComponent * customComponent = [[THCustomComponent alloc] init];
    customComponent.name = @"my cool component";
    customComponent.code = @"function myFunction(sideHops){var filter = RCFilter.new();var filteredSignal = filter.filter(sideHops,60,5); return 5;} myFunction(data);";
    
    [[THDirector sharedDirector] didFinishReceivingObject:customComponent];
    */
    
    
    THEditor * editor = (THEditor*) [THDirector sharedDirector].currentLayer;
    if(editor.isLilypadMode){
        [editor stopLilypadMode];
        
        [self checkSwitchToState:kEditorStateNormal];
        self.editingTools = self.editingToolsWithVPmode;
        [self addEditionButtons];
        
    } else {
        [editor startLilypadMode];
        
        [self addLilypadButtons];
    }
    
    [self.tabController showTab:0];
    
    [self updateLilypadTint];
}

- (void) pinsModePressed:(id)sender {
    THSimulator * simulator = (THSimulator*) [THDirector sharedDirector].currentLayer;
    
    if(simulator.state == kSimulatorStateNormal){
        [simulator addPinsController];
    } else {
        [simulator removePinsController];
    }
    
    [self updatePinsModeItemTint];
}

- (void) pushPressed:(id)sender {
    THServerController * serverController = [THDirector sharedDirector].serverController;
    THProject * project = (THProject*) [THDirector sharedDirector].currentProject;
    [serverController pushProjectToAllClients:project];
}

- (void) hideiPhonePressed:(id)sender {
    
    THProject * project = (THProject*) [THDirector sharedDirector].currentProject;
    if (project.iPhone.visible) {
        self.editingTools = self.editingToolsWithoutVPmode;
    } else {
        self.editingTools = self.editingToolsWithVPmode;
    }
    [self addEditionButtons];
    project.iPhone.visible = !project.iPhone.visible;
    [self updateHideIphoneButtonTint];
    
    THEditor * editor = (THEditor*) [THDirector sharedDirector].currentLayer;
    if([editor.currentObject isKindOfClass:[THViewEditableObject class]] || [editor.currentObject isKindOfClass:[THiPhoneEditableObject class]]){
        [self.tabController showTab:0];
    }
    
    [editor handleIphoneVisibilityChangedTo:project.iPhone.visible];
    
}

- (void) hidePalettePressed:(id)sender {
    CGRect paletteFrame = self.tabController.view.frame;
    CGRect imageViewFrame = self.hidePaletteButton.frame;
    
    if(paletteFrame.origin.x < 0)
    {
        paletteFrame.origin.x = 0;
        imageViewFrame.origin.x = paletteFrame.size.width;
    }
    else
    {
        paletteFrame.origin.x = -paletteFrame.size.width;
        imageViewFrame.origin.x = 0;
    }
    
    self.tabController.view.frame = paletteFrame;
    self.hidePaletteButton.frame = imageViewFrame;
}

//zoom slider
-(void)sliderAction:(id)sender {
    THEditor * editor = (THEditor*) self.currentLayer;
    float newScale = [(UISlider *)sender value];
    
    editor.zoomLevel = newScale;
}

-(void) updateEditorZoomSlider:(NSNotification*) notification{
    THEditor * editor = (THEditor*) self.currentLayer;
    self.zoomSlider.value = editor.zoomLevel;
}

-(NSString*) description{
    return @"ProjectController";
}

-(void) dealloc{
    if ([@"YES" isEqualToString: [[[NSProcessInfo processInfo] environment] objectForKey:@"printUIDeallocs"]]) {
        NSLog(@"deallocing %@",self);
    }
}

@end
