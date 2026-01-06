import sys, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parents[2]
ALLOW_PREFIX = ROOT / "packages/domain-spec"

PATTERNS = [
    re.compile(r".*/schemas/.*", re.I),
    re.compile(r".*schema.*\.(json|ya?ml)$", re.I),
    re.compile(r".*/events/.*", re.I),
    re.compile(r".*/state_machines/.*", re.I),
]

def is_forbidden(path: pathlib.Path) -> bool:
    s = str(path).replace("\\", "/")
    if str(ALLOW_PREFIX).replace("\\", "/") in s:
        return False
    return any(p.match(s) for p in PATTERNS)

def main():
    bad = []
    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        if is_forbidden(p):
            bad.append(p)

    if bad:
        print("ERR: schema/event/state-machine sources found outside packages/domain-spec:")
        for p in bad[:200]:
            print("  -", p.relative_to(ROOT))
        if len(bad) > 200:
            print(f"  ... and {len(bad)-200} more")
        return 1

    print("OK: schema single source (no forbidden sources outside packages/domain-spec)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
