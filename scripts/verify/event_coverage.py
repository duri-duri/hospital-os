import sys, yaml, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parents[2]
SSOT = ROOT / "docs/ssot/monorepo.yaml"
CATALOG = ROOT / "packages/domain-spec/events/catalog.yaml"

def load_yaml(p):
    with open(p, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)

def main():
    if not SSOT.exists():
        print(f"ERR: missing {SSOT}")
        return 2
    if not CATALOG.exists():
        print(f"ERR: missing {CATALOG}")
        return 2

    ssot = load_yaml(SSOT)
    cat = load_yaml(CATALOG)

    modules = ssot.get("domain_modules", [])
    declared = set()
    for m in modules:
        for ev in (m.get("events") or []):
            declared.add(ev)

    catalog_events = set(cat.get("events") or [])
    missing = sorted(declared - catalog_events)

    if missing:
        print("ERR: events referenced by domain_modules but missing in domain-spec catalog:")
        for ev in missing:
            print(f"  - {ev}")
        return 1

    print("OK: event coverage (domain_modules ⊆ domain-spec catalog)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
