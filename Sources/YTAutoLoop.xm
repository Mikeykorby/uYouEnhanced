// YTAutoLoop.xm - uYouEnhanced Extras
// Auto loop: when enabled, the current video replays instead of autoplaying
// the next one. Mechanism verified against YouLoop (Tweaks/YouLoop/Tweak.x):
// YTAutoplayAutonavController.loopMode == 2 means "loop this video",
// 0 means normal autonav. We force loopMode to 2 whenever the controller
// is created or set, for as long as the toggle is on.

#import "uYouPlus.h"

// Local interface declaration (mirrors YouLoop/Tweak.x) so the compiler
// sees the full class instead of a forward declaration.
@interface YTAutoplayAutonavController : NSObject
- (NSInteger)loopMode;
- (void)setLoopMode:(NSInteger)loopMode;
@end

static BOOL autoLoopEnabled() {
    return IS_ENABLED(kAutoLoop);
}

%group gAutoLoop

%hook YTAutoplayAutonavController

// New controllers (each video gets a fresh one) start in loop mode
- (id)init {
    self = %orig;
    if (self && autoLoopEnabled()) {
        [self setLoopMode:2];
    }
    return self;
}

- (id)initWithParentResponder:(id)arg1 {
    self = %orig;
    if (self && autoLoopEnabled()) {
        [self setLoopMode:2];
    }
    return self;
}

// While the toggle is on, every attempt to change loop mode lands on 2.
// Turn the toggle off and YouTube regains normal autonav behavior.
- (void)setLoopMode:(NSInteger)mode {
    if (autoLoopEnabled() && mode != 2) {
        %orig(2);
        return;
    }
    %orig;
}

%end

%end // gAutoLoop

%ctor {
    if (autoLoopEnabled()) {
        %init(gAutoLoop);
    }
}
