// YTExtrasUI.xm - uYouEnhanced Extras
// UI extras that complement the existing hide-toggles (which already cover
// hiding nav-bar buttons, player elements, and Shorts elements — see the
// kHide* family in uYouPlus.h). This file adds the *customization* side:
//   - Tab reorder: long-press + drag on the pivot bar reorders tabs
//   - Custom player actions: long-press a player button to copy title/URL
//   - Custom Shorts actions: long-press in Shorts to copy link / open in
//     the main app

#import "uYouPlus.h"

static BOOL tabReorderEnabled() {
    return IS_ENABLED(kTabReorderMode);
}

static BOOL customPlayerActionsEnabled() {
    return IS_ENABLED(kCustomPlayerActions);
}

static BOOL customShortsActionsEnabled() {
    return IS_ENABLED(kCustomShortsActions);
}

%group gTabReorder

// Long-press on a pivot bar button pops a move-left / move-right menu.
// (Full drag-reorder requires private gesture plumbing; explicit move
// actions achieve the same result reliably across YouTube versions.)
%hook YTPivotBarView
- (void)layoutSubviews {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        for (UIView *sub in self.subviews) {
            if ([sub isKindOfClass:UIButton.class]) {
                UILongPressGestureRecognizer *lp =
                    [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tabMoveLongPress:)];
                [sub addGestureRecognizer:lp];
            }
        }
    });
}
%new
- (void)tabMoveLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIView *tabButton = gesture.view;
    UIView *parent = tabButton.superview;
    if (![parent isKindOfClass:UIStackView.class]) return;
    UIStackView *stack = (UIStackView *)parent;
    NSUInteger idx = [stack.arrangedSubviews indexOfObject:tabButton];
    if (idx == NSNotFound) return;

    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"Reorder Tab"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    if (idx > 0) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Move Left" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [stack removeArrangedSubview:tabButton];
            [stack insertArrangedSubview:tabButton atIndex:idx - 1];
        }]];
    }
    if (idx < stack.arrangedSubviews.count - 1) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Move Right" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [stack removeArrangedSubview:tabButton];
            [stack insertArrangedSubview:tabButton atIndex:idx + 1];
        }]];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *top = tabButton.window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    menu.popoverPresentationController.sourceView = tabButton;
    menu.popoverPresentationController.sourceRect = tabButton.bounds;
    [top presentViewController:menu animated:YES completion:nil];
}
%end

%end // gTabReorder

%group gCustomPlayerActions

// Long-press the video title area for quick copy actions
%hook YTMainAppVideoPlayerOverlayViewController
- (void)viewDidLoad {
    %orig;
    if (!customPlayerActionsEnabled()) return;
    UIView *titleView = nil;
    for (UIView *sub in self.view.subviews) {
        if ([sub isKindOfClass:UIView.class] && sub.gestureRecognizers.count == 0) {
            titleView = sub;
        }
    }
    if (!titleView) return;
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(playerCopyLongPress:)];
    [titleView addGestureRecognizer:lp];
}
%new
- (void)playerCopyLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    NSString *videoId = nil;
    @try {
        id playerViewController = [%c(YTPlayerViewController) activePlayerController];
        videoId = [playerViewController valueForKeyPath:@"currentVideoMetadata.videoId"];
    } @catch (NSException *e) {}
    if (!videoId) return;

    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"Player Actions"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Copy Video ID" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = videoId;
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Copy Video URL" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string =
            [NSString stringWithFormat:@"https://youtu.be/%@", videoId];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Copy Embed URL" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string =
            [NSString stringWithFormat:@"https://www.youtube.com/embed/%@", videoId];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *top = gesture.view.window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    menu.popoverPresentationController.sourceView = gesture.view;
    menu.popoverPresentationController.sourceRect = gesture.view.bounds;
    [top presentViewController:menu animated:YES completion:nil];
}
%end

%end // gCustomPlayerActions

%group gCustomShortsActions

// Long-press anywhere on the Shorts player for quick actions
%hook YTShortsPlayerViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!customShortsActionsEnabled()) return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UILongPressGestureRecognizer *lp =
            [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(shortsCopyLongPress:)];
        [self.view addGestureRecognizer:lp];
    });
}
%new
- (void)shortsCopyLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    NSString *shortsId = nil;
    @try {
        // Verified: YTReelPlayerViewController (YTShortsPlayerViewController's
        // parent) declares - (NSString *)videoId directly.
        if ([self respondsToSelector:@selector(videoId)]) {
            shortsId = [self performSelector:@selector(videoId)];
        }
    } @catch (NSException *e) {
        // never crash the Shorts player over a copy action
        return;
    }
    if (![shortsId isKindOfClass:NSString.class] || shortsId.length == 0) return;

    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"Shorts Actions"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Copy Shorts ID" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = shortsId;
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Copy Shorts URL" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string =
            [NSString stringWithFormat:@"https://youtube.com/shorts/%@", shortsId];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Open in Main App" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *url = [NSString stringWithFormat:@"youtube://watch?v=%@", shortsId];
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *top = gesture.view.window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    menu.popoverPresentationController.sourceView = gesture.view;
    menu.popoverPresentationController.sourceRect = gesture.view.bounds;
    [top presentViewController:menu animated:YES completion:nil];
}
%end

%end // gCustomShortsActions

%ctor {
    if (tabReorderEnabled()) {
        %init(gTabReorder);
    }
    if (customPlayerActionsEnabled()) {
        %init(gCustomPlayerActions);
    }
    if (customShortsActionsEnabled()) {
        %init(gCustomShortsActions);
    }
}
