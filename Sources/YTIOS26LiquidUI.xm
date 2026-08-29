// YTIOS26LiquidUI.xm - uYouEnhanced Extras
// iOS 26 "Liquid Glass" integration: when enabled, restyles YouTube's
// overlay chrome (player action buttons, tab/pivot bar, chips bar) with
// translucent material, continuous-corner rounded containers, and softer
// shadows so controls read as integrated glass rather than opaque chips.
//
// Availability: every restyle is guarded by @available(iOS 26.0, *) — on
// older iOS the hook compiles in but does nothing, leaving stock styling.
// The toggle (kIOS26LiquidUI) gates everything at runtime.

#import "uYouPlus.h"
#import <UIKit/UIKit.h>

static BOOL liquidUIEnabled() {
    return IS_ENABLED(kIOS26LiquidUI);
}

static BOOL liquidUIActive() {
    return liquidUIEnabled() && @available(iOS 26.0, *);
}

%group gIOS26LiquidUI

// Shared material builder: an iOS 26 glass-like visual effect view with
// continuous corners. Falls back gracefully if the class is missing.
static UIVisualEffectView *liquidGlassContainer(CGFloat cornerRadius) {
    UIVisualEffectView *glass = nil;
    if (@available(iOS 26.0, *)) {
        // Prefer the system's own liquid glass material when exposed;
        // otherwise fall back to the standard blur material.
        Class effectClass = NSClassFromString(@"UIGlassEffect");
        if (effectClass) {
            id effect = [[effectClass alloc] init];
            glass = [[UIVisualEffectView alloc] initWithEffect:effect];
        }
    }
    if (!glass) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        glass = [[UIVisualEffectView alloc] initWithEffect:blur];
    }
    glass.layer.cornerRadius = cornerRadius;
    glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.clipsToBounds = YES;
    glass.userInteractionEnabled = YES;
    return glass;
}

// Restyle one overlay button: wrap (or reuse) a glass container behind it,
// clear its own opaque background, and soften the icon treatment.
static void liquidizeButton(UIButton *button) {
    if (!button || button.hidden) return;

    static char kLiquidGlassKey;
    UIVisualEffectView *existing = objc_getAssociatedObject(button, &kLiquidGlassKey);
    if (!existing) {
        CGFloat side = MAX(button.bounds.size.width, button.bounds.size.height) ?: 44.0;
        UIVisualEffectView *glass = liquidGlassContainer(side / 2.0);
        // Insert behind the button's content within its own superview
        [button.superview insertSubview:glass belowSubview:button];
        glass.translatesAutoresizingMaskIntoConstraints = NO;
        [button.superview addConstraint:
            [NSLayoutConstraint constraintWithItem:glass attribute:NSLayoutAttributeCenterX
                                       relatedBy:NSLayoutRelationEqual toItem:button
                                       attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
        [button.superview addConstraint:
            [NSLayoutConstraint constraintWithItem:glass attribute:NSLayoutAttributeCenterY
                                       relatedBy:NSLayoutRelationEqual toItem:button
                                       attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        [button.superview addConstraint:
            [NSLayoutConstraint constraintWithItem:glass attribute:NSLayoutAttributeWidth
                                       relatedBy:NSLayoutRelationEqual toItem:button
                                       attribute:NSLayoutAttributeWidth multiplier:1.25 constant:0]];
        [button.superview addConstraint:
            [NSLayoutConstraint constraintWithItem:glass attribute:NSLayoutAttributeHeight
                                       relatedBy:NSLayoutRelationEqual toItem:button
                                       attribute:NSLayoutAttributeHeight multiplier:1.25 constant:0]];
        objc_setAssociatedObject(button, &kLiquidGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // Strip the button's own chrome so the glass shows through
    button.backgroundColor = [UIColor clearColor];
    button.layer.cornerRadius = button.bounds.size.height / 2.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.shadowOpacity = 0;
    button.alpha = 0.95;
}

// Walk a view tree and liquidize every direct-subview button container
static void liquidizeOverlayButtons(UIView *root) {
    if (!root) return;
    for (UIView *sub in root.subviews) {
        if ([sub isKindOfClass:UIButton.class]) {
            liquidizeButton((UIButton *)sub);
        } else if ([sub isKindOfClass:UIStackView.class]) {
            for (UIView *item in ((UIStackView *)sub).arrangedSubviews) {
                if ([item isKindOfClass:UIButton.class]) {
                    liquidizeButton((UIButton *)item);
                }
            }
        }
        liquidizeOverlayButtons(sub);
    }
}

// Player overlay chrome (action buttons row, title area containers)
%hook YTMainAppVideoPlayerOverlayView
- (void)layoutSubviews {
    %orig;
    if (!liquidUIActive()) return;
    liquidizeOverlayButtons(self);
}
%end

// Modern player button controller view
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
    %orig;
    if (!liquidUIActive()) return;
    liquidizeOverlayButtons(self);
}
%end

// Bottom tab / pivot bar container
%hook YTPivotBarView
- (void)layoutSubviews {
    %orig;
    if (!liquidUIActive()) return;
    self.backgroundColor = [UIColor clearColor];
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:UIButton.class]) {
            liquidizeButton((UIButton *)sub);
        }
    }
}
%end

// Chips bar (feed filter row) — translucent pill containers
%hook YTIChipsBarContainerViewController
- (void)viewDidLoad {
    %orig;
    if (!liquidUIActive()) return;
    UIView *view = self.view;
    UIView *chips = nil;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:UICollectionView.class]) { chips = sub; break; }
    }
    if (chips) {
        chips.backgroundColor = [UIColor clearColor];
    }
}
%end

%end // gIOS26LiquidUI

// Runtime toggle: the group only initializes when the user enables it.
// On iOS < 26 the hooks run but every restyle is a no-op via the
// availability guard inside liquidUIActive().
%ctor {
    if (liquidUIEnabled()) {
        %init(gIOS26LiquidUI);
    }
}
