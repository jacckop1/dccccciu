#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import "WGTranslations.h"

/*
 * Whitegram Languages v9 — AutoSafe
 *
 * Safety model:
 * - No floating button, panel, extra UIWindow, gesture recognizer, or timer.
 * - No global UILabel/NSBundle/UIViewController swizzles.
 * - Telegram's original settings are never translated or mutated.
 * - Outside Whitegram, the scanner only performs a bounded, read-only marker
 *   check on the currently visible controller.
 * - After the Whitegram root is positively identified, only that navigation
 *   stack (root and its pushed subpages) is translated.
 * - Language follows Telegram's cached base-language preference automatically.
 */

#pragma mark - Runtime helpers

static void WGSendVoid(id object, SEL selector) {
    if (object && [object respondsToSelector:selector]) {
        ((void (*)(id, SEL))objc_msgSend)(object, selector);
    }
}

static id WGSendObject(id object, SEL selector) {
    if (object && [object respondsToSelector:selector]) {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    }
    return nil;
}

static Ivar WGFindIvar(Class cls, const char *name) {
    for (Class cursor = cls; cursor != Nil; cursor = class_getSuperclass(cursor)) {
        Ivar ivar = class_getInstanceVariable(cursor, name);
        if (ivar) {
            return ivar;
        }
    }
    return NULL;
}

typedef void (*WGStrongIvarSetter)(id object, Ivar ivar, id value);

static WGStrongIvarSetter WGStrongSetter(void) {
    static WGStrongIvarSetter setter = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setter = (WGStrongIvarSetter)dlsym(RTLD_DEFAULT, "object_setIvarWithStrongDefault");
    });
    return setter;
}

static BOOL WGSetStrongObjectIvar(id object, Ivar ivar, id value) {
    WGStrongIvarSetter setter = WGStrongSetter();
    if (!object || !ivar || !setter) {
        return NO;
    }
    setter(object, ivar, value);
    return YES;
}

static BOOL WGObjectIsKindOfRuntimeClass(id object, const char *className) {
    Class cls = objc_getClass(className);
    return cls && object && [object isKindOfClass:cls];
}

static BOOL WGIsKnownTextRenderable(id object) {
    if (!object) {
        return NO;
    }
    return WGObjectIsKindOfRuntimeClass(object, "_TtC7Display17ImmediateTextNode") ||
           WGObjectIsKindOfRuntimeClass(object, "_TtC20TextNodeWithEntities29ImmediateTextNodeWithEntities") ||
           WGObjectIsKindOfRuntimeClass(object, "_TtC7Display17ImmediateTextView") ||
           WGObjectIsKindOfRuntimeClass(object, "_TtCC22MultilineTextComponent22MultilineTextComponent4View") ||
           WGObjectIsKindOfRuntimeClass(object, "_TtCC13ComponentFlow4TextP33_C336015A3F4BB8AB8C7F5EBEFE5DB6BF12MeasureState");
}

static void WGRefreshRenderable(id object) {
    if (!object) {
        return;
    }

    /* These are the minimum redraw requests used by Telegram's text nodes. */
    WGSendVoid(object, NSSelectorFromString(@"invalidateCalculatedLayout"));
    WGSendVoid(object, NSSelectorFromString(@"setNeedsLayout"));
    WGSendVoid(object, NSSelectorFromString(@"setNeedsDisplay"));

    id view = WGSendObject(object, NSSelectorFromString(@"view"));
    if ([view isKindOfClass:UIView.class]) {
        [(UIView *)view setNeedsLayout];
        [(UIView *)view setNeedsDisplay];
    }
}

static NSAttributedString *WGAttributedTextFromKnownObject(id object) {
    if (!WGIsKnownTextRenderable(object)) {
        return nil;
    }

    Ivar ivar = WGFindIvar(object_getClass(object), "attributedText");
    if (!ivar) {
        return nil;
    }

    id value = object_getIvar(object, ivar);
    return [value isKindOfClass:NSAttributedString.class] ? value : nil;
}

#pragma mark - Whitegram root markers (read-only)

@interface WGMarkerState : NSObject
@property (nonatomic, assign) BOOL hasName;
@property (nonatomic, assign) BOOL hasVersion;
@property (nonatomic, assign) BOOL hasSearch;
@property (nonatomic, strong) NSMutableSet<NSString *> *features;
@end

