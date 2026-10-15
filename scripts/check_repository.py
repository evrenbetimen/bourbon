#!/usr/bin/env python3
"""QC: repository hygiene rules that a compiler won't catch.

* The GPL licence and the Whisky attribution stay in place.
* Production sources start with a header comment and avoid crash-prone or debug-only code.
* Every UI-test identifier the tests rely on exists in the app.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE_DIRS = [ROOT / "App" / "Sources", ROOT / "BourbonKit" / "Sources"]
FORBIDDEN = {
    r"\btry!": "use do/catch or try? instead of try!",
    r"(?<![\w.])print\(": "remove debug print() calls",
    r"\bfatalError\(": "don't crash the app; surface the error instead",
    r"\b(TODO|FIXME)\b": "resolve TODO/FIXME before merging",
}


def main() -> int:
    problems = []

    licence = (ROOT / "LICENSE").read_text(encoding="utf-8") if (ROOT / "LICENSE").exists() else ""
    if "GNU GENERAL PUBLIC LICENSE" not in licence or "Version 3" not in licence:
        problems.append("LICENSE must contain the GNU GPL v3 text")

    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    if "Whisky" not in readme or "github.com/Whisky-App/Whisky" not in readme:
        problems.append("README.md must credit Whisky with a link to its repository")

    swift_files = [p for d in SOURCE_DIRS for p in sorted(d.rglob("*.swift"))]
    for path in swift_files:
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(ROOT)
        if not text.startswith("//"):
            problems.append(f"{relative}: start the file with a header comment")
        for number, line in enumerate(text.splitlines(), start=1):
            code = line.split("//", 1)[0] if not line.lstrip().startswith("///") else ""
            for pattern, advice in FORBIDDEN.items():
                target = line if "TODO" in pattern else code
                if re.search(pattern, target):
                    problems.append(f"{relative}:{number}: {advice}")

    app_text = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "App" / "Sources").rglob("*.swift"))
    tests = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "App" / "UITests").rglob("*.swift"))
    for identifier in sorted(set(re.findall(r'element\("([A-Za-z]+)(?:-[^"]*)?"\)', tests))):
        if f'"{identifier}' not in app_text:
            problems.append(f"UI tests use identifier '{identifier}' that the app never sets")

    print(f"Checked {len(swift_files)} Swift files.")
    if problems:
        print("\n".join(problems))
        return 1
    print("Repository checks OK.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
