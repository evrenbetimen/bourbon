#!/usr/bin/env python3
"""QC: every user-facing string in the app must exist in the string catalog with a Turkish translation.

Scans App/Sources for literal strings passed to SwiftUI initialisers and modifiers that take a
LocalizedStringKey (Text, Button, Label, Toggle, …), converts interpolations to format specifiers
the same way Xcode does, and compares them with App/Resources/Localizable.xcstrings.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = ROOT / "App" / "Sources"
CATALOG = ROOT / "App" / "Resources" / "Localizable.xcstrings"
LANGUAGES = ["tr"]

CALLS = [
    "Text", "Button", "Label", "Toggle", "Picker", "Section", "TextField", "LabeledContent",
    "ContentUnavailableView", "ProgressView", "Link", "LocalizedStringKey", "SectionHeader",
    r"\.alert", r"\.confirmationDialog", r"\.help", r"\.accessibilityLabel",
    r"\.accessibilityHint", r"\.navigationTitle", "CommandMenu", "StepLayout",
]
STRING = r'"((?:[^"\\]|\\.)*)"'
PATTERNS = [re.compile(rf"(?:{call})\(\s*(?:title:\s*)?{STRING}") for call in CALLS]
PATTERNS += [
    re.compile(rf"String\(localized:\s*{STRING}"),
    re.compile(rf"(?:prompt|title|message):\s*(?:Text\()?{STRING}"),
    re.compile(rf"return\s+{STRING}\s*$", re.MULTILINE),
]
# Strings that are deliberately not translated.
IGNORED = {"·", "", "Bourbon", "Whisky", "Wine", "GPL v3"}
# Files whose `return "…"` lines are user-facing labels.
RETURN_LABEL_FILES = {"Theme.swift", "NewBottleSheet.swift"}
INTEGER_INTERPOLATIONS = {"programCount", "count", "limit"}


def to_key(literal: str) -> str:
    def replace(match: re.Match) -> str:
        expression = match.group(1).strip()
        return "%lld" if expression in INTEGER_INTERPOLATIONS else "%@"

    key = re.sub(r"\\\(((?:[^()]|\([^()]*\))*)\)", replace, literal)
    return key.replace('\\"', '"')


def extract() -> dict:
    found = {}
    for path in sorted(SOURCES.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for pattern in PATTERNS:
            if pattern.pattern.startswith("return") and path.name not in RETURN_LABEL_FILES:
                continue
            for match in pattern.finditer(text):
                key = to_key(match.group(1))
                if key in IGNORED or key.startswith(("http", "-")):
                    continue
                line = text.count("\n", 0, match.start()) + 1
                found.setdefault(key, f"{path.relative_to(ROOT)}:{line}")
    return found


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    entries = catalog.get("strings", {})
    used = extract()
    problems = []

    for key, location in sorted(used.items()):
        if key not in entries:
            problems.append(f"{location}: \"{key}\" is missing from the catalog")
    for key, entry in sorted(entries.items()):
        if entry.get("shouldTranslate") is False:
            continue
        localizations = entry.get("localizations", {})
        for language in LANGUAGES:
            unit = localizations.get(language, {}).get("stringUnit", {})
            if unit.get("state") != "translated" or not unit.get("value"):
                problems.append(f"\"{key}\" has no {language} translation")
            elif key.count("%") != unit["value"].count("%"):
                problems.append(f"\"{key}\" and its {language} translation use different placeholders")

    unused = sorted(set(entries) - set(used))
    print(f"{len(used)} strings in code, {len(entries)} in the catalog, {len(unused)} only in the catalog.")
    if problems:
        print("\n".join(problems))
        return 1
    print("Localization OK.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