@implementation WGMarkerState
- (instancetype)init {
    self = [super init];
    if (self) {
        _features = [NSMutableSet set];
    }
    return self;
}
@end

static NSString *WGFold(NSString *text) {
    if (![text isKindOfClass:NSString.class] || text.length == 0) {
        return @"";
    }
    return [[[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
             lowercaseString]
            stringByReplacingOccurrencesOfString:@"\u200c" withString:@""];
}

static void WGObserveMarkerText(NSString *text, WGMarkerState *state) {
    if (!state || text.length == 0) {
        return;
    }

    NSString *folded = WGFold(text);
    if (folded.length == 0) {
        return;
    }

    if ([folded containsString:@"whitegram"] ||
        [folded containsString:@"وايت كرام"] ||
        [folded containsString:@"وايتكرام"] ||
        [folded containsString:@"وایت گرام"] ||
        [folded containsString:@"وایتگرام"]) {
        state.hasName = YES;
    }

    static NSRegularExpression *versionRegex;
    static dispatch_once_t versionOnce;
    dispatch_once(&versionOnce, ^{
        versionRegex = [NSRegularExpression regularExpressionWithPattern:@"(?:^|\\s)[0-9]+\\.[0-9]+\\s*\\([0-9]+\\)(?:\\s|$)"
                                                                  options:0
                                                                    error:nil];
    });
    if ([versionRegex firstMatchInString:folded options:0 range:NSMakeRange(0, folded.length)]) {
        state.hasVersion = YES;
    }

    static NSSet<NSString *> *searchMarkers;
    static dispatch_once_t searchOnce;
    dispatch_once(&searchOnce, ^{
        searchMarkers = [NSSet setWithArray:@[
            @"find option...", @"search settings", @"найти опцию...", @"поиск настроек",
            @"البحث في الإعدادات", @"ابحث عن خيار...", @"یافتن گزینه...", @"جستجو در تنظیمات",
            @"buscar opción...", @"buscar ajustes", @"rechercher dans les réglages",
            @"rechercher une option...", @"encontrar opção...", @"pesquisar ajustes"
        ]];
    });
    if ([searchMarkers containsObject:folded]) {
        state.hasSearch = YES;
    }

    static NSDictionary<NSString *, NSString *> *featureMap;
    static dispatch_once_t featureOnce;
    dispatch_once(&featureOnce, ^{
        featureMap = @{
            @"appearance": @"appearance", @"المظهر": @"appearance", @"ظاهر": @"appearance",
            @"apariencia": @"appearance", @"apparence": @"appearance", @"aparência": @"appearance",
            @"notifications": @"notifications", @"الإشعارات": @"notifications", @"اعلان ها": @"notifications",
            @"notificaciones": @"notifications", @"notificações": @"notifications",
            @"liquid glass": @"liquidglass", @"الزجاج السائل": @"liquidglass", @"شیشه مایع": @"liquidglass",
            @"cristal líquido": @"liquidglass", @"vidrio líquido": @"liquidglass",
            @"verre liquide": @"liquidglass", @"vidro líquido": @"liquidglass",
            @"messages": @"messages", @"الرسائل": @"messages", @"پیام ها": @"messages",
            @"mensajes": @"messages", @"mensagens": @"messages",
            @"camera": @"camera", @"الكاميرا": @"camera", @"دوربین": @"camera",
            @"cámara": @"camera", @"caméra": @"camera", @"câmera": @"camera",
            @"privacy": @"privacy", @"الخصوصية": @"privacy", @"حریم خصوصی": @"privacy",
            @"privacidad": @"privacy", @"confidentialité": @"privacy", @"privacidade": @"privacy",
            @"ghost mode": @"ghost", @"وضع الشبح": @"ghost", @"حالة الشبح": @"ghost",
            @"حالت شبح": @"ghost", @"حالت روح": @"ghost", @"modo fantasma": @"ghost",
            @"mode fantôme": @"ghost",
            @"analytics": @"analytics", @"التحليلات": @"analytics", @"تحلیل ها": @"analytics",
            @"analíticas": @"analytics", @"analyses": @"analytics", @"analytique": @"analytics",
            @"análises": @"analytics",
            @"plugins": @"plugins", @"الإضافات": @"plugins", @"افزونه ها": @"plugins",
            @"complementos": @"plugins", @"extensions": @"plugins",
            @"extras": @"extras", @"إضافات": @"extras", @"إضافات أخرى": @"extras",
            @"موارد اضافی": @"extras", @"موارد بیشتر": @"extras", @"suppléments": @"extras"
        };
    });

    NSString *feature = featureMap[folded];
    if (feature) {
        [state.features addObject:feature];
    }
}

static BOOL WGLooksLikeWhitegramRoot(WGMarkerState *state) {
    if (!state) {
        return NO;
    }
    return (state.hasName && state.hasVersion && state.features.count >= 2) ||
           (state.hasName && state.hasSearch && state.features.count >= 3) ||
           (state.hasVersion && state.hasSearch && state.features.count >= 3);
}

#pragma mark - Read-only marker collector

static void WGCollectDisplayNodeMarkers(id node,
                                        NSMutableSet<NSValue *> *visited,
                                        NSUInteger depth,
                                        WGMarkerState *state) {
    if (!node || depth > 70 || visited.count > 2400) {
        return;
    }

    NSValue *identity = [NSValue valueWithPointer:(__bridge const void *)node];
    if ([visited containsObject:identity]) {
        return;
    }
    [visited addObject:identity];

    NSAttributedString *text = WGAttributedTextFromKnownObject(node);
    WGObserveMarkerText(text.string, state);

    id subnodes = WGSendObject(node, NSSelectorFromString(@"subnodes"));
    if ([subnodes isKindOfClass:NSArray.class]) {
        for (id child in (NSArray *)subnodes) {
            WGCollectDisplayNodeMarkers(child, visited, depth + 1, state);
        }
    }
}

static void WGCollectViewMarkers(UIView *view,
                                 NSMutableSet<NSValue *> *visitedNodes,
                                 NSUInteger depth,
                                 WGMarkerState *state) {
    if (!view || depth > 80) {
        return;
    }

    WGObserveMarkerText(view.accessibilityLabel, state);
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        WGObserveMarkerText(label.text, state);
        WGObserveMarkerText(label.attributedText.string, state);
    } else if ([view isKindOfClass:UIButton.class]) {
        WGObserveMarkerText([(UIButton *)view titleForState:UIControlStateNormal], state);
    } else if ([view isKindOfClass:UITextField.class]) {
        UITextField *field = (UITextField *)view;
        WGObserveMarkerText(field.text, state);
        WGObserveMarkerText(field.placeholder, state);
    } else if ([view isKindOfClass:UITextView.class]) {
        WGObserveMarkerText(((UITextView *)view).text, state);
    } else if ([view isKindOfClass:UISearchBar.class]) {
        WGObserveMarkerText(((UISearchBar *)view).placeholder, state);
    }

    NSAttributedString *directText = WGAttributedTextFromKnownObject(view);
    WGObserveMarkerText(directText.string, state);

    if (WGObjectIsKindOfRuntimeClass(view, "_TtCC13ComponentFlow4Text4View")) {
        Ivar measureStateIvar = WGFindIvar(object_getClass(view), "measureState");
        id measureState = measureStateIvar ? object_getIvar(view, measureStateIvar) : nil;
        WGObserveMarkerText(WGAttributedTextFromKnownObject(measureState).string, state);
    }

    id node = WGSendObject(view, NSSelectorFromString(@"asyncdisplaykit_node"));
    if (node) {
        WGCollectDisplayNodeMarkers(node, visitedNodes, 0, state);
    }

    NSArray<UIView *> *subviews = [view.subviews copy];
    for (UIView *subview in subviews) {
        WGCollectViewMarkers(subview, visitedNodes, depth + 1, state);
    }
}

