#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"
KNOWN = ROOT / "data" / "extracted_whitegram_strings.txt"
REPORT = ROOT / "coverage-report.txt"
LANGUAGES = ["ar", "es", "fa", "fr", "pt"]
PLACEHOLDER_RE = re.compile(r"%(?:\d+\$)?(?:@|d|ld|lld|u|lu|llu|f|s|%)")


def placeholders(value: str) -> list[str]:
    return sorted(PLACEHOLDER_RE.findall(value))


def main() -> int:
    canonical_table = json.loads((RESOURCES / "ar.json").read_text(encoding="utf-8"))
    known = sorted(canonical_table.keys(), key=str.casefold)
    known_set = set(known)
    errors: list[str] = []
    report = [
        "Whitegram Languages v9 AutoSafe translation coverage",
        "===========================================",
        f"Canonical extracted strings: {len(known)}",
        "",
    ]

    for language in LANGUAGES:
        path = RESOURCES / f"{language}.json"
        if not path.exists():
            errors.append(f"Missing resource: {path.name}")
            continue

        translations = json.loads(path.read_text(encoding="utf-8"))
        keys = set(translations)
        missing = sorted(known_set - keys, key=str.casefold)
        extra = sorted(keys - known_set, key=str.casefold)
        empty = sorted((key for key, value in translations.items() if not str(value).strip()), key=str.casefold)
        placeholder_errors = sorted(
            (
                key
                for key, value in translations.items()
                if key in known_set and placeholders(key) != placeholders(value)
            ),
            key=str.casefold,
        )
        translated = len(known) - len(missing) - len(empty)
        coverage = translated / len(known) * 100.0 if known else 100.0

        report.extend(
            [
                f"[{language}]",
                f"Translated:             {translated}/{len(known)}",
                f"Coverage:               {coverage:.2f}%",
                f"Missing keys:           {len(missing)}",
                f"Extra keys:             {len(extra)}",
                f"Empty translations:     {len(empty)}",
                f"Placeholder mismatches: {len(placeholder_errors)}",
                "",
            ]
        )

        if missing:
            errors.append(f"{language}: {len(missing)} missing keys")
            report.extend([f"{language} missing:", *[f"- {item}" for item in missing], ""])
        if extra:
            errors.append(f"{language}: {len(extra)} extra keys")
            report.extend([f"{language} extra:", *[f"- {item}" for item in extra], ""])
        if empty:
            errors.append(f"{language}: {len(empty)} empty translations")
            report.extend([f"{language} empty:", *[f"- {item}" for item in empty], ""])
        if placeholder_errors:
            errors.append(f"{language}: {len(placeholder_errors)} placeholder mismatches")
            report.append(f"{language} placeholder mismatches:")
            translations = json.loads(path.read_text(encoding="utf-8"))
            for key in placeholder_errors:
                report.append(
                    f"- {key!r}: source={placeholders(key)} target={placeholders(translations[key])}"
                )
            report.append("")

    report.append("Status: " + ("FAILED" if errors else "OK"))
    if errors:
        report.extend(["", "Errors:", *[f"- {error}" for error in errors]])

    REPORT.write_text("\n".join(report) + "\n", encoding="utf-8")
    print(REPORT.read_text(encoding="utf-8"))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
