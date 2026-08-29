// YTMediaDownload.xm - uYouEnhanced Extras
// Built-in downloader menu: adds a "Media Download" action (long-press the
// player share button) covering:
//   - Video (best muxed stream — up to 1080p60; higher resolutions are
//     adaptive-only and require muxing, out of scope for the share flow)
//   - Audio-only (largest audio stream)
//   - Captions (timedtext XML, default track)
//   - Thumbnail (highest-res JPG)
//   - Video details (player response JSON)
//
// Complements two existing paths without duplicating them:
//   - DownloadPipeline.xm already repairs uYou's native download flow via
//     innertube (DownloadsManager.getLinksLocallyPlayerItem hook) — that
//     path stays enabled and unchanged.
//   - REPLACE_YT_DOWNLOAD_WITH_UYOU swaps the YouTube download button for
//     uYou's full manager when enabled.
// This hook adds a standalone share-sheet flow that works regardless of
// either path.

#import "uYouPlus.h"
#import <AVFoundation/AVFoundation.h>

static BOOL mediaDownloadEnabled() {
    return IS_ENABLED(kMediaDownloadButton);
}

// --- Player response access ------------------------------------------------
// Uses YouTubeExtractor (repo's own innertube client, Extractor.h/xm) with
// the video ID found via the responder chain — no guessed class methods.

#import "Extractor.h"

static NSString *currentVideoID(void) {
    // Walk the responder chain looking for anything exposing a videoId
    // (works from any view inside the watch page); strictly guarded.
    for (id scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                UIResponder *responder = window;
                while (responder) {
                    @try {
                        if ([responder respondsToSelector:@selector(videoId)]) {
                            id val = [responder performSelector:@selector(videoId)];
                            if ([val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0
                                && ![(NSString *)val containsString:@" "]) {
                                return val;
                            }
                        }
                    } @catch (NSException *e) {}
                    responder = responder.nextResponder;
                }
            }
        }
    }
    return nil;
}

static NSDictionary *currentPlayerResponse(void) {
    NSString *videoId = currentVideoID();
    if (!videoId) return nil;
    return [YouTubeExtractor youtubePlayerRequest:@"ios" :videoId];
}

static NSArray *adaptiveFormats(void) {
    NSDictionary *pr = currentPlayerResponse();
    return pr[@"streamingData"][@"adaptiveFormats"] ?: @[];
}

static NSArray *muxedFormats(void) {
    NSDictionary *pr = currentPlayerResponse();
    return pr[@"streamingData"][@"formats"] ?: @[];
}

static NSString *videoTitleSafe(void) {
    NSDictionary *pr = currentPlayerResponse();
    NSString *title = pr[@"videoDetails"][@"title"];
    NSCharacterSet *bad = [NSCharacterSet characterSetWithCharactersInString:@"/\\:?%*|\"<>"];
    title = [[title componentsSeparatedByCharactersInSet:bad] componentsJoinedByString:@"-"];
    return title ?: @"YouTubeMedia";
}

// Pick the best muxed stream (itags 22=720p, 18=360p; some builds expose
// 37/1080p). Falls back to the largest muxed format.
static NSDictionary *bestMuxedVideoFormat(void) {
    NSArray *formats = muxedFormats();
    NSDictionary *best = nil;
    long bestPixels = -1;
    for (NSDictionary *f in formats) {
        long w = [f[@"width"] longValue];
        long h = [f[@"height"] longValue];
        long fps = [f[@"fps"] longValue] ?: 30;
        long pixels = w * h * (fps >= 50 ? 2 : 1);
        if (pixels > bestPixels) { bestPixels = pixels; best = f; }
    }
    return best;
}

static NSDictionary *bestAudioFormat(void) {
    NSArray *formats = adaptiveFormats();
    NSDictionary *best = nil;
    long bestBitrate = -1;
    for (NSDictionary *f in formats) {
        NSString *mime = f[@"mimeType"];
        if (![mime hasPrefix:@"audio"]) continue;
        long bitrate = [f[@"bitrate"] longValue];
        if (bitrate > bestBitrate) { bestBitrate = bitrate; best = f; }
    }
    return best;
}

static NSString *captionURL(void) {
    NSDictionary *pr = currentPlayerResponse();
    NSArray *tracks = pr[@"captions"][@"playerCaptionsTracklistRenderer"][@"captionTracks"];
    if (tracks.count == 0) return nil;
    NSString *base = tracks[0][@"baseUrl"];
    return base ? [base stringByAppendingString:@"&fmt=xml"] : nil;
}

