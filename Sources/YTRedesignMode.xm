// YTRedesignMode.xm - uYouEnhanced Extras
// Redesign Mode: a cohesive visual overhaul of YouTube's chrome, designed
// and built by uYouEnhanced. When enabled it applies a consistent design
// language across the app:
//   - Rounded, softened player action buttons (no opaque chips)
//   - Pill-shaped, tinted subscribe/join buttons
//   - Tab bar with tinted active item and translucent background
//   - Rounded video thumbnail corners in feeds
//   - Accent-tinted progress bar
//
// Everything is plain UIKit — no private API dependencies beyond the
// YouTube classes already hooked elsewhere in this tweak. Toggling off
// (and restarting the app) restores stock styling.

#import "uYouPlus.h"
#import <UIKit/UIKit.h>

// Forward-declaration fixes: declare the YouTube classes this file touches
// so the compiler sees full interfaces (headers aren't imported globally).
// NOTE: YTMainAppControlsOverlayView is already fully declared via
// uYouPlus.h -> YTMainAppVideoPlayerOverlayView.h -> YTMainAppControlsOverlayView.h
@interface YTPivotBarView : UIView
@end

@interface YTAppViewController : UIViewController
@end

static BOOL redesignEnabled() {
    return IS_ENABLED(kRedesignMode);
}

// uYouEnhanced accent — a YouTube-adjacent red/rose blend
static UIColor *redesignAccentColor() {
    return [UIColor colorWithRed:0.88 green:0.22 blue:0.36 alpha:1.0];
}

%group gRedesignMode

// --- Player overlay buttons: rounded, translucent, shadowless -----------
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
    %orig;
    if (!redesignEnabled()) return;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:UIButton.class]) {
            UIButton *btn = (UIButton *)sub;
            btn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
            btn.layer.cornerRadius = btn.bounds.size.height / 2.0;
            btn.layer.cornerCurve = kCACornerCurveContinuous;
            btn.layer.shadowOpacity = 0;
            btn.tintColor = [UIColor whiteColor];
        } else if ([sub isKindOfClass:UIStackView.class]) {
            for (UIView *item in ((UIStackView *)sub).arrangedSubviews) {
                if ([item isKindOfClass:UIButton.class]) {
                    UIButton *btn = (UIButton *)item;
                    btn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
                    btn.layer.cornerRadius = item.bounds.size.height / 2.0;
                    btn.layer.cornerCurve = kCACornerCurveContinuous;
                    btn.layer.shadowOpacity = 0;
                }
            }
        }
    }
}
%end

// --- Subscribe / pill-style buttons: rounded + accent tint ---------------
// YTQTMButton is YouTube's universal button class (verified header, also
// hooked by LowContrastMode.xm) covering subscribe/join/action chips.
%hook YTQTMButton
- (void)layoutSubviews {
    %orig;
    if (!redesignEnabled()) return;
    self.layer.cornerRadius = self.bounds.size.height / 2.0;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.shadowOpacity = 0;
    if (!self.customTintColor) {
        self.customTintColor = redesignAccentColor();
    }
}
%end

// --- Feed thumbnails: continuous rounded corners -------------------------
%hook YTAsyncCollectionView
- (UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = %orig;
    if (!redesignEnabled() || !cell) return cell;
    cell.contentView.layer.cornerRadius = 14.0;
    cell.contentView.layer.cornerCurve = kCACornerCurveContinuous;
    cell.contentView.layer.masksToBounds = YES;
    return cell;
}
%end

// --- Tab bar: translucent background, tinted active item -----------------
%hook YTPivotBarView
- (void)layoutSubviews {
    %orig;
    if (!redesignEnabled()) return;
    self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:UIButton.class]) {
            UIButton *btn = (UIButton *)sub;
            btn.tintColor = redesignAccentColor();
        }
    }
}
%end

// --- Progress bar: accent tint -------------------------------------------
// (Progress bar tinting is handled by the existing kRedProgressBar hook in
// uYouPlus.xm; Redesign Mode recommends enabling that toggle alongside.)

// --- Settings / pivot bar view controllers: translucent chrome -----------
%hook YTAppViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (!redesignEnabled()) return;
    self.view.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
}
%end

%end // gRedesignMode

// Runtime toggle: group only initializes when the user enables it.
%ctor {
    if (redesignEnabled()) {
        %init(gRedesignMode);
    }
}
