// YTRememberSpeed.xm - uYouEnhanced Extras
// Remember playback speed: persist the user's chosen playback rate across
// videos and app restarts (per-session override of YouTube's default 1.0x).
//
// Strategy: MLPlayerStickySettings.rate is the object YouTube itself uses
// to hand the player its initial rate when a new MLAVPlayer is created
// (see FixPlayback.xm - makeAVPlayer reads stickySettings.rate). We hook
// the two places that write the rate:
//   1. YTMainAppVideoPlayerOverlayViewController.setPlaybackRate:
//   2. YTPlayerViewController.setPlaybackRate: (via the overlay delegate)
// and rewrite stickySettings.rate to the saved value whenever a player is
// acquired. The saved value lives in NSUserDefaults so it survives restarts.

#import "uYouPlus.h"
#import <YouTubeHeader/MLPlayerStickySettings.h>

#define kSavedRateKey @"rememberedPlaybackRate"

static BOOL rememberSpeedEnabled() {
    return IS_ENABLED(kRememberSpeed);
}

static float rememberedRate() {
    float r = [[NSUserDefaults standardUserDefaults] floatForKey:kSavedRateKey];
    if (r < 0.25f || r > 4.0f) r = 1.0f;
    return r;
}

static void saveRate(float rate) {
    [[NSUserDefaults standardUserDefaults] setFloat:rate forKey:kSavedRateKey];
}

%group gRememberSpeed

// 1) User sets a rate from the speed menu (overlay controller)
%hook YTMainAppVideoPlayerOverlayViewController
- (void)setPlaybackRate:(CGFloat)rate {
    %orig(rate);
    if (rememberSpeedEnabled() && rate > 0.0f) {
        saveRate((float)rate);
    }
}
%end

// 2) MLPlayerStickySettings is handed to the player pool for every new
//    video; rewrite the rate so the new player starts at the saved speed.
%hook MLPlayerStickySettings
- (void)setRate:(float)rate {
    if (rememberSpeedEnabled()) {
        float saved = rememberedRate();
        if (saved > 0.0f && saved != rate) {
            %orig(saved);
            return;
        }
    }
    %orig;
}

- (float)rate {
    float rate = %orig;
    if (rememberSpeedEnabled()) {
        float saved = rememberedRate();
        if (saved > 0.0f && rate == 1.0f && saved != 1.0f) {
            return saved;
        }
    }
    return rate;
}
%end

%end // gRememberSpeed

%ctor {
    if (rememberSpeedEnabled()) {
        %init(gRememberSpeed);
    }
}
