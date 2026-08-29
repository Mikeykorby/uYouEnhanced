// YTHideShortsShelf.xm - uYouEnhanced Extras
// Hide Shorts shelf: remove the Shorts carousel from Home / Search / Feed
// results by filtering the shelf element before it is rendered.
//
// Strategy (mirrors AdBlocking.xm's proven filteredArray approach):
// YTInnerTubeCollectionViewController._sectionRenderers contains
// YTIShelfRenderer-wrapped sections; a shelf whose horizontal list items
// are all Shorts cells (or whose description contains the shelf id) is
// dropped before display.

#import "uYouPlus.h"

static BOOL hideShortsShelfEnabled() {
    return IS_ENABLED(kHideShortsShelf);
}

%group gHideShortsShelf

static BOOL isShortsShelfSection(YTIItemSectionRenderer *sectionRenderer) {
    if ([sectionRenderer isKindOfClass:%c(YTIShelfRenderer)]) {
        YTIShelfSupportedRenderers *content = ((YTIShelfRenderer *)sectionRenderer).content;
        YTIHorizontalListRenderer *horizontalListRenderer = content.horizontalListRenderer;
        if (horizontalListRenderer.itemsArray.count == 0) return NO;
        // A Shorts shelf's items all carry the shorts shelf identifier
        for (YTIHorizontalListSupportedRenderers *supported in horizontalListRenderer.itemsArray) {
            NSString *desc = [supported.elementRenderer description];
            if (![desc containsString:@"shorts_shelf"]
                && ![desc containsString:@"shortsShelfRenderer"]
                && ![desc containsString:@"reel_shelf"]) {
                return NO;
            }
        }
        return YES;
    }
    NSString *desc = [sectionRenderer description];
    return [desc containsString:@"shorts_shelf"]
        || [desc containsString:@"shortsShelfRenderer"];
}

static NSMutableArray <YTIItemSectionRenderer *> *filteredShelfArray(NSArray <YTIItemSectionRenderer *> *array) {
    NSMutableArray <YTIItemSectionRenderer *> *newArray = [array mutableCopy];
    NSIndexSet *removeIndexes = [newArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionRenderer *sectionRenderer, NSUInteger idx, BOOL *stop) {
        return isShortsShelfSection(sectionRenderer);
    }];
    [newArray removeObjectsAtIndexes:removeIndexes];
    return newArray;
}

%hook YTInnerTubeCollectionViewController
- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer {
    NSMutableArray *sectionRenderers = [self valueForKey:@"_sectionRenderers"];
    [self setValue:filteredShelfArray(sectionRenderers) forKey:@"_sectionRenderers"];
    %orig;
}
%end

%end // gHideShortsShelf

%ctor {
    if (hideShortsShelfEnabled()) {
        %init(gHideShortsShelf);
    }
}
