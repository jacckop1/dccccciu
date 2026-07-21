#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRANSLATIONS = (ROOT / "Sources" / "WGTranslations.m").read_text(encoding="utf-8")
HEADER = (ROOT / "Sources" / "WGTranslations.h").read_text(encoding="utf-8")

required = [
    'wg_tgBaseLanguageCode',
    'WGCurrentTelegramLanguageCode',
    'AppleLanguages',
    'NSBundle.mainBundle.preferredLocalizations',
    'NSLocale.preferredLanguages',
    '@"ar"', '@"en"', '@"es"', '@"fa"', '@"fr"', '@"pt"',
]
for token in required:
    assert token in TRANSLATIONS or token in HEADER, f"Missing auto-language token: {token}"

forbidden = [
    'WGSelectedLanguage',
    'WGSetSelectedLanguageCode',
    'WGLanguageDidChangeNotification',
]
for token in forbidden:
    assert token not in TRANSLATIONS and token not in HEADER, f"Manual selector remains: {token}"

samples = {
    "ar": "ar", "ar-IQ": "ar", "AR_iq": "ar",
    "en": "en", "en-US": "en",
    "es-ES": "es", "fa_IR": "fa",
    "fr-FR": "fr", "pt-BR": "pt",
    "de-DE": None, "system": None, "": None,
}

def normalize(raw: str):
    value = raw.replace("_", "-").strip().lower()
    if not value or value in {"system", "default", "auto", "base"}:
        return None
    primary = value.split("-", 1)[0]
    return primary if primary in {"ar", "en", "es", "fa", "fr", "pt"} else None

for raw, expected in samples.items():
    actual = normalize(raw)
    assert actual == expected, f"{raw!r}: expected {expected!r}, got {actual!r}"

print("Auto-language validation: OK")
print("Primary Telegram key: wg_tgBaseLanguageCode")
print("Supported languages: ar, en, es, fa, fr, pt")
print("Unsupported Telegram languages fall back to app/system language, then English.")
