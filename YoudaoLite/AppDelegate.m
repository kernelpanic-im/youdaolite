//
//  AppDelegate.m
//  YoudaoLite
//
//  Created by hewig on 1/25/14.
//  Copyright (c) 2014 kernelpanic.im. All rights reserved.
//

#import "AppDelegate.h"
#import "YoudaoLitePrefsController.h"
#import "MASShortcut+Monitoring.h"
#import "MASShortcut+UserDefaults.h"
#import "MASShortcut.h"
#import "MAAttachedWindow.h"

#import <Crashlytics/Crashlytics.h>

NSString* const kYoudaoKeyFrom  = @"kernelpanic";
NSString* const kYoudaokey      = @"482091942";


@interface AppDelegate()

@property (nonatomic, weak) IBOutlet NSTextField *queryField;
@property (nonatomic, strong) NSOperationQueue* networkQueue;
@property (nonatomic, strong) YoudaoLitePrefsController* prefController;
@property (nonatomic, assign) NSRect originWindowFrame;
@property (nonatomic, assign) NSRect originQueryFrame;
@property (nonatomic, assign) BOOL isDisplaying;
@property (nonatomic, retain) MAAttachedWindow* attachedWindow;

@end

@implementation AppDelegate

-(void)awakeFromNib
{
    self.prefController = [[YoudaoLitePrefsController alloc] initWithWindowNibName:@"YoudaoLitePrefsController"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    NSDictionary* dict = [[NSBundle mainBundle] localizedInfoDictionary];
    
    self.window.title = dict[@"CFBundleDisplayName"];

    self.originWindowFrame = self.window.frame;
    self.originQueryFrame = self.queryField.frame;
    
    self.networkQueue = [[NSOperationQueue alloc] init];
    self.networkQueue.name = @"im.kernelpanic.youdaolite.network";
    self.networkQueue.maxConcurrentOperationCount = 10;
    
    [MASShortcut registerGlobalShortcutWithUserDefaultsKey:@"YoudaoLiteShowHideShortcut" handler:^{
        [self showHideMainWindow];
    }];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
        selector:@selector(controlTextDidChange:)
            name:NSControlTextDidChangeNotification
            object:self.queryField];
    
    [Crashlytics startWithAPIKey:@"00294b074c27a6569db329a72df442fbff108a8c"];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
    [self.window makeKeyAndOrderFront:self];
    return YES;
}

-(void)controlTextDidChange:(NSNotification *)notification
{
    if (notification.object == self.queryField && [self.queryField.stringValue isEqualToString:@""]){
        if (self.attachedWindow) {
            [self.attachedWindow orderOut:self];
            self.attachedWindow = nil;
        }
    }
}

-(void)queryYoudao:(NSString*)word
{
    NSString* wordEncoding = [word stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSString* queryString = [NSString stringWithFormat:@"http://fanyi.youdao.com/openapi.do?keyfrom=%@&key=%@&type=data&doctype=json&version=1.1&q=%@", kYoudaoKeyFrom, kYoudaokey, wordEncoding];
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:queryString]];
    [NSURLConnection sendAsynchronousRequest:request queue:self.networkQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        
        if (connectionError) {
            [self handleError:connectionError];
            return;
        }
        
        NSHTTPURLResponse* httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse*)response;
        }
        if (httpResponse) {
            if (httpResponse.statusCode == 200) {
                NSError* error = nil;
                NSDictionary* responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (!error) {
                    //NSLog(@"%@",responseDict);
                    NSArray* explains = responseDict[@"basic"][@"explains"];
                    if (explains) {
                        [self showQueryResult:explains];
                    } else if(responseDict[@"web"]){
                        NSArray* webResults = responseDict[@"web"];
                        NSMutableArray* results = [NSMutableArray new];
                        for (NSDictionary* result in webResults){
                            NSArray* valueArray = result[@"value"];
                            [results addObject:[NSString stringWithFormat:@"%@:%@", result[@"key"], [valueArray componentsJoinedByString:@" "]]];
                        }
                        [self showQueryResult:results];
                    } else if(responseDict[@"translation"]){
                        NSArray* translation = responseDict[@"translation"];
                        [self showQueryResult:translation];
                    } else{
                        [self showErrorAlert:@"No valid results"];
                    }
                    self.window.title = [NSString stringWithFormat:@"Lookup ==> %@", word];
                }else{
                    [self handleError:error];
                }
            }
        }
    }];

}

