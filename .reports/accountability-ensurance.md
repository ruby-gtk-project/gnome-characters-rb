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

## This round — three more stale claims found and corrected, not re-cited

Three commits landed on `ruby` between the previous audit round (reports
pinned at port `d89d6f1`'s ancestor `686d2f1`) and this one:

```
3fc46f8 Port tests/testUtil.js and fix the search-result whitespace filter
b1ecdbc Port the mirrored-character related-entry via BidiMirroring.txt
d89d6f1 test: give the search-result screenshot enough settle time to realise
```

Before writing anything new, every number in the four existing reports was
re-derived against the current tree rather than trusted, and three had gone
stale in the direction that matters most — reporting a gap as still open
when it had been closed, which is the shape that makes a reviewer skip
re-checking something that already needs no more work, but also the shape
that makes a reviewer *distrust a report that turns out to have been right
to flag the gap in the first place and just never got credit for the fix*:

1. **`test-parity.md`** said 0/1 upstream tests ported and `spec/` broken
   with zero test files. Re-run this round:
   `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; ...'`
   → **15 examples, 0 failures**. `spec/util_spec.rb` and `spec/gc_spec.rb`
   (added in `3fc46f8`) port `tests/testUtil.js` in full. Corrected in place.
2. **`component-parity.md`** carried Gc's mirrored-character "See Also"
   cross-ref as a real, documented gap (no Ruby binding for
   `g_unichar_get_mirror_char`). `b1ecdbc` closed it by porting the
   underlying BidiMirroring.txt data table directly. Re-verified by reading
   `lib/gc.rb:584-638` and running `spec/gc_spec.rb`'s three mirroring
   assertions. Corrected in place; axis 1–3 count moved from 9/12 to 10/12.
3. **`translation-parity.md`** carried the metainfo `<summary>` as a reworded
   (gap) string over one space character, citing upstream's `.in.in`
   template. `b1ecdbc` changed the port to match the template, but the
   template is not the canonical msgid — upstream's own `.po` files carry
   the single-space form. Checking the `.po` files directly this round shows
   the port's **original, pre-`b1ecdbc`** single-space string was already
   correct, and the "gap" the prior report flagged was itself wrong about
   which bytes are authoritative. Corrected in place, with the `.po` grep
   that proves it, rather than either silently dropped or re-asserted.

**Why this is filed under accountability-ensurance rather than just fixed
quietly:** a report that goes stale and keeps claiming a closed gap is open
is the same failure class as `component-inventory.md`'s stale `MISSING`
rows from the prior round — a document cited as current fact about the
tree without anyone re-running what it depends on. The fix in both cases is
the same: re-derive before citing, and correct in place with the commit that
changed the ground truth named, never just overwrite the number silently.

None of these three corrections changes this round's two open, real
findings — **zero gettext anywhere in `lib/`/`exe/`, 0/78 languages shipped,
no `po/` directory** (unchanged, re-confirmed: `grep -rn 'require .gettext\|
FastGettext\|_("' lib/ exe/` still returns nothing) — which remain the
dominant gap in this port and are not touched by any of the three commits
above.

## This round — the prior round's own closing claim went stale, caught before re-citing it

The prior round's "Verdict" section below ends: *"zero gettext anywhere in
`lib/`/`exe/`, 0/78 languages shipped, no `po/` directory... remain the
dominant gap in this port."* Commit `3135717` landed since and makes that
sentence false — `po/` exists, 75 languages ship, `lib/i18n.rb` wires
`require 'gettext'` through most of `lib/`. Per this skill's own rule
against citing a stale claim as current, this is flagged and corrected here
rather than left standing under "Verdict" below, even though the direction
of the staleness (claiming a bigger gap than currently exists) is the safer
one to be wrong in.

**That does not make this round's translation finding a non-finding.**
`translation-parity.md` this round finds **120 real gaps against upstream's
174-message count** (down from the stale "208/217"), and a **domain
mismatch** (`gnome-characters-rb` vs upstream's `org.gnome.Characters`) that
no prior report caught, because no prior report checked `po/meson.build`
against `lib/i18n.rb`. The dominant piece of the 120 — 117 Unicode script
names (`lib/gc.rb`, `lib/data/language_scripts.tsv`) that carry zero
translation markers — is a real, located, unexcused gap: `lib/gc.rb` offers
no sentence anywhere claiming this is fine, by design, or out of scope. It
is simply absent, and `translation-parity.md`/`component-parity.md` both
say so by file and line rather than by label. No excuse language was found
attached to it, which is correct, but its absence from an excuse is not the
same as its absence from the port — it is still owed.

Two scanner defects were found and fixed by hand this round (HTML-entity
decoding in `.ui` XML, a Python format-string false positive) rather than
reported as port gaps that do not exist — see `translation-parity.md`'s
"Step 1" for both, with the `.po` cross-check that proves each one.

## Verdict

The port's actual code (`lib/`, `exe/`) carries no excuse language across
every round so far, this one included — re-scanned this round
(`find-excuses.sh .`, hand `grep` over `lib/exe/.reports`), zero real hits
in `lib/`/`exe/`. The failures this skill exists to catch keep showing up
in **reports**, not code: the first round's `.reports/component-inventory.md`
was stale and excuse-worded on five rows; this round's own prior version of
this document closed with a now-false claim ("0/78 languages, no `po/`")
that commit `3135717` had already overtaken. Both are fixed in place, named
in their own "This round" sections, not silently swapped. The 120 real
translation gaps and the domain mismatch this round's `translation-parity.md`
found are real, located by file and line, and carry no excuse anywhere —
the script-name table is simply unmarked, stated as exactly that, nothing
more.
