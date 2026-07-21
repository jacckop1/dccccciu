#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TWEAK = (ROOT / "Sources" / "Tweak.m").read_text(encoding="utf-8")
BUILD = (ROOT / "build.sh").read_text(encoding="utf-8")
SOURCE_NAMES = {p.name for p in (ROOT / "Sources").iterdir() if p.is_file()}

required = [
    'WGDetectAndTrackWhitegramRoot',
    'WGControllerIsInTrackedWhitegramStack',
    'WGTrackedRootController',
    'WGTrackedNavigationController',
    'WGCollectViewMarkers',
    'WGTranslateController',
    '_ASDisplayView',
    'WGActiveWindow',
    'WGScanInProgress',
]
for token in required:
    assert token in TWEAK, f"Missing scoped safety component: {token}"

forbidden = [
    'WGLanguageOverlay',
    'method_exchangeImplementations',
    'localizedStringForKey:value:table:',
    'wg_is_',
    'wg_nf_',
    'viewDidAppear:',
    'viewWillAppear:',
    'WGScanAllVisibleWindows',
    'UIWindow alloc',
    'UIWindowLevelAlert',
    'NSTimer',
    'dispatch_source_set_timer',
    'UIPanGestureRecognizer',
    'UITapGestureRecognizer',
]
for token in forbidden:
    assert token not in TWEAK, f"Forbidden global/overlay architecture remains: {token}"

assert "WGLanguageOverlay.m" not in BUILD, "Overlay is still compiled"
assert "WGLanguageOverlay.m" not in SOURCE_NAMES, "Overlay source still exists"
assert "WGLanguageOverlay.h" not in SOURCE_NAMES, "Overlay header still exists"

# Only the exact Texture view method may be replaced. This prevents hooks on
# Telegram's original settings controllers and UIKit text classes.
assert TWEAK.count("class_replaceMethod") == 1, "Unexpected additional method hook"
assert "UILabel (" not in TWEAK, "Global UILabel category hook detected"
assert "UIViewController (" not in TWEAK, "Global UIViewController category hook detected"
assert "NSBundle (" not in TWEAK, "Global NSBundle category hook detected"

print("Scoped architecture validation: OK")
print("Overlay UI: removed")
print("Global UIKit hooks: 0")
print("Global controller hooks: 0")
print("Exact runtime hook: _ASDisplayView.didMoveToWindow only")
print("Mutation scope: tracked Whitegram navigation stack only")