-(void)showQueryResult:(NSArray*)results
{
    if(results.count == 0){
        return;
    }
    
    NSPoint buttonPoint = NSMakePoint(NSMidX([self.queryField frame]),
                                      NSMidY([self.queryField frame]));
    CGFloat frameHeight = 110.f;
    if (results.count > 4) {
        frameHeight = 220.f;
    }
    
    NSView* view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 368, frameHeight)];
    NSTextField* label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 368, frameHeight)];
    
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:YES];
    [label setStringValue:[results componentsJoinedByString:@"\n"]];
    [label setFont:[NSFont systemFontOfSize:14]];
    [label setTextColor:[NSColor whiteColor]];
    
    [view addSubview:label];
    
    self.attachedWindow = [[MAAttachedWindow alloc] initWithView:view
                                            attachedToPoint:buttonPoint
                                                   inWindow:[self.queryField window]
                                                     onSide:1
                                                 atDistance:25.f];
    [self.attachedWindow setHasArrow:NO];
    [self.attachedWindow setArrowBaseWidth:1.f];
    [self.attachedWindow setArrowHeight:1.f];
    [[self.queryField window] addChildWindow:self.attachedWindow ordered:NSWindowAbove];
}

-(void)showQueryResultAsSheet:(NSArray*)results
{
    self.isDisplaying = YES;
    NSAlert* alert = [NSAlert alertWithMessageText:self.queryField.stringValue defaultButton:@"close" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",[results componentsJoinedByString:@"\n"]];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        self.isDisplaying = NO;
    }];
    
    [[NSApp mainWindow] makeKeyAndOrderFront:self];
}

-(void)showQueryResultInside:(NSArray*)results
{
    self.queryField.stringValue = [results componentsJoinedByString:@"\n"];
    [self resizeWindowByLine:results.count];
}

-(void)resizeWindowByLine:(NSUInteger)count
{
    NSRect windowFrame = self.window.frame;
    NSRect queryFrame = self.queryField.frame;
    
    if (count<=2) {
        windowFrame.size = self.originWindowFrame.size;
        queryFrame.size = self.originQueryFrame.size;
        [self.window setFrame:windowFrame display:YES animate:YES];
        [self.queryField setFrame:queryFrame];
    } else{

        int times = ceil(count/2.f);
        
        windowFrame.size.height = times * self.originWindowFrame.size.height;
        queryFrame.size.height = times* self.originQueryFrame.size.height;

        [self.window setFrame:windowFrame display:YES animate:YES];
        [self.queryField setFrame:queryFrame];
    }
}


-(void)showErrorAlert:(NSString*)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert* alert = [NSAlert alertWithMessageText:@"YoudaoLite" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",message];
        [alert runModal];
    });
}
-(void)handleError:(NSError*)error
{
    NSLog(@"%@",[error description]);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert* alert = [NSAlert alertWithMessageText:@"YoudaoLite"
                                         defaultButton:@"OK"
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"%@",[error description]];
        [alert runModal];
    });
}

-(void)showHideMainWindow
{
    if (!self.window.isVisible || !self.window.isKeyWindow) {
        [self.window makeKeyAndOrderFront:self];
        [NSApp activateIgnoringOtherApps:YES];
        NSLog(@"==> show youdaolite window");
    } else{
        [self.window orderOut:self];
        NSLog(@"==> hide youdaolite window");
    }
}

#pragma mark IBActions

- (IBAction)enterKeyPressed:(id)sender
{
    if (self.isDisplaying || [self.queryField.stringValue isEqualToString:@""]) {
        return;
    }
    
    if (self.attachedWindow) {
        [self.attachedWindow orderOut:self];
        self.attachedWindow = nil;
    }
    
    [self queryYoudao:self.queryField.stringValue];
}

-(IBAction)settingClicked:(id)sender
{
    [self.prefController showWindow:sender];
}

@end
