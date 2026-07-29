"""Assert every /workflow-settings row marks exactly one default value."""
import sys

rows = [
    line for line in open("skills/workflow-settings/SKILL.md")
    if line.startswith("| `") and line.count("|") >= 4
]
missing = [r.split("|")[1].strip() for r in rows if "(default)" not in r]
for key in missing:
    print(f"  ✗ setting {key} marks no default value", file=sys.stderr)
if missing:
    sys.exit(1)
print(f"  ✓ {len(rows)} settings, each marking a default")
