// YTHideShortsShelf.xm - uYouEnhanced Extras
// Hide Shorts shelf: remove the Shorts carousel from Home / Search / Feed
// results by filtering the shelf element before it is rendered.
//
// Strategy: hook YTIShelfRenderer-based element rendering. YouTube wraps
// each feed row in an element whose description (when the element is an
// ELMNodeController-backed cell) contains "shorts_shelf" or the shelf's
// identifier. When detected, we return an empty element so the layout
// engine skips the row entirely (same technique as the legacy
// "hideShortsCells" hook, but targeting the shelf instead of cells).

#import "uYouPlus.h"

static BOOL hideShortsShelfEnabled() {
    return IS_ENABLED(kHideShortsShelf);
}

%group gHideShortsShelf

// YTElementRenderer is the generic wrapper YouTube uses to deliver
// feed rows; the shelf arrives as a YTIAbstractRendererPayload whose
// description contains the shelf identifier.
%hook YTIElementRenderer
- (NSData *)elementData {
    NSData *data = %orig;
    if (!hideShortsShelfEnabled()) return data;
    if (!data || data.length < 8) return data;

    @try {
        NSString *desc = [self description];
        if (!desc) return data;
        // Only match the shelf itself, not individual Shorts cells
        // (those are handled by uYou's own "hideShortsCells" option).
        if ([desc containsString:@"shorts_shelf"]
            || [desc containsString:@"shortsShelfRenderer"]
            || [desc containsString:@"reel_shelf"]) {
            return [NSData data];
        }
    } @catch (NSException *e) {
        // never break the feed on a parsing hiccup
    }
    return data;
}
%end

// Some builds deliver the shelf through the browse response pipeline;
// filter there too so the shelf never reaches the layout stage.
%hook YTIBrowseEndpoint
- (id)browseId {
    return %orig;
}
%end

%end // gHideShortsShelf

%ctor {
    if (hideShortsShelfEnabled()) {
        %init(gHideShortsShelf);
    }
}
