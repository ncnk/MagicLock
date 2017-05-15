//
//  AppDelegate.m
//  MagicLock_MacOS
//
//  Created by 程启航 on 2017/5/8.
//  Copyright © 2017年 NcnkCheng. All rights reserved.
//

#import "AppDelegate.h"
#import "NCPeripheralManager.h"
#import "NCMacLockManager.h"

@interface AppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *statusMenu;
@property (nonatomic, strong) NSTextField *textField;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application

    [[NSApplication sharedApplication] setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self setup];
    if ([NCMacLockConfig globalConfig].password.length) {
        [[NCPeripheralManager sharedInstance] startAdvertising];
    }
    else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSMenuItem *item = [self.statusMenu itemWithTag:10000];
            item.title = @"程序未启动，需要设置密码";
            [self setPasswordAction:nil];
        });
    }
}

- (void)setup {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.image = [NSImage imageNamed:@"Lock Portrait"];
    
    self.statusMenu = [NSMenu new];
    self.statusItem.menu = self.statusMenu;
    
    NSMenuItem *titleItem = [[NSMenuItem alloc] init];
    titleItem.enabled = NO;
    titleItem.tag = 10000;
    titleItem.title = @"未连接";
    [[NCPeripheralManager sharedInstance] addObserver:self forKeyPath:@"phoneName" options:NSKeyValueObservingOptionNew context:nil];
    [[NCPeripheralManager sharedInstance] addObserver:self forKeyPath:@"realDistance" options:NSKeyValueObservingOptionNew context:nil];
    [self.statusMenu addItem:titleItem];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *menuItem1 = [[NSMenuItem alloc] initWithTitle:@"离开时进入睡眠" action:@selector(sleepItemAction:) keyEquivalent:@""];
    menuItem1.target = self;
    menuItem1.tag = 10001;
    [self.statusMenu addItem:menuItem1];
    
    NSMenuItem *menuItem2 = [[NSMenuItem alloc] initWithTitle:@"离开时显示屏保" action:@selector(screensaverItemAction:) keyEquivalent:@""];
    menuItem2.target = self;
    menuItem2.tag = 10002;
    [self.statusMenu addItem:menuItem2];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *passwordItem = [[NSMenuItem alloc] initWithTitle:@"设置密码" action:@selector(setPasswordAction:) keyEquivalent:@""];
    passwordItem.target = self;
    passwordItem.tag = 10003;
    [self.statusMenu addItem:passwordItem];
    
    NSMenuItem *distanceItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"设置锁定距离（%zd米）", [NCPeripheralManager sharedInstance].lockDistance] action:@selector(setDistanceAction:) keyEquivalent:@""];
    distanceItem.target = self;
    distanceItem.tag = 10004;
    [self.statusMenu addItem:distanceItem];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"退出" action:@selector(quitItemAction:) keyEquivalent:@""];
    quitItem.target = self;
    [self.statusMenu addItem:quitItem];

    [self refreshItemCheckmarkState];
}

#pragma mark -

- (void)setPasswordAction:(NSMenuItem *)sender {

    NSString *inputString = [self inputWithMessageText:@"输入密码"
                                       informativeText:@"请输入您计算机的管理密码"
                                     placeholderString:@"密码不能为空"
                                          defaultValue:[NCMacLockConfig globalConfig].password];
    if (inputString.length) {
        [NCMacLockConfig globalConfig].password = inputString;
        NSMenuItem *item = [self.statusMenu itemWithTag:10000];
        item.title = @"未连接";
        [[NCPeripheralManager sharedInstance] startAdvertising];
    }
}

- (void)setDistanceAction:(NSMenuItem *)sender {
    NSString *inputString = [self inputWithMessageText:@"输入锁定距离"
                                       informativeText:@"请输入超出多少范围时锁定您的计算机(2-10的整数)"
                                     placeholderString:@"2-10的整数，单位（米）"
                                          defaultValue:[NSString stringWithFormat:@"%zd", [NCPeripheralManager sharedInstance].lockDistance]];
    if (inputString.length) {
        NSInteger distance = [inputString integerValue];
        [NCPeripheralManager sharedInstance].lockDistance = distance;
        NSMenuItem *item = [self.statusMenu itemWithTag:10004];
        item.title = [NSString stringWithFormat:@"设置锁定距离（%zd米）", [NCPeripheralManager sharedInstance].lockDistance];
    }
}

- (void)sleepItemAction:(NSMenuItem *)sender {
    [NCMacLockConfig globalConfig].lockType = NCMacLockTypeSleep;
    [self refreshItemCheckmarkState];
}

- (void)screensaverItemAction:(NSMenuItem *)sender {
    [NCMacLockConfig globalConfig].lockType = NCMacLockTypeScreensaver;
    [self refreshItemCheckmarkState];
}

- (void)quitItemAction:(NSMenuItem *)sender {
    exit(0);
}

- (void)refreshItemCheckmarkState {
    for (NSMenuItem *item in self.statusMenu.itemArray) {
        if (item.tag == 10001) {
            item.state = [NCMacLockConfig globalConfig].lockType == NCMacLockTypeSleep ? 1 : 0;
        }
        else if (item.tag == 10002) {
            item.state = [NCMacLockConfig globalConfig].lockType == NCMacLockTypeScreensaver ? 1 : 0;
        }
    }
}

- (NSString *)inputWithMessageText:(NSString *)messageText
                   informativeText:(NSString *)informativeText
                 placeholderString:(NSString *)placeholderString
                      defaultValue:(NSString *)defaultValue {
    NSAlert *alert = [NSAlert new];
    alert.messageText = messageText;
    alert.informativeText = informativeText;
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    
    self.textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 24)];
    [self.textField setStringValue:defaultValue];
    [alert setAccessoryView:self.textField];
    self.textField.placeholderString = placeholderString;
    [[NSApplication sharedApplication] becomeFirstResponder];
    
    NSInteger button = [alert runModal];
    if (button == NSAlertFirstButtonReturn) {
        [self.textField validateEditing];
        if (!self.textField.stringValue.length) {
            return [self inputWithMessageText:messageText
                              informativeText:informativeText
                            placeholderString:placeholderString
                                 defaultValue:defaultValue];
        }
        else {
            return [self.textField stringValue];
        }
    } else if (button == NSAlertSecondButtonReturn) {
        return nil;
    } else {
        return nil;
    }
}


#pragma mark - 

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if([keyPath isEqualToString:@"phoneName"]) {
        NSMenuItem *item = [self.statusMenu itemWithTag:10000];
        BOOL hasConnect = ((NCPeripheralManager *)object).phoneName != nil;
        item.title = hasConnect?[NSString stringWithFormat:@"%@ %@",((NCPeripheralManager *)object).phoneName, ((NCPeripheralManager *)object).realDistance]:@"未连接";
    }
    else if ([keyPath isEqualToString:@"realDistance"]) {
        NSMenuItem *item = [self.statusMenu itemWithTag:10000];
        BOOL hasConnect = ((NCPeripheralManager *)object).phoneName != nil;
        item.title = hasConnect?[NSString stringWithFormat:@"%@ %@",((NCPeripheralManager *)object).phoneName, ((NCPeripheralManager *)object).realDistance]:@"未连接";
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