static NSString *thumbnailURL(void) {
    NSDictionary *pr = currentPlayerResponse();
    NSArray *thumbs = pr[@"videoDetails"][@"thumbnail"][@"thumbnails"];
    NSDictionary *best = nil;
    long bestW = -1;
    for (NSDictionary *t in thumbs) {
        long w = [t[@"width"] longValue];
        if (w > bestW) { bestW = w; best = t; }
    }
    return best[@"url"];
}

// --- Download execution -----------------------------------------------------

static void presentShareSheet(NSArray *items, UIView *anchorView) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIActivityViewController *sheet =
            [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
        if (anchorView.window) {
            sheet.popoverPresentationController.sourceView = anchorView;
            sheet.popoverPresentationController.sourceRect = anchorView.bounds;
        }
        UIViewController *top = anchorView.window.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        [top presentViewController:sheet animated:YES completion:nil];
    });
}

static void downloadToFile(NSString *urlString, NSString *filename, UIView *anchor) {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    [[NSURLSession.sharedSession downloadTaskWithURL:url
        completionHandler:^(NSURL *location, NSURLResponse *resp, NSError *error) {
            if (error || !location) return;
            NSFileManager *fm = NSFileManager.defaultManager;
            [fm removeItemAtPath:tmp error:nil];
            [fm moveItemAtPath:location.path toPath:tmp error:nil];
            presentShareSheet(@[[NSURL fileURLWithPath:tmp]], anchor);
        }] resume];
}

static void downloadCaptions(UIView *anchor) {
    NSString *url = captionURL();
    if (!url) return;
    downloadToFile(url, [videoTitleSafe() stringByAppendingString:@".xml"], anchor);
}

static void downloadThumbnail(UIView *anchor) {
    NSString *url = thumbnailURL();
    if (!url) return;
    downloadToFile(url, [videoTitleSafe() stringByAppendingString:@".jpg"], anchor);
}

static void downloadVideoDetails(UIView *anchor) {
    NSDictionary *pr = currentPlayerResponse();
    if (!pr) return;
    NSData *json = [NSJSONSerialization dataWithJSONObject:pr options:NSJSONWritingPrettyPrinted error:nil];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [videoTitleSafe() stringByAppendingString:@"-details.json"]];
    [json writeToFile:path atomically:YES];
    presentShareSheet(@[[NSURL fileURLWithPath:path]], anchor);
}

// --- UI wiring --------------------------------------------------------------

static void showMediaDownloadMenu(UIView *anchor) {
    NSDictionary *video = bestMuxedVideoFormat();
    NSDictionary *audio = bestAudioFormat();
    NSString *videoLabel = video
        ? [NSString stringWithFormat:@"Video — %@x%@%@",
            video[@"width"], video[@"height"],
            ([video[@"fps"] longValue] >= 50 ? @" (high fps)" : @"")]
        : @"Video — unavailable";
    NSString *audioLabel = audio
        ? [NSString stringWithFormat:@"Audio — %@kbps", audio[@"bitrate"]]
        : @"Audio — unavailable";

    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"Media Download"
        message:videoLabel message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    menu.message = [NSString stringWithFormat:@"%@\n%@", videoLabel, audioLabel];

    if (video[@"url"]) {
        [menu addAction:[UIAlertAction actionWithTitle:videoLabel style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            downloadToFile(video[@"url"],
                [NSString stringWithFormat:@"%@.mp4", videoTitleSafe()], anchor);
        }]];
    }
    if (audio[@"url"]) {
        [menu addAction:[UIAlertAction actionWithTitle:audioLabel style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            downloadToFile(audio[@"url"],
                [NSString stringWithFormat:@"%@.m4a", videoTitleSafe()], anchor);
        }]];
    }
    if (captionURL()) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Captions (.xml)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            downloadCaptions(anchor);
        }]];
    }
    if (thumbnailURL()) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Thumbnail (.jpg)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            downloadThumbnail(anchor);
        }]];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"Video details (.json)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        downloadVideoDetails(anchor);
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    UIViewController *top = anchor.window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    [top presentViewController:menu animated:YES completion:nil];
}

%group gMediaDownload

// Add a "Media Download" entry to the player overlay share flow: long-press
// on the share button triggers the menu (keeps stock share behavior intact).
%hook YTMainAppControlsOverlayView
- (void)didMoveToWindow {
    %orig;
    if (!mediaDownloadEnabled()) return;
    UIButton *shareButton = nil;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:UIButton.class] &&
            [[sub accessibilityIdentifier] containsString:@"share"]) {
            shareButton = (UIButton *)sub;
            break;
        }
    }
    if (!shareButton) return;
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(mediaDownloadLongPress:)];
    [shareButton addGestureRecognizer:lp];
}
%new
- (void)mediaDownloadLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        showMediaDownloadMenu(gesture.view);
    }
}
%end

%end // gMediaDownload

%ctor {
    if (mediaDownloadEnabled()) {
        %init(gMediaDownload);
    }
}
