//
//  AppDelegate.m
//  KFURLBar
//
//  Copyright (c) 2013 Rico Becker, KF Interactive
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//


#import "AppDelegate.h"
#import "KFURLBar.h"
#import "KFToolbar.h"
#import "KFWebKitProgressController.h"
#import "DsMusicPlayer.h"
#import <WebKit/WebKit.h>

@interface AppDelegate () <KFURLBarDelegate, NSWindowDelegate, KFWebKitProgressDelegate>


@property (weak) IBOutlet KFURLBar *urlBar;

@property (weak) IBOutlet WebView *webView;
@property (weak) IBOutlet KFToolbar *toolbar;

@property (weak) IBOutlet NSTextField *remainsLabel;

@property (nonatomic) float progress;

@property (nonatomic) NSString *tmpFileUrl;


@property (nonatomic) NSString *mainUrl;

@property (nonatomic) NSTimer *oneHourTimer;

@property (nonatomic) int elapsed;
@property (nonatomic) int remains;

@end


@implementation AppDelegate
int oneHour;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    oneHour = 60*60;
    _mainUrl = @"https://www.duosuccess.com";
    [_remainsLabel setStringValue:@""];
    self.window.delegate = self;

    [_webView setPolicyDelegate:self];
    self.webView.frameLoadDelegate = self;
    self.webView.resourceLoadDelegate = self;
    _tmpFileUrl = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)objectAtIndex:0]stringByAppendingPathComponent:@"/.duosuccess_browser.mid"];
    
    
    self.urlBar.delegate = self;
    self.urlBar.addressString = _mainUrl;
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:_mainUrl ]];
    [self.webView.mainFrame loadRequest:req];
    NSButton *reloadButton = [[NSButton alloc] init];
    [reloadButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [reloadButton setBezelStyle:NSInlineBezelStyle];
    [reloadButton setImage:[NSImage imageNamed:@"NSRefreshTemplate"]];
    [reloadButton setTarget:self];
    [reloadButton setAction:@selector(reloadURL:)];
    self.urlBar.leftItems = @[reloadButton];
    
    KFToolbarItem *backItem = [KFToolbarItem toolbarItemWithIcon:[NSImage imageNamed:NSImageNameLeftFacingTriangleTemplate] tag:0];
    backItem.toolTip = @"Back";
    
    KFToolbarItem *fwdItem = [KFToolbarItem toolbarItemWithIcon:[NSImage imageNamed:NSImageNameRightFacingTriangleTemplate] tag:1];
    fwdItem.toolTip = @"Forward";
    
    
    self.toolbar.leftItems = @[backItem, fwdItem];
    
    
    [self.toolbar setItemSelectionHandler:^(KFToolbarItemSelectionType selectionType, KFToolbarItem *toolbarItem, NSUInteger tag)
     {
         switch (tag)
         {
             case 0:
                 [self.webView goBack];
                 break;
                 
             case 1:
                 [self.webView goForward];
                 break;
         }
         
     }];
    
    
}



- (void)reloadURL:(id)sender
{
    [[self.webView mainFrame] reload];
}




- (void)updateProgress
{
    self.urlBar.progressPhase = KFProgressPhaseDownloading;
    self.progress += .005;
    self.urlBar.progress = self.progress;
    if (self.progress < 1.0)
    {
        [self performSelector:@selector(updateProgress) withObject:nil afterDelay:.02f];
    }
    else
    {
        self.urlBar.progressPhase = KFProgressPhaseNone;
    }
}


#pragma mark - KFURLBarDelegate Methods


- (void)urlBar:(KFURLBar *)urlBar didRequestURL:(NSURL *)url
{
    [[self.webView mainFrame] loadRequest:[[NSURLRequest alloc] initWithURL:url]];
    self.urlBar.progressPhase = KFProgressPhasePending;
}


- (BOOL)urlBar:(KFURLBar *)urlBar isValidRequestStringValue:(NSString *)requestString
{
    NSString *urlRegEx = @"(ftp|http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+";
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", urlRegEx];
    return [urlTest evaluateWithObject:requestString];
}


#pragma mark - NSWindowDelegate Methods


- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect
{
    rect.origin.y -= NSHeight(self.urlBar.frame);
    return rect;
}


#pragma mark WebKitProgressDelegate Methods


