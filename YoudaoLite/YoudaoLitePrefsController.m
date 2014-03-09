//
//  YoudaoLitePrefsController.m
//  YoudaoLite
//
//  Created by hewig on 1/25/14.
//  Copyright (c) 2014 kernelpanic.im. All rights reserved.
//

#import "YoudaoLitePrefsController.h"
#import "MASShortcutView+UserDefaults.h"
#import "MASShortcutView.h"

@interface YoudaoLitePrefsController ()

@property (nonatomic,weak) IBOutlet NSToolbarItem* shortcutItem;
@property (nonatomic,weak) IBOutlet MASShortcutView* shortcutView;

@end

@implementation YoudaoLitePrefsController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.shortcutView.associatedUserDefaultsKey = @"YoudaoLiteShowHideShortcut";
}

@end
