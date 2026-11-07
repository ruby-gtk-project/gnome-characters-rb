# Component parity — gnome-characters-rb

| | |
|---|---|
| Upstream | `main` @ `4b42297` |
| Port | `ruby` @ `686d2f1` |
| Units with parity (widget/CSS/behaviour axes only) | 9 / 12 |
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
| Gc (`lib/gc.rb`) | category enum + search/lookup API on `.tsv` tables | parity, with one documented absence (mirrored-character "See Also" cross-refs — no binding for `g_unichar_get_mirror_char`); real gap, filed correctly as a gap rather than excused |
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

That makes the fourth axis fail for **all twelve units**, including the nine
marked `parity` above on the other three axes. Per the skill: "A unit has
parity when every row says parity... One gap is not a pass with a note" — the
text axis is the one gap every single unit shares, so the honest top-line
number is **0 / 12**, not 9/12. The widget/CSS/behaviour read is still worth
keeping separately because it answers a different, real question (does the
port *look* and *click* the same) — but it must not be read as "9 units have
parity."

Additionally, the three packaging files that do exist (`.desktop`,
`.metainfo.xml`) were **reworded**, not transcribed, relative to upstream:

```
upstream: Characters is a simple utility application to find and insert
          unusual characters.  It allows you to quickly find the character
          you are looking for by searching for keywords.
port:     Characters is a simple utility application to find and insert
          unusual characters. It allows you to quickly find the character
          you are looking for by searching for keywords.
```

One space character differs (upstream has two spaces after the first
sentence). As a gettext key this is already a different message — see
`translation-parity.md` for the full diff and the msgid-identity rule.

## Stylesheet (Step 4)

`diff /tmp/up-characters/data/style.css lib/style.css` — byte-identical
except a single trailing blank line. Full parity on the one stylesheet file
in the app; no app-namespaced classes are unaccounted for.

## Behaviour actually firing (Step 5)

`test/drive_characters.rb` drives real signal emission for 8 of the 12
units (window, sidebar selection, characters_view rendering/search, character
dialog open/copy/see-also/close, search bar, breakpoint collapse, shortcuts
dialog, about dialog) and all 32 driven checks pass (`DRIVE OK`, see
`test-parity.md`). It does **not** drive: the ShellSearchProvider's 5 D-Bus
methods, Settings persistence (recent-characters round-trip through a
restart), or Gc's search/lookup API directly. Those three units' behaviour
axis is therefore read from source only, not driven — noted as unverified
rather than claimed.

## Summary

Widget/CSS/behaviour: 9 of 12 units read as faithful ports, 2 real documented
gaps (Gc's mirrored-character cross-ref, the packaging files' stale report),
1 unit (Settings) with a translatable-string gap on top of a sound
implementation. Text axis: 0 of 12 — every unit's user-visible strings are
untranslatable English literals, which is the dominant finding of this audit
and is detailed fully in `translation-parity.md`.