- (void)webKitProgressDidChangeFinishedCount:(NSInteger)finishedCount ofTotalCount:(NSInteger)totalCount
{
    self.urlBar.progressPhase = KFProgressPhaseDownloading;
    self.urlBar.progress = (float)finishedCount / (float)totalCount;
    
    if (totalCount == finishedCount)
    {
        double delayInSeconds = 1.0;
        
        __weak typeof(self) weakSelf = self;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
                       {
                           weakSelf.urlBar.progressPhase = KFProgressPhaseNone;
                       });
    }
}

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id < WebPolicyDecisionListener >)listener
{
    [self.webView.mainFrame loadRequest:request];
    [listener ignore];
}


- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame{
    self.urlBar.addressString = self.webView.mainFrameURL;
    [self stopMusic];
}

-(NSURLRequest*) webView:(WebView*)webview resource:(id)sender willSendRequest:(NSURLRequest*)request redirectResponse:(NSURLResponse*)redirectresponse fromDataSource:(WebDataSource*)dataSource {
    
    NSString *strUrl = request.URL.absoluteString;
    if([strUrl rangeOfString:@"duosuccess"].location != NSNotFound){
        if([strUrl rangeOfString:@"https"].location != 0 ){
            NSString *httpsUrl = [strUrl stringByReplacingOccurrencesOfString:@"http" withString:@"https"];
            NSLog(@"Url is changed to https %@", httpsUrl);
            self.urlBar.addressString = httpsUrl;
            return [NSURLRequest requestWithURL:[NSURL URLWithString:httpsUrl]];
        }
    }
    
    return request;
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame{
    NSLog(@"did finish load for frame.");
    [self.remainsLabel setStringValue:@""];
    NSString *strExtractMidJs = @"document.querySelector('embed').src";
    NSString *strRemoveMidJs = @"document.querySelector('embed').Stop()";
    
    NSString *midiUrl = [self.webView stringByEvaluatingJavaScriptFromString:strExtractMidJs];
    [self.webView stringByEvaluatingJavaScriptFromString:strRemoveMidJs];
    
    _elapsed = 0;
    _remains = oneHour;
    if(midiUrl && ![midiUrl isEqualToString:@""]){
        _oneHourTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                         target:self
                                                       selector:@selector(handleOneHourTimer)
                                                       userInfo:nil
                                                        repeats:YES];
    }
    [NSThread detachNewThreadSelector:@selector(startTheBackgroundMusic:) toTarget:self withObject:midiUrl];
    
    
}


-(void)startTheBackgroundMusic: (NSString*)midiUrl{
    if(midiUrl && ![midiUrl isEqualToString:@""]){
        NSLog(@"midi url found %@.", midiUrl);
        
        NSData *midiContents = [NSData dataWithContentsOfURL: [NSURL URLWithString:midiUrl]];
        NSLog(@"Saving to %@.", _tmpFileUrl);
        [midiContents writeToFile:_tmpFileUrl atomically:true ];
        DsMusicPlayer *mp = [DsMusicPlayer sharedInstance];
        
        [mp playMedia:(_tmpFileUrl)];
        
    }
    
}

-(void) stopMusic{
    [[DsMusicPlayer sharedInstance] stopMedia];
    [self clearTmpFile];
    [_oneHourTimer invalidate];
}
- (void)windowWillClose:(NSNotification *)notification{
    [self stopMusic];
}
-(void)clearTmpFile {
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath: _tmpFileUrl] error:&error];
    if(error){
//        NSLog(@"Failed to remove %@.", error.description);
    }else{
        
        NSLog(@"Tmp file has been removed.");
    }
}

-(void) handleOneHourTimer{
    self.elapsed++;
    self.remains--;
    if(self.remains<0){
        self.remains = 0;
    }
    if(self.elapsed >= oneHour){
        NSLog(@"1 hour arrived, calling music stop.");
        [self stopMusic];
        
    }else{
        long remainsMins = _remains/60;
        long remainsSecs = _remains-(remainsMins*60);
        NSString *remainsDisplay = [NSString stringWithFormat:@"%lu:%02lu", remainsMins, remainsSecs];
        NSLog(@"remains %@", remainsDisplay);
        [_remainsLabel setStringValue: remainsDisplay];
    }
    
    
}



@end