#pragma mark - Scoped translator

static BOOL WGTranslateKnownAttributedTextObject(id object) {
    NSAttributedString *source = WGAttributedTextFromKnownObject(object);
    if (!source || source.length == 0) {
        return NO;
    }

    NSAttributedString *translated = WGTranslateAttributedString(source);
    if (!translated || [translated.string isEqualToString:source.string]) {
        return NO;
    }

    Ivar ivar = WGFindIvar(object_getClass(object), "attributedText");
    if (!WGSetStrongObjectIvar(object, ivar, translated)) {
        return NO;
    }
    WGRefreshRenderable(object);
    return YES;
}

static void WGTranslateDisplayNode(id node,
                                   NSMutableSet<NSValue *> *visited,
                                   NSUInteger depth) {
    if (!node || depth > 70 || visited.count > 2400) {
        return;
    }

    NSValue *identity = [NSValue valueWithPointer:(__bridge const void *)node];
    if ([visited containsObject:identity]) {
        return;
    }
    [visited addObject:identity];

    WGTranslateKnownAttributedTextObject(node);

    id subnodes = WGSendObject(node, NSSelectorFromString(@"subnodes"));
    if ([subnodes isKindOfClass:NSArray.class]) {
        for (id child in (NSArray *)subnodes) {
            WGTranslateDisplayNode(child, visited, depth + 1);
        }
    }
}

