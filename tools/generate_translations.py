#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"
OUTPUT = ROOT / "Sources" / "GeneratedTranslations.inc"
LANGUAGES = ["ar", "es", "fa", "fr", "pt"]


def objc_escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "\\r")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def function_name(language: str) -> str:
    return f"WGGenerated_{language}_Translations"


def main() -> None:
    lines: list[str] = []
    counts: dict[str, int] = {}

    for language in LANGUAGES:
        translations = json.loads((RESOURCES / f"{language}.json").read_text(encoding="utf-8"))
        counts[language] = len(translations)
        lines.extend(
            [
                f"static NSDictionary<NSString *, NSString *> *{function_name(language)}(void) {{",
                "    return @{",
            ]
        )
        for source, target in sorted(translations.items(), key=lambda item: item[0].casefold()):
            lines.append(f'        @"{objc_escape(source)}": @"{objc_escape(target)}",')
        lines.extend(["    };", "}", ""])

    lines.extend(
        [
            "static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *WGGeneratedTranslationTables(void) {",
            "    return @{",
        ]
    )
    for language in LANGUAGES:
        lines.append(f'        @"{language}": {function_name(language)}(),')
    lines.extend(["    };", "}", ""])

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated {OUTPUT.relative_to(ROOT)}: " + ", ".join(f"{k}={v}" for k, v in counts.items()))


if __name__ == "__main__":
    main()
