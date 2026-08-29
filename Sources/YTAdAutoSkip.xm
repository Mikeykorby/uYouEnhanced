// YTAdAutoSkip.xm - uYouEnhanced Extras
// Auto-skip ads: when a skippable ad is playing, find the Skip button and
// press it automatically after a short, configurable delay.
//
// Strategy (no private ad-class names guessed): the skip button is exposed
// by YouTube as an accessibility element identified by
//   "id.video.skippable_ad.skip_button"  (modern 19.x-21.x builds)
// with a localized label ("Skip", "Skip Ad", "Überspringen", ...).
// We hook the generic overlay view lifecycle and tap the button on the
// main thread once it lands in the window hierarchy.

#import "uYouPlus.h"

#define kSkipDelayKey @"adAutoSkipDelay"
// Legacy fallback identifiers seen across YouTube versions
static NSArray *SkipButtonIDs = nil;

static BOOL adAutoSkipEnabled() {
    return IS_ENABLED(kAdAutoSkip);
}

static float adAutoSkipDelay() {
    float d = [[NSUserDefaults standardUserDefaults] floatForKey:kSkipDelayKey];
    return (d > 0.0f && d <= 30.0f) ? d : 0.0f;
}

// Recursively search for the skip button starting from a root view
static UIView *findSkipButton(UIView *root) {
    if (!root) return nil;
    NSString *aid = root.accessibilityIdentifier;
    if ([aid isEqualToString:@"id.video.skippable_ad.skip_button"]
        || [aid isEqualToString:@"skip_button.ad.video"])
        return root;
    // Legacy: label-based fallback (English + common short form)
    NSString *label = root.accessibilityLabel;
    if (([label isEqualToString:@"Skip"] || [label isEqualToString:@"Skip Ad"])
        && [root isKindOfClass:%c(YTAdvancedAccessibilityButton)])
        return root;
    for (UIView *sub in root.subviews) {
        UIView *found = findSkipButton(sub);
        if (found) return found;
    }
    return nil;
}

%group gAdAutoSkip

// Buttons on the ad overlay live in _ASDisplayView / UIButton hierarchies
// that are attached to the player overlay; didMoveToWindow fires when the
// skip button is added on screen.
%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    if (!adAutoSkipEnabled()) return;
    if (!self.window) return;
    UIView *skipButton = findSkipButton(self);
    if (!skipButton) return;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(adAutoSkipDelay() * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            // Re-check the button is still on screen and press it
            if (skipButton.window && !skipButton.hidden && skipButton.alpha > 0.01) {
                [skipButton sendActionsForControlEvents:UIControlEventTouchUpInside];
                // Fallback for non-control views: walk up to a control
                UIView *ctrl = skipButton;
                while (ctrl && ![ctrl isKindOfClass:UIControl.class]) ctrl = ctrl.superview;
                if (ctrl) [(UIControl *)ctrl sendActionsForControlEvents:UIControlEventTouchUpInside];
            }
        });
}
%end

%hook YTAdOverlayViewController
- (void)viewDidLoad {
    %orig;
    if (!adAutoSkipEnabled()) return;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)((adAutoSkipDelay() + 0.5) * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            UIView *skip = findSkipButton(self.view);
            if (skip) {
                UIView *ctrl = skip;
                while (ctrl && ![ctrl isKindOfClass:UIControl.class]) ctrl = ctrl.superview;
                if (ctrl) [(UIControl *)ctrl sendActionsForControlEvents:UIControlEventTouchUpInside];
            }
        });
}
%end

%end // gAdAutoSkip

%ctor {
    SkipButtonIDs = @[
        @"id.video.skippable_ad.skip_button",
        @"skip_button.ad.video",
    ];
    if (adAutoSkipEnabled()) {
        %init(gAdAutoSkip);
    }
}
