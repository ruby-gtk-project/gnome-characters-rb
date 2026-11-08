# Test parity — gnome-characters-rb

| | |
|---|---|
| Upstream | `main` @ `4b42297` |
| Port | `ruby` @ `ca1d509` |
| Upstream tests | 1 |
| Ported | 1 |
| Gaps | 0 |
| Test commands run this round | `nix develop --command xvfb-run -a ruby test/drive_characters.rb` (DRIVE OK, **33/33**) and `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` (**15 examples, 0 failures**) |

## This round

Both commands were re-run directly this round rather than taken on the
runtime gate's word. `test/drive_characters.rb` now passes **33/33**
(previously 32/32) — commit `ca1d509` ("test: retry the search-result
screenshot instead of swallowing the race") wraps the *search-result*
screenshot (`06-search`, `test/drive_characters.rb:230-238`) in a retry loop
plus a real `check('the search result page produced a screenshot')`. That
accounts for the +1 to the total: this round's own re-run shows `06-search`
hitting exactly the race the commit message describes (`shot 06-search
failed: RuntimeError: widget produced no render node`, printed, then a
retried attempt that succeeds and the check passes) — the fix is exercised,
not just present.

**This is a different step from the one the prior round's report flagged.**
That report's "Extra" section named *step 28, "the collapsed layout
renders"* (`07-collapsed`) as the one that failed in its run, and `ca1d509`
did not touch that step at all — it is still the bare, unguarded
`d.step('the collapsed layout renders') { d.shot('07-collapsed') }` at
`test/drive_characters.rb:265`, identical before and after `ca1d509`. Both
`06-search` and `07-collapsed` share the same underlying race (a
size-allocate pass that lands on a later frame-clock tick than one `pump`
call reaches); `ca1d509` happened to be written against `06-search`
reproducing it, and closes that one occurrence of the race without closing
the mechanism. Conflating "the screenshot race is fixed" with "the one
instance someone happened to reproduce is fixed" is exactly the kind of
narrow fix this skill asks not to be waved through as the whole problem
closed — so it is not: see the residual gap below.

**One screenshot step is still not covered by any `check`, and this round's
report says so rather than letting the +1 read as "the whole screenshot
problem is fixed."** `test/drive_characters.rb:265`,
`d.step('the collapsed layout renders') { d.shot('07-collapsed') }`, calls
`shot` bare — `shot` rescues its own render failures internally
(`test/gtk_driver.rb:118-119`) and only prints `shot <name> failed: ...`,
it does not raise and nothing asserts on its return value. A render failure
there would **not** reduce the 33/33 count; it would be visible only to a
human reading the full console log. This run's log shows it printed the
success line, not the failure line, so it rendered successfully this round
— but the step's *coverage* is narrower than `06-search`'s, in the same way
the prior round's report was right to flag before `ca1d509` closed it for
search. Not closed this round; named as the residual gap in the same
screenshot-reliability class.

The 15/15 rspec result is unchanged and was re-run to confirm it still
holds against the two translation-wiring commits (`3135717`, `ca1d509`)
that landed since the prior round — neither touches `spec/` or
`Util`/`Gc`, and the re-run confirms nothing regressed there.

## Correction to the prior round's report

The previous version of this document (pinned at port `ruby` @ `686d2f1`)
reported `spec/` as broken — `spec_helper.rb` raising `LoadError` on `require
"gnome/characters/rb"`, and zero `*_spec.rb` files existing — and recorded the
upstream test as a flat gap (0/1). Three commits landed after that report was
written and before this round started:

```
3fc46f8 Port tests/testUtil.js and fix the search-result whitespace filter
b1ecdbc Port the mirrored-character related-entry via BidiMirroring.txt
d89d6f1 test: give the search-result screenshot enough settle time to realise
```

`3fc46f8` is the one that matters here: it adds `spec/util_spec.rb` and
`spec/gc_spec.rb`, and (per `git show 3fc46f8 --stat`) fixes the loader so
`spec_helper.rb`'s `require "gnome/characters/rb"` resolves. **That prior
report's claim is now stale and would be a false-gap if republished
unchanged** — this document replaces it rather than restating it, per the
accountability-ensurance rule that a stale claim must be corrected, not
re-cited.

## Step 1 — census

Upstream's `tests/meson.build` registers exactly one test, named `Util`,
running `gjs_console tests/testUtil.js` under the `default` test setup with
`xvfb-run`. A second suite (`smoke_test.py`) is listed in the same file but is
behind an explicit early `subdir_done()` guarded by `# FIXME: fix
smoke_test.py: it's still using python2 and not tested for long time` —
upstream itself never runs it, so it is not part of the one test upstream
actually has.

`testUtil.js`'s single test asserts two properties (verified by reading
`git show origin/main:tests/testUtil.js` directly this round):

1. `Util.characterToIconData(e)` returns a `GLib.Variant` for three emoji
   (🍕, 🤌, 🥰) and `null` for seven whitespace-only strings.