static void WGTranslateButton(UIButton *button) {
    const UIControlState states[] = {
        UIControlStateNormal,
        UIControlStateHighlighted,
        UIControlStateSelected,
        UIControlStateDisabled
    };
    for (NSUInteger index = 0; index < sizeof(states) / sizeof(states[0]); index++) {
        UIControlState state = states[index];
        NSAttributedString *attributed = [button attributedTitleForState:state];
        if (attributed.length > 0) {
            NSAttributedString *translated = WGTranslateAttributedString(attributed);
            if (![translated.string isEqualToString:attributed.string]) {
                [button setAttributedTitle:translated forState:state];
            }
        } else {
            NSString *title = [button titleForState:state];
            NSString *translated = WGTranslateString(title);
            if (title && ![translated isEqualToString:title]) {
                [button setTitle:translated forState:state];
            }
        }
    }
}

static void WGTranslateUIKitView(UIView *view) {
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        if (label.attributedText.length > 0) {
            NSAttributedString *source = label.attributedText;
            NSAttributedString *translated = WGTranslateAttributedString(source);
            if (![translated.string isEqualToString:source.string]) {
                label.attributedText = translated;
                label.textAlignment = NSTextAlignmentNatural;
            }
        } else if (label.text.length > 0) {
            NSString *source = label.text;
            NSString *translated = WGTranslateString(source);
            if (![translated isEqualToString:source]) {
                label.text = translated;
                label.textAlignment = NSTextAlignmentNatural;
            }
        }
    } else if ([view isKindOfClass:UIButton.class]) {
        WGTranslateButton((UIButton *)view);
    } else if ([view isKindOfClass:UITextField.class]) {
        UITextField *field = (UITextField *)view;
        NSString *translatedPlaceholder = WGTranslateString(field.placeholder);
        if (field.placeholder && ![translatedPlaceholder isEqualToString:field.placeholder]) {
            field.placeholder = translatedPlaceholder;
        }
        NSString *translatedText = WGTranslateString(field.text);
        if (field.text && ![translatedText isEqualToString:field.text]) {
            field.text = translatedText;
        }
        field.textAlignment = NSTextAlignmentNatural;
    } else if ([view isKindOfClass:UITextView.class]) {
        UITextView *textView = (UITextView *)view;
        if (textView.attributedText.length > 0) {
            NSAttributedString *source = textView.attributedText;
            NSAttributedString *translated = WGTranslateAttributedString(source);
            if (![translated.string isEqualToString:source.string]) {
                textView.attributedText = translated;
            }
        } else if (textView.text.length > 0) {
            NSString *source = textView.text;
            NSString *translated = WGTranslateString(source);
            if (![translated isEqualToString:source]) {
                textView.text = translated;
            }
        }
        textView.textAlignment = NSTextAlignmentNatural;
    } else if ([view isKindOfClass:UISearchBar.class]) {
        UISearchBar *searchBar = (UISearchBar *)view;
        NSString *source = searchBar.placeholder;
        NSString *translated = WGTranslateString(source);
        if (source && ![translated isEqualToString:source]) {
            searchBar.placeholder = translated;
        }
    }
}

static void WGTranslateViewTree(UIView *view,
                                NSMutableSet<NSValue *> *visitedNodes,
                                NSUInteger depth) {
    if (!view || depth > 90) {
        return;
    }

    WGTranslateUIKitView(view);
    WGTranslateKnownAttributedTextObject(view);

    if (WGObjectIsKindOfRuntimeClass(view, "_TtCC13ComponentFlow4Text4View")) {
        Ivar measureStateIvar = WGFindIvar(object_getClass(view), "measureState");
        id measureState = measureStateIvar ? object_getIvar(view, measureStateIvar) : nil;
        if (WGTranslateKnownAttributedTextObject(measureState)) {
            WGRefreshRenderable(view);
        }
    }

    id node = WGSendObject(view, NSSelectorFromString(@"asyncdisplaykit_node"));
    if (node) {
        WGTranslateDisplayNode(node, visitedNodes, 0);
    }

    NSArray<UIView *> *subviews = [view.subviews copy];
    for (UIView *subview in subviews) {
        WGTranslateViewTree(subview, visitedNodes, depth + 1);
    }
}

