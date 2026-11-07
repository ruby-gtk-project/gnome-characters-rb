# Accountability ensurance — gnome-characters-rb

| | |
|---|---|
| Scan command | `bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .` |
| Also grepped by hand | `grep -rniE "TODO|FIXME|not implemented|for now|in a future|not yet|stub" lib/ exe/ .reports/ PORTING.md` |

## What the scan found, before this audit's own edits

```
.reports/component-inventory.md:242:N/A:asserts the behaviour cannot exist here...
.reports/component-inventory.md:210:by design:borrows architectural vocabulary for an unmade decision
.reports/component-inventory.md:242:by design:borrows architectural vocabulary for an unmade decision
.reports/component-inventory.md:229:not ported:honest but toothless - name the behaviour and owe it
```

All four hits were in the **existing** `.reports/component-inventory.md`,
written before this audit. They were rewritten in place (never deleted) as
part of this audit — see the diff to that file in this same commit — and a
re-run of the scanner after the rewrite returns zero hits. The rewrites:

- The "by design" line excusing the Settings unit's JSON backend was
  replaced with a first-person admission that its two GSettings keys'
  translatable `<summary>`/`<description>` text was never carried over —
  a real gap this phrasing had been hiding.
- The "not ported" / "MISSING" / "N/A by design" table describing the six
  non-widget packaging artifacts was replaced with a corrected table: three
  of those "MISSING" rows were simply **false** at the time of this audit —
  the desktop entry, metainfo and search-provider `.ini` files exist in the
  current tree (added by commit `d632e53`, after the inventory was first
  written) — and the `po/` row, which is genuinely still missing, now says
  so without a "no Ruby analogue"-style hedge.

## The false-green finding this audit treats as its most serious

**`.reports/component-inventory.md` reported `MISSING` for files that, by
the time an orchestrator or reviewer would read that report, had already
been added.** That is a report actively lying about the state of the
repository — not by malice, but because it was written once and never
regenerated against a later commit, and nothing in this org's process forced
it to be re-checked before being treated as current. A stale claim in the
*safe* direction (claiming something missing that actually exists) is less
dangerous than the reverse, but it is the same failure: a document was
cited as settled fact about the tree's current state without anyone
re-running the check it depended on.

The more dangerous version of this failure is the one the task's runtime
gate is vulnerable to and that this audit had to check by hand rather than
trust: **`drive_ok=true, 32 checks passed, 0 failed` is true, re-verified by
actually running `test/drive_characters.rb` in this session** — it is not a
false green. But two adjacent claims that *could* have been false green were
checked and were not waved through:

1. The claim (implicit in treating `spec/` as "the port's tests") that the
   port has an rspec suite. It does not run at all — `spec_helper.rb` raises
   a `LoadError` on `require "gnome/characters/rb"` because
   `lib/gnome/characters/rb.rb` does not exist, and even past that there are
   zero `*_spec.rb` files. This was verified by actually invoking rspec, not
   by reading that `spec/` exists and assuming it works. See
   `.reports/test-parity.md`.
2. The claim that upstream's one real test (`tests/testUtil.js`, meson
   target `Util`) is "covered" by the port's much larger
   `test/drive_characters.rb` suite. It is not — none of that suite's 68
   named cases exercises `Util.character_to_icon_data` or `Gc`'s search API
   the way `testUtil.js` does, and a bigger green suite with zero mapped
   cases is exactly the shape this skill and `test-parity` both warn about.

## No `PORTING.md`, `TEST_PARITY.md`, `COMPONENT_PARITY.md`,
## `TRANSLATION_PARITY.md` or `FINDINGS.md` exist on `ruby`

```sh
$ find . -iname "PORTING.md" -o -iname "TEST_PARITY.md" -o -iname "COMPONENT_PARITY.md" \
         -o -iname "TRANSLATION_PARITY.md" -o -iname "FINDINGS.md"
(no output)
```

None of the four ledgers these skills are written to produce and maintain
exist anywhere on this branch. `.reports/component-inventory.md` is the only
document that resembles one, and it covers only the `component-identification`
/`component-parity` ground — there was never a document a reader could use
to answer "is the test suite ported" or "is this translated" before this
audit's four new reports. An absent ledger is not evidence of nothing being
wrong; it is evidence nobody wrote down what is wrong, which is worse,
because the next agent inherits silence instead of a debt.

## `IRP.md` and `AGENTS.md` — read, no hits

Both are process documents (an incident-response plan, a copy of the house
style read me) with no claims about what was or was not ported. No excuse
language in either.

## `lib/`, `exe/` — grep for TODO/FIXME/stub language

Every hit was a false positive from the Unicode block name "MONGOLIAN LETTER
TODO ..." inside `lib/data/character_names.tsv` — a legitimate character name
table, not an excuse. Zero real TODO/FIXME/"not implemented"/"for now"/"in a
future" comments exist in `lib/` or `exe/`.

## Verdict

The port's actual code (`lib/`, `exe/`) carries no excuse language — the
failure this audit found is not code comments hiding gaps, it is a **report**
(`.reports/component-inventory.md`) that was stale on three rows and used
"by design"/"not ported"/"N/A" phrasing on two more, describing real,
uncounted work (the Settings unit's lost translatable strings, the missing
`po/` catalogue) as though it were a closed question. Both are fixed in
place in this commit. The translation and test gaps themselves remain open —
see `.reports/translation-parity.md` and `.reports/test-parity.md` — and are
not excused anywhere in this audit's own reports.
