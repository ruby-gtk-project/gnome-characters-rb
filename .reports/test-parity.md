# Test parity — gnome-characters-rb

| | |
|---|---|
| Upstream | `main` @ `4b42297` |
| Port | `ruby` @ `686d2f1` |
| Upstream tests | 1 |
| Ported | 0 |
| Gaps | 1 |
| Test command run | `nix develop --command xvfb-run -a ruby test/drive_characters.rb` (DRIVE OK, 32/32) and `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run([...])'` (**0 examples, 2 errors**) |

## Step 1 — census

Upstream's `tests/meson.build` registers exactly one test, named `Util`,
running `gjs_console tests/testUtil.js` under the `default` test setup with
`xvfb-run`. A second suite (`smoke_test.py`) is listed in the same file but
is behind an explicit early `subdir_done()` guarded by `# FIXME: fix
smoke_test.py: it's still using python2 and not tested for long time` —
upstream itself never runs it, so it is not part of the one test upstream
actually has.

`testUtil.js`'s single test asserts two properties:

1. `Util.characterToIconData(e)` returns a `GLib.Variant` for three emoji
   (🍕, 🤌, 🥰) and `null` for seven whitespace-only strings.
2. `Gc.SearchContext` search (via `Gc.SearchCriteria.new_keywords`, flag
   `WORD`) for `"pizza"` includes 🍕, for `"joy"` includes 😂, and for
   `"space"` returns zero results.

**This is not the "upstream has no tests" trivial case.** Upstream has
exactly 1 registered, CI-reachable test, and it pins real behaviour in two
units the port also has (`lib/util.rb#character_to_icon_data`, `lib/gc.rb`'s
search API).

## Step 2 — the ledger

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `tests/testUtil.js` (meson target `Util`) | `Util.characterToIconData` returns a Variant for emoji / nil for whitespace; `Gc` keyword search finds pizza/joy, excludes "space" | — | **gap** |

**Behaviour still owed:** nothing in the port's test suite calls
`Util.character_to_icon_data` or exercises `Gc`'s search API directly and
asserts on the result. `lib/shell_search_provider.rb` calls
`Util.character_to_icon_data` as part of its own logic, and
`test/drive_characters.rb` drives the UI's search bar (which goes through
`Gc` internally), but neither assertion in `testUtil.js` — "whitespace
produces no icon data", "searching 'space' finds nothing" — has a named,
re-runnable counterpart anywhere in the port. A regression in either rule
would pass the whole port suite today.

## Step 4 — prove it (and where it fails)

Two separate things claim to be "the port's tests," and both were run
directly rather than taken on faith:

### `test/drive_characters.rb` — real, passes, but is not upstream's test

```
$ nix develop --command xvfb-run -a ruby test/drive_characters.rb
...
32 of 32 checks passed
DRIVE OK
```

This genuinely runs and genuinely passes — 38 named `step`s, 32 of which
also call `check(...)` for a concrete assertion, covering roughly 10 of the
12 units identified in `component-identification.md` (window, sidebar,
characters_view/grid, search, character dialog + copy + see-also, breakpoint
collapse, shortcuts dialog, about dialog). `test-census.sh` censuses 68 named
cases in this one file (38 `step` + 30 `check`, the same double-count shape
the skill's `planify-rb` worked example warns about — the assertion unit here
is `check`, confirmed by reading `test/gtk_driver.rb:78`).

**None of these 68 cases maps to upstream's one test.** They were written
for the port, from the port's own UI, not from `testUtil.js`. This is
exactly the shape the skill's worked example describes: a bigger, green,
passing suite with zero inherited parity. It goes under `## Extra` below, not
against the one upstream row.

### `spec/` — registered as "the specs" and does not run at all

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; \
    exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
NOTE: kettle-test isn't installed; running with plain RSpec.
An error occurred while loading spec_helper.
Failure/Error: require "gnome/characters/rb"
LoadError:
  cannot load such file -- gnome/characters/rb
0 examples, 0 failures, 2 errors occurred outside of examples
```

This is not an environment problem on my end — `RUBYLIB` inside the dev
shell correctly includes `lib/` (verified: `ruby -e 'puts $LOAD_PATH'` lists
the repo's `lib` first). The failure is structural: `spec/spec_helper.rb:43`
requires `"gnome/characters/rb"`, which resolves to
`lib/gnome/characters/rb.rb` — a file that **does not exist**. The tree only
has `lib/gnome/characters/rb/version.rb` (the kettle-jem gem-name scaffold).
Nobody wrote the loader file the generated spec helper expects.

The second, and larger, problem: even if that `require` were fixed, `spec/`
contains **zero** test files — only `spec/README.md` and `spec/spec_helper.rb`.
There is no `*_spec.rb` anywhere in the tree. **A suite that has never been
executed, because it cannot load, with no tests written under it even if it
could, is a gap, not a pass — and it must be said plainly, which is why this
line exists:** the gem-packaging boilerplate added a test *framework* and
left it entirely empty and broken, and nothing in this repo's history shows
it ever ran successfully.

## Summary — the numbers, not an adjective

```
1/1 upstream test ported: 0/1 (0%)
test/drive_characters.rb: 68 named cases (38 step + 30 check), 32/32 checks pass, DRIVE OK — all Extra, 0 mapped to upstream
spec/: 0 examples runnable; spec_helper.rb raises LoadError on every invocation
```

## Extra

- `test/drive_characters.rb` — 68 named cases (38 steps, 30 checks) driving
  the window, sidebar, character grid, search, character dialog, breakpoint
  and both standalone dialogs end to end; 32/32 checks pass, `DRIVE OK`. Real,
  runnable, passing — and entirely outside the upstream-test count because
  none of it was written from `tests/testUtil.js`.

## Rules followed / gaps not excused

- The one upstream test is recorded as a gap, not waved through because the
  port's own suite is bigger and green — matching this skill's explicit
  warning against exactly that substitution.
- The broken `spec/` suite is reported as broken, not glossed as "specs
  exist." A test file that cannot load is not evidence of test coverage.