#pragma mark - Active controller and Whitegram scope

static __weak UINavigationController *WGTrackedNavigationController = nil;
static __weak UIViewController *WGTrackedRootController = nil;
static BOOL WGScanInProgress = NO;

static UIWindow *WGActiveWindow(void) {
    UIApplication *application = UIApplication.sharedApplication;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive ||
                ![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow && !window.hidden && window.alpha > 0.01) {
                    return window;
                }
            }
            for (UIWindow *window in windowScene.windows) {
                if (!window.hidden && window.alpha > 0.01 && window.rootViewController) {
                    return window;
                }
            }
        }
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *window in application.windows) {
        if (window.isKeyWindow && !window.hidden && window.alpha > 0.01) {
            return window;
        }
    }
#pragma clang diagnostic pop
    return nil;
}

static UIViewController *WGVisibleContainerController(UIViewController *controller) {
    UIViewController *cursor = controller;
    for (NSUInteger guard = 0; cursor && guard < 24; guard++) {
        UIViewController *next = nil;
        if (cursor.presentedViewController && !cursor.presentedViewController.isBeingDismissed) {
            next = cursor.presentedViewController;
        } else if ([cursor isKindOfClass:UINavigationController.class]) {
            next = ((UINavigationController *)cursor).visibleViewController;
        } else if ([cursor isKindOfClass:UITabBarController.class]) {
            next = ((UITabBarController *)cursor).selectedViewController;
        }
        if (!next || next == cursor) {
            break;
        }
        cursor = next;
    }
    return cursor;
}

static void WGClearScope(void) {
    WGTrackedNavigationController = nil;
    WGTrackedRootController = nil;
}

static BOOL WGControllerIsInTrackedWhitegramStack(UIViewController *controller) {
    UIViewController *root = WGTrackedRootController;
    UINavigationController *navigation = WGTrackedNavigationController;
    if (!root || !controller) {
        WGClearScope();
        return NO;
    }

    if (!navigation) {
        if (controller == root) {
            return YES;
        }
        UIViewController *presenter = controller.presentingViewController;
        while (presenter) {
            if (presenter == root) {
                return YES;
            }
            presenter = presenter.presentingViewController;
        }
        return NO;
    }

    NSArray<UIViewController *> *stack = navigation.viewControllers;
    NSUInteger rootIndex = [stack indexOfObjectIdenticalTo:root];
    if (rootIndex == NSNotFound) {
        WGClearScope();
        return NO;
    }

    UIViewController *visible = navigation.visibleViewController;
    NSUInteger visibleIndex = [stack indexOfObjectIdenticalTo:visible];
    if (visibleIndex == NSNotFound || visibleIndex < rootIndex) {
        return NO;
    }

    if (controller == visible || controller == navigation || controller.navigationController == navigation) {
        return YES;
    }

    UIViewController *presenter = controller.presentingViewController;
    while (presenter) {
        if (presenter == visible || presenter.navigationController == navigation) {
            return YES;
        }
        presenter = presenter.presentingViewController;
    }
    return NO;
}

static BOOL WGDetectAndTrackWhitegramRoot(UIViewController *controller) {
    if (!controller || !controller.isViewLoaded || !controller.view.window) {
        return NO;
    }

    WGMarkerState *state = [WGMarkerState new];
    WGObserveMarkerText(controller.title, state);
    WGObserveMarkerText(controller.navigationItem.title, state);

    NSMutableSet<NSValue *> *visitedNodes = [NSMutableSet set];
    WGCollectViewMarkers(controller.view, visitedNodes, 0, state);
    if (controller.navigationController.navigationBar) {
        WGCollectViewMarkers(controller.navigationController.navigationBar, visitedNodes, 0, state);
    }

    if (!WGLooksLikeWhitegramRoot(state)) {
        return NO;
    }

    WGTrackedRootController = controller;
    WGTrackedNavigationController = controller.navigationController;
    return YES;
}