2. A keyword search (via `Gc.SearchCriteria.new_keywords`, flag `WORD`) for
   `"pizza"` includes 🍕, for `"joy"` includes 😂, and for `"space"` returns
   zero results.

## Step 2 — the ledger

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1a | `tests/testUtil.js` assertions 1–2 (`characterToIconData`) | emoji → `Variant`, whitespace → `nil` | `spec/util_spec.rb` — `Util.character_to_icon_data`, same 3 emoji + 6 whitespace cases (one extra: `"\t   \n    \n \r      "`) | **ported** |
| 1b | `tests/testUtil.js` assertions 3–5 (search) | `"pizza"` finds 🍕, `"joy"` finds 😂, `"space"` finds nothing | `spec/gc_spec.rb` — same three keyword searches via `Gc::SearchCriteria`/`Gc::SearchContext` | **ported** |

Both spec files carry a header comment naming `tests/testUtil.js` as the
source, matching the house style's "every class/spec names the file it was
ported from" rule.

`gc_spec.rb` also adds three extra cases (mirrored-character "See Also"
entries) that have no counterpart in `testUtil.js` — correctly filed in this
round's component-parity report as port-only extra coverage for the
BidiMirroring.txt port, not claimed against the upstream count.

## Step 4 — prove it (ran directly this round, not taken on the ledger's word)

### `spec/` — now loads and passes

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; \
    exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
NOTE: kettle-test isn't installed; running with plain RSpec.
Randomized with seed ...
...............

Finished in 15.59 seconds (files took 7.2 seconds to load)
15 examples, 0 failures
```

15 examples = 9 from `util_spec.rb` (3 emoji + 6 whitespace) + 6 from
`gc_spec.rb` (3 search + 3 mirroring). `spec_helper.rb` loads
`"gnome/characters/rb"` successfully now — confirmed by the run completing
rather than erroring before any example loads, as it did against the prior
commit.

### `test/drive_characters.rb` — still real, still passes, still not upstream's test

```
$ nix develop --command xvfb-run -a ruby test/drive_characters.rb
...
33 of 33 checks passed
DRIVE OK
```

This is the runtime gate for the round (`drive_ok=true, 33 checks passed, 0
failed`), re-run directly in this session rather than trusted from the task
description. It still covers roughly 10 of the 12 units identified in
`component-identification.md` end-to-end (window, sidebar, characters_view,
search, character dialog, breakpoint collapse, shortcuts dialog, about
dialog) but, as before, none of its named steps maps onto `testUtil.js` —
it was written from the port's own UI, not ported from upstream's test. It
remains filed as `Extra`, not against the one upstream row, which is now
closed by the `spec/` files instead.

One screenshot step (`'the collapsed layout renders'`, `07-collapsed`,
`test/drive_characters.rb:265`) is still a bare `d.shot` with no retry and
no `check(...)` wrapping it — see "This round" above. It rendered
successfully in this round's run, but a future failure there would not
reduce the 33/33 count and would be visible only in the raw console log,
not in any number this report or the runtime gate carries. Noted rather
than silently absorbed into "DRIVE OK".

## Summary — the numbers, not an adjective

```
1/1 upstream test ported: 1/1 (100%)
spec/: 15 examples, 0 failures — util_spec.rb (9) + gc_spec.rb (6, 3 of which are port-only extra)
test/drive_characters.rb: 68 named cases (38 step + 30 check), 33/33 checks pass, DRIVE OK — still all Extra, 0 mapped to upstream, now redundant with spec/ for coverage purposes but not identical in what it drives (UI integration vs. unit-level Util/Gc calls)
```

## Extra

- `test/drive_characters.rb` — 68 named cases (38 steps, 31 checks since
  `ca1d509` added one) driving the window, sidebar, character grid, search,
  character dialog, breakpoint and both standalone dialogs end to end;
  33/33 checks pass, `DRIVE OK`.
- `spec/gc_spec.rb`'s three mirroring cases (opening paren, opening bracket,
  no-mirror-entry for `'a'`) — pin the BidiMirroring.txt port that has no
  upstream JS test at all (gc.c's C logic predates `testUtil.js` entirely).

## Rules followed

- The prior round's stale "0/1, spec/ broken" claim is corrected in place
  here with the commit that closed it named, not silently dropped.
- The one upstream test is traced to two named port files rather than waved
  through because "the port's suite is bigger and green."
- `test/drive_characters.rb`'s 68 cases are still not credited against the
  one upstream test, even though it is real, runs, and passes — size is not
  correspondence.
- `ca1d509`'s fix is checked against the step it actually changed (the
  search screenshot), not credited for also closing the different step
  the prior round flagged (the collapsed-layout screenshot) just because
  both are screenshots — the remaining unguarded step is named as a
  residual gap, not folded into the overall "DRIVE OK" headline.
