# Component identification — gnome-characters-rb

| | |
|---|---|
| Upstream | `main` @ `4b42297` |
| Port | `ruby` @ `d89d6f1` |

Upstream has no `.ui`/`.blp` files for most of the app except `data/window.ui`,
`data/sidebar.ui`, `data/character_dialog.ui`, `data/shortcuts.ui` — read
first, per the skill's Step 1 — plus two programmatic units with no
declarative file: the `about` dialog (built inline in `src/window.js`) and the
D-Bus search provider (`src/searchProvider.js` + `data/ShellSearchProvider2.xml`).

## Unit list (the order a user meets them)

1. **App** — `src/main.js` → `lib/main.rb`
2. **MainWindow** — `src/window.js` + `data/window.ui` → `lib/window.rb`
3. **Sidebar** — `src/sidebar.js` + `data/sidebar.ui` → `lib/sidebar.rb`
4. **SidebarItem** — `src/sidebarItem.js` → `lib/sidebar_item.rb`
5. **CharactersView** — `src/charactersView.js` → `lib/characters_view.rb`
6. **CharacterDialog** — `src/characterDialog.js` + `data/character_dialog.ui` → `lib/character_dialog.rb`
7. **ShortcutsDialog** — `data/shortcuts.ui` (no backing `.js`) → `lib/shortcuts_dialog.rb`
8. **AboutDialog** — inline in `src/window.js`'s `_about()` → `lib/about_dialog.rb`
9. **ShellSearchProvider** — `src/searchProvider.js` + `data/ShellSearchProvider2.xml` → `lib/shell_search_provider.rb`
10. **Settings** — `data/org.gnome.Characters.gschema.xml` → `lib/settings.rb`
11. **Gc** (native support library) — `lib/gc.c`/`lib/gc.h` + `gen-*.py` tables → `lib/gc.rb`
12. **Util** — `src/util.js` → `lib/util.rb`

## Widget scan, both trees (component-scan.sh, gir-symbols.sh backed)

| Widget type | Upstream × | Port × |
|---|---:|---:|
| `Gtk.ScrolledWindow` | 4 | 5 |
| `Gtk.Label` | 4 | 4 |
| `Adw.ToolbarView` | 4 | 4 |
| `Adw.NavigationPage` | 4 | 4 |
| `Adw.HeaderBar` | 4 | 4 |
| `Adw.ActionRow` | 3 | 3 |
| `Gtk.Stack` | 2 | 2 |
| `Gtk.ListBox` | 2 | 2 |
| `Adw.StatusPage` | 2 | 2 |
| `Adw.Dialog` | 2 | — |
| `Adw.Clamp` | 2 | 2 |
| `Adw.ApplicationWindow` | 2 | — |
| `Gtk.Image` | 1 | — |

Full totals: upstream 89 scan rows, port 78 scan rows across 12 mapped files.
The counts are close enough on the widget axis that they corroborate, not
replace, the per-file read below — the scan is a lead, not a verdict, and does
not see loop-built rows (the sidebar's 17 items, the character grid's cells,
the related-character repeater) or runtime CSS.

## Non-widget packaging artifacts — the part this skill also owes

`component-identification`'s scope explicitly includes GSettings schemas,
desktop entries, AppStream metainfo and the `po/` catalogue, because a user
reaches them (the shell search tile, the `Super`-key launcher, the software
center) without ever opening the app's window.

| Upstream file | Port counterpart | Found |
|---|---|---|
| `data/org.gnome.Characters.desktop.in.in` | `data/org.gnome.CharactersRb.desktop` | **present** — file exists in the current tree. (The repo's own `.reports/component-inventory.md` claims this file is MISSING; it is not — that claim is stale, written before commit `d632e53 "Add desktop entry, metainfo and search-provider registration"` and never updated. See `.reports/accountability-ensurance.md`.) |
| `data/org.gnome.Characters.metainfo.xml.in.in` | `data/org.gnome.CharactersRb.metainfo.xml` | **present**, same staleness note |
| `data/org.gnome.Characters.search-provider.ini` | `data/org.gnome.CharactersRb.search-provider.ini` | **present**, same staleness note |
| `data/org.gnome.Characters.gschema.xml` | none — reimplemented as `lib/settings.rb` (JSON file backend) | no `.gschema.xml` on either side of the Settings unit; this is a correspondence per `component-parity`, not a gap, as long as the two translatable keys (`summary`/`description` on `recent-characters` / `max-recent-characters`) are carried — see translation-parity report, they are not |
| `po/*.po`, `po/LINGUAS`, `po/POTFILES.in` (84 files) | none | **confirmed missing** — no `po/` directory anywhere in the tree, no `.po`, no `LINGUAS`, no `.pot`. See translation-parity report. |
| `data/org.gnome.Characters.data.gresource.xml`, `src/org.gnome.Characters.src.gresource.xml.in` | none | correspondence, confirmed by reading the whole tree — the port builds every widget in Ruby code (house style) and has no `.ui`/`.blp` file anywhere, so there is no bundle for a manifest to list |

## Build/test registration cross-check

`tests/meson.build` registers exactly **one** GJS test, named `Util`, running
`tests/testUtil.js` under `gjs_console`. `tests/meson.build` also lists a
second, disabled suite (`smoke_test.py`) behind an explicit
`subdir_done()`/`# FIXME: fix smoke_test.py: it's still using python2 and not
tested for long time`. It is upstream's own dead test, unreachable by `meson
test`, so upstream itself has never run it either — the census counts what
upstream actually ships as a passing test, which this is not.

`testUtil.js` exercises two units that both have Ruby counterparts:

- `Util.characterToIconData` → `lib/util.rb:63` `Util.character_to_icon_data`
- `Gc.SearchCriteria`/`Gc.SearchContext` search (`"pizza"` → 🍕, `"joy"` → 😂,
  `"space"` → 0 results) → `lib/gc.rb`'s search API

Both exist in the port. Both are now exercised directly by `spec/util_spec.rb`
and `spec/gc_spec.rb` (added since this report was first written, commit
`3fc46f8`) — re-run this round (`15 examples, 0 failures`). See the
test-parity report, which was itself stale on this point and has been
corrected this round.
