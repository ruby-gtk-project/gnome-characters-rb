# Component parity — gnome-characters-rb

| | |
|---|---|
| Upstream | `main` @ `4b42297` |
| Port | `ruby` @ `d89d6f1` |
| Units with parity (widget/CSS/behaviour axes only) | 10 / 12 |
| Units with parity (all four axes, text included) | **0 / 12** |

The widget/CSS/behaviour read in this report leans on
`.reports/component-inventory.md`, which was re-verified file by file against
the current `origin/main` and `ruby` trees rather than trusted as written —
three of its claims were stale (see below) and are corrected here.

## Axis 1–3 (count, style, behaviour) — per unit

| Unit | Widget/CSS/behaviour | Verdict |
|---|---|---|
| App (`lib/main.rb`) | actions/accels/signals match; documented structural deviation (`Gtk::Application` + manual Adwaita init, `Adwaita::Application` broken in bindings) | parity |
| MainWindow (`lib/window.rb`) | all widgets/CSS/signals/actions present, confirmed by scan + read | parity |
| Sidebar (`lib/sidebar.rb`) | all 3 sections, 17 items, `activated` re-emit | parity |
| SidebarItem (`lib/sidebar_item.rb`) | plain attribute vs GObject enum property — correspondence, not a gap | parity |
| CharactersView (`lib/characters_view.rb`) | grid repeater, `character-selected`/`notify::loading` present | parity |
| CharacterDialog (`lib/character_dialog.rb`) | full widget tree, related-character repeater, `character.copy` action | parity |
| ShortcutsDialog (`lib/shortcuts_dialog.rb`) | all 4 items, accelerators hardcoded (documented) | parity |
| AboutDialog (`lib/about_dialog.rb`) | all fields reproduced | parity |
| ShellSearchProvider (`lib/shell_search_provider.rb`) | all 5 D-Bus methods present | parity |
| Settings (`lib/settings.rb`) | same 2 keys/defaults, JSON backend instead of compiled schema (documented, matches pilot port) | parity on behaviour; **translatable `summary`/`description` strings on the two keys are not carried at all** — see Axis 4 |
| Gc (`lib/gc.rb`) | category enum + search/lookup API on `.tsv` tables | parity — the mirrored-character "See Also" cross-ref gap this report previously carried (no binding for `g_unichar_get_mirror_char`) was closed by commit `b1ecdbc`, which ports the same underlying data (Unicode's BidiMirroring.txt) as `lib/data/mirroring.tsv` and wires it into `Gc.related_characters`; re-verified this round by reading `lib/gc.rb:584-638` and running `spec/gc_spec.rb`'s three mirroring cases directly (pass) |
| Non-widget packaging (desktop/metainfo/search-provider.ini) | **present in the current tree** (`data/org.gnome.CharactersRb.{desktop,metainfo.xml,search-provider.ini}`) | corrected from the stale inventory below — files exist, so widget/behaviour axis for these three is a pass; the **text axis is not** |

### Stale claims found in `.reports/component-inventory.md`

That file states the desktop entry, metainfo and search-provider `.ini` are
`MISSING`. They are not: `git log` shows commit `d632e53 "Add desktop entry,
metainfo and search-provider registration"` landed after the inventory was
written (`65854bc`/`5b13050` "Inventory upstream components"), and the
inventory was never regenerated. A stale report that claims a gap which has
since been closed is not a dangerous direction to be wrong in by itself, but
it means every number in that document has to be re-verified rather than
cited — which is what this report and `component-identification.md` did.

## Axis 4 — text (the one that fails)

The port's `lib/*.rb` files mark **zero** strings with any translation
marker. There is no `require "gettext"`, no `_()`/`N_()`/`n_()` call, no
`FastGettext`, anywhere in `lib/` or `exe/`. Every label a user sees —
"Copy", "Unicode", "Related Characters", every sidebar section/item title,
every dialog title, "Character copied to clipboard", the four shortcuts
items, the about dialog's strings — is a bare Ruby literal.

That makes the fourth axis fail for **all twelve units**, including the ten
marked `parity` above on the other three axes. Per the skill: "A unit has
parity when every row says parity... One gap is not a pass with a note" — the
text axis is the one gap every single unit shares, so the honest top-line
number is **0 / 12**, not 10/12. The widget/CSS/behaviour read is still worth
keeping separately because it answers a different, real question (does the
port *look* and *click* the same) — but it must not be read as "10 units have
parity."

The metainfo `<summary>` byte-mismatch this report previously flagged (the
port was missing one space after the first sentence relative to upstream's
`.in.in` source) was fixed by commit `b1ecdbc`. Re-checked this round against
upstream's actual `.po` msgids (not the `.in.in` template, which carries a
double space that `xgettext`/the translators' `.po` files normalise away) —
the port's single-space string is now byte-identical to the real msgid. See
`translation-parity.md` for the full check. The metainfo's `<releases>`
history (upstream's per-version changelog `<p>`/`<ul>` entries) is still not
reproduced in the port's metainfo at all — not a per-component gap (no
upstream `.js`/`.ui` unit owns it) but noted here since it is new text found
in this file during the re-check; filed in `translation-parity.md` as an
out-of-scope-for-this-unit observation, not a counted gap, since the port's
metainfo legitimately has its own (much shorter) release history.

## Stylesheet (Step 4)

`diff /tmp/up-characters/data/style.css lib/style.css` — byte-identical
except a single trailing blank line. Full parity on the one stylesheet file
in the app; no app-namespaced classes are unaccounted for.

## Behaviour actually firing (Step 5)

`test/drive_characters.rb` drives real signal emission for 8 of the 12
units (window, sidebar selection, characters_view rendering/search, character
dialog open/copy/see-also/close, search bar, breakpoint collapse, shortcuts
dialog, about dialog) and all 32 driven checks pass (`DRIVE OK`, re-run
directly this round, see `test-parity.md`). `spec/gc_spec.rb` (added since
the prior round) now drives Gc's search API directly too — `pizza`/`joy`/
`space` keyword search plus the three mirroring cases — run this round
(`15 examples, 0 failures`). The drive script and `spec/` together still do
**not** exercise: the ShellSearchProvider's 5 D-Bus methods, or Settings
persistence (recent-characters round-trip through a restart). Those two
units' behaviour axis is still read from source only, not driven — noted as
unverified rather than claimed.

## Summary

Widget/CSS/behaviour: 10 of 12 units read as faithful ports this round —
Gc's mirrored-character cross-ref gap from the prior round is now closed
(commit `b1ecdbc`) and re-verified by running `spec/gc_spec.rb` directly, and
the non-widget packaging files are confirmed present and byte-correct. 1 unit
(Settings) still has a translatable-string gap (the GSettings-equivalent
`summary`/`description` text was never carried, on top of an otherwise sound
JSON-backend implementation) on top of a sound implementation. Text axis: 0
of 12 — every unit's user-visible strings are untranslatable English
literals, which remains the dominant finding of this audit and is detailed
fully in `translation-parity.md`.
