#import "DLIApertureObserver.h"

static id DLIApertureValue(id object, NSString *key) {
    if (!object) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *e) {
        return nil;
    }
}

@implementation DLIApertureObserver {
    NSDictionary *_lastInfo;
}

- (instancetype)init {
    if ((self = [super init])) {
        _islandFrame = CGRectNull;
        _primaryFrame = CGRectNull;
        _bubbleFrame = CGRectNull;
    }
    return self;
}

- (BOOL)updateFromApertureViewController:(UIViewController *)viewController {
    // The hook runs on every layout pass; most of them report the same layout again (a
    // small dictionary, cheap to compare).
    NSDictionary *info = DLIApertureValue(viewController, @"_cachedLayoutDidChangeUserInfo");
    if ([info isKindOfClass:NSDictionary.class] && [info isEqual:_lastInfo] && !CGRectIsNull(_islandFrame)) return NO;
    _lastInfo = [info isKindOfClass:NSDictionary.class] ? [info copy] : nil;

    // The curtain view always covers the sensor housing, whatever the elements do.
    UIView *curtain = DLIApertureValue(viewController, @"_magiciansCurtainView");
    if ([curtain isKindOfClass:UIView.class] && curtain.window) {
        CGRect frame = [curtain convertRect:curtain.bounds toView:nil];
        if (frame.size.height > 1) _islandFrame = frame;
    }

    NSArray *identifiers = [info isKindOfClass:NSDictionary.class] ? info[@"SBSystemApertureVisibleElementIdentifiers"] : nil;
    NSArray *frames = [info isKindOfClass:NSDictionary.class] ? info[@"SBSystemApertureFrames"] : nil;
    NSUInteger count = [identifiers isKindOfClass:NSArray.class] ? identifiers.count : 0;
    CGRect primary = CGRectNull;
    CGRect bubble = CGRectNull;
    if ([frames isKindOfClass:NSArray.class]) {
        if (frames.count > 0 && [frames[0] isKindOfClass:NSValue.class]
            && strcmp([frames[0] objCType], @encode(CGRect)) == 0)
            primary = [frames[0] CGRectValue];
        // The report lists one frame per visible element; with two, the second is the
        // bubble. Read, never inferred: its size and its offset from the island are
        // exactly what differs between iOS releases.
        if (count >= 2 && frames.count > 1 && [frames[1] isKindOfClass:NSValue.class]
            && strcmp([frames[1] objCType], @encode(CGRect)) == 0) {
            CGRect candidate = [frames[1] CGRectValue];
            // Only a frame right of the primary element is the bubble; a firmware that
            // orders the report differently leaves this null and the island estimate wins.
            if (CGRectIsNull(primary) || CGRectGetMinX(candidate) > CGRectGetMaxX(primary) - 1)
                bubble = candidate;
        }
    }
    _primaryFrame = primary;
    _bubbleFrame = bubble;
    if (CGRectIsNull(_islandFrame) && !CGRectIsNull(primary)) _islandFrame = primary;

    DLIAperturePhase phase;
    NSInteger orientation = [DLIApertureValue(viewController, @"_activeElementInterfaceOrientation") integerValue];
    if (orientation != 0 && orientation != UIInterfaceOrientationPortrait) {
        phase = DLIAperturePhaseLandscape;
    } else if (!CGRectIsNull(primary) && !CGRectIsNull(_islandFrame)
               && primary.size.height > _islandFrame.size.height + 4) {
        phase = DLIAperturePhaseExpanded;
    } else {
        phase = count >= 2 ? DLIAperturePhaseSplit : DLIAperturePhaseSingle;
    }
    BOOL changed = phase != _phase;
    _phase = phase;
    return changed;
}

@end