static void WGTranslateController(UIViewController *controller) {
    if (!controller || !controller.isViewLoaded || !controller.view.window) {
        return;
    }

    NSString *translatedTitle = WGTranslateString(controller.title);
    if (controller.title && ![translatedTitle isEqualToString:controller.title]) {
        controller.title = translatedTitle;
    }
    NSString *translatedNavigationTitle = WGTranslateString(controller.navigationItem.title);
    if (controller.navigationItem.title &&
        ![translatedNavigationTitle isEqualToString:controller.navigationItem.title]) {
        controller.navigationItem.title = translatedNavigationTitle;
    }

    NSMutableSet<NSValue *> *visitedNodes = [NSMutableSet set];
    WGTranslateViewTree(controller.view, visitedNodes, 0);
    if (controller.navigationController.navigationBar) {
        WGTranslateViewTree(controller.navigationController.navigationBar, visitedNodes, 0);
    }
}

static void WGPerformScopedScan(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ WGPerformScopedScan(); });
        return;
    }
    if (WGScanInProgress || !WGLocalizationEnabled()) {
        return;
    }

    WGScanInProgress = YES;
    @try {
        UIWindow *window = WGActiveWindow();
        UIViewController *controller = WGVisibleContainerController(window.rootViewController);
        if (!controller || !controller.isViewLoaded || !controller.view.window) {
            return;
        }

        BOOL inScope = WGControllerIsInTrackedWhitegramStack(controller);
        if (!inScope) {
            inScope = WGDetectAndTrackWhitegramRoot(controller);
        }

        if (inScope) {
            WGTranslateController(controller);
        }
    } @catch (__unused NSException *exception) {
        /* A failed scan must never take Telegram down. The next screen event
           can retry after the hierarchy has settled. */
    } @finally {
        WGScanInProgress = NO;
    }
}

#pragma mark - Coalesced screen events

static NSUInteger WGScanGeneration = 0;

static void WGRequestScopedScan(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ WGRequestScopedScan(); });
        return;
    }

    NSUInteger generation = ++WGScanGeneration;
    const NSTimeInterval delays[] = {0.06, 0.30, 0.85};
    for (NSUInteger index = 0; index < sizeof(delays) / sizeof(delays[0]); index++) {
        NSTimeInterval delay = delays[index];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (generation == WGScanGeneration) {
                WGPerformScopedScan();
            }
        });
    }
}

#pragma mark - Exact Texture view hook only

static IMP WGOriginalASDisplayViewDidMoveToWindow = NULL;
static BOOL WGASDisplayViewHookInstalled = NO;

static void WGASDisplayViewDidMoveToWindow(id self, SEL _cmd) {
    if (WGOriginalASDisplayViewDidMoveToWindow) {
        ((void (*)(id, SEL))WGOriginalASDisplayViewDidMoveToWindow)(self, _cmd);
    }

    UIView *view = [self isKindOfClass:UIView.class] ? (UIView *)self : nil;
    if (view.window) {
        WGRequestScopedScan();
    }
}

static void WGInstallASDisplayViewHook(void) {
    @synchronized (UIApplication.class) {
        if (WGASDisplayViewHookInstalled) {
            return;
        }

        Class cls = objc_getClass("_ASDisplayView");
        SEL selector = sel_registerName("didMoveToWindow");
        Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
        if (!method) {
            return;
        }

        IMP original = method_getImplementation(method);
        const char *types = method_getTypeEncoding(method);
        if (!original || !types) {
            return;
        }

        WGOriginalASDisplayViewDidMoveToWindow = original;
        class_replaceMethod(cls, selector, (IMP)WGASDisplayViewDidMoveToWindow, types);
        WGASDisplayViewHookInstalled = YES;
    }
}

static void WGApplicationDidBecomeActive(NSNotification *notification) {
    WGInstallASDisplayViewHook();
    WGRequestScopedScan();
}

#pragma mark - Entry point

__attribute__((constructor))
static void WGAutoSafeEntryPoint(void) {
    @autoreleasepool {
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:NSOperationQueue.mainQueue
                                                      usingBlock:^(__unused NSNotification *notification) {
            WGApplicationDidBecomeActive(notification);
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            WGInstallASDisplayViewHook();
            WGRequestScopedScan();

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                WGInstallASDisplayViewHook();
                WGRequestScopedScan();
            });
        });
    }
}
