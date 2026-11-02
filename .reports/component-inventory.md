# gnome-characters — upstream component inventory

Survey of `origin/main` (GJS + GtkBuilder `.ui`, libadwaita 1.9-era: `AdwSidebar`,
`AdwShortcutsDialog`, `AdwSpinner`) against what the `ruby` branch's `lib/`
currently has. No app code was written in this step.

Upstream is read with `git show origin/main:<path>`. The upstream ref is never
checked out and never merged; it is the spec.

## How upstream is laid out

Seven JS files under `src/`, four `.ui` files under `data/`, and a C library
under `lib/` (`libgc`, introspected as the `Gc` namespace) that holds all the
Unicode data and the search engine. Each UI component is split across two
files — the GJS subclass and its `.ui` template — so the component is the pair:

| Upstream pair | What each half holds |
|---|---|
| `src/window.js` + `data/window.ui` | window subclass, actions, search wiring / widget tree, menu, breakpoint |
| `src/sidebar.js` + `data/sidebar.ui` | selection API / the 17 sidebar items |
| `src/characterDialog.js` + `data/character_dialog.ui` | character state, clipboard, related search / two-page dialog tree |
| `src/charactersView.js` | custom `Gtk.Widget`, built entirely in code, no `.ui` |
| `data/shortcuts.ui` | standalone `AdwShortcutsDialog`, no backing source file |

`data/shortcuts.ui` is aliased to `shortcuts-dialog.ui` in
`data/org.gnome.Characters.data.gresource.xml`, which is how GTK's built-in
`app.shortcuts` action finds it. The menu item in `window.ui` targets
`app.shortcuts` and nothing in `src/` installs that action — the port has to
install it and build the dialog explicitly.

## Current state of `ruby`

`lib/` now holds the port itself, flat and one file per upstream source:

| Path | Upstream it ports |
|---|---|
| `lib/gnome_characters.rb` | entry point, `require_relative 'main'` |
| `lib/main.rb` | `src/main.js` |
| `lib/window.rb` | `src/window.js` + `data/window.ui` (menu included) |
| `lib/sidebar.rb` | `src/sidebar.js` + `data/sidebar.ui` |
| `lib/sidebar_item.rb` | `src/sidebarItem.js` |
| `lib/characters_view.rb` | `src/charactersView.js` |
| `lib/character_dialog.rb` | `src/characterDialog.js` + `data/character_dialog.ui` |
| `lib/shortcuts_dialog.rb` | `data/shortcuts.ui` |
| `lib/about_dialog.rb` | the `_about` method of `src/window.js` |
| `lib/shell_search_provider.rb` | `src/searchProvider.js` + `data/ShellSearchProvider2.xml` |
| `lib/util.rb` | `src/util.js` |
| `lib/gc.rb` + `lib/data/*.tsv` | `lib/gc.{c,h}` and its generated headers |
| `lib/settings.rb` | `data/org.gnome.Characters.gschema.xml` |
| `lib/style.css` | `data/style.css` |
| `lib/gnome/characters/rb/version.rb` | version constant (port only) |

So **every unit upstream has a counterpart on `ruby`**, and the survey's job is
now to name what is still missing inside them rather than which files are
absent. The three standing gaps are translations (`po/` does not exist), the
seven app-shipped `characters-*-symbolic` icons (referenced by the sidebar and
the empty-state page but not shipped or registered with the icon theme), and
the conditional `devel` CSS class on the window for the `…Devel` app id.

Two units deliberately diverge from upstream's mechanism rather than its
behaviour, and both are documented in the file's own header comment:
`lib/gc.rb` reimplements libgc in Ruby over TSV tables converted from the
generated headers, and `lib/settings.rb` keeps the schema's keys, defaults and
semantics in a JSON file under `XDG_CONFIG_HOME` instead of requiring a
compiled GSettings schema to be installed before the app will run.
`lib/characters_view.rb` likewise draws into a `Gtk::DrawingArea` inside a
`Gtk::ScrolledWindow` instead of subclassing `Gtk::Widget` and implementing
`Gtk::Scrollable`.

The house shape in the pilot (`gnome-contacts-rb`) is flat `lib/*.rb`, one
upstream source file per file, each opening with `# frozen_string_literal: true`
then `require 'adwaita'` and `require_relative` siblings, a class comment
naming the upstream file, and widgets as memoized accessors configured in `.tap`
blocks. Every file above follows that.
---

## Components, in the order a user meets them

### 1. `src/main.js` → `lib/main.rb` — the application

Not a widget class, but it owns the app id, the color scheme, the actions and
accelerators, the D-Bus registration and the search-provider export.

| Item | × | Notes |
|---|---:|---|
| `Gtk.Application` (upstream `Adw.Application`) | 1 | `Adwaita::Application` is broken in the Ruby bindings — use `Gtk::Application`; app id, `resource_base_path`, `ApplicationFlags.FLAGS_NONE`, app name "Characters" |
| action `app.quit` | 1 | accel `<Primary>q` |
| accel for `win.find` | 1 | `<Primary>f`, set on the application |
| action `app.shortcuts` | 1 | referenced by the primary menu; GTK's built-in resource-driven action upstream, must be installed by hand in the port |
| `Adw.StyleManager` color scheme | 1 | `PREFER_LIGHT` |
| `devel` CSS class on the window | 1 | applied only when the app id ends in `Devel` |
| inactivity timeout | 1 | 10 s when launched as a D-Bus service |
| `vfunc_dbus_register` | 1 | exports the search provider at `<path>/SearchProvider` |

Present on `ruby`: **yes** — `lib/main.rb`: `Gtk::Application`, `app.quit` and
`app.shortcuts`, the `win.find` accel, the `PREFER_LIGHT` style manager, the
stylesheet, and the search-provider export over `app.dbus_connection`. Gap: the
conditional `devel` CSS class for the `…Devel` app id is not applied.

### 2. `src/window.js` + `data/window.ui` → `lib/window.rb` — the main window

| Widget | × | CSS | Signals / behaviour | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (conditional) | `vfunc_map` picks the start page | 800×600 default, 360×294 minimum |
| `Adw.NavigationSplitView` | 1 | — | — | `collapsed` under the breakpoint |
| `Adw.NavigationPage` | 2 | — | — | sidebar page titled "Characters"; content page tagged `content`, title tracks the selected item / "Search Result" |
| `Adw.ToolbarView` | 2 | `view` (content one) | — | one per pane |
| `Adw.HeaderBar` | 2 | — | — | one per pane |
| `Gtk.ToggleButton` | 1 | — | `toggled` → focus or clear the entry, flips `searchActive` | `edit-find-symbolic`, tooltip "Search", bound bidirectionally to the search bar's `search-mode-enabled` |
| `Gtk.MenuButton` | 1 | — | — | `open-menu-symbolic`, tooltip "Main Menu", `primary` true, menu model `primary_menu` |
| `Gtk.SearchBar` | 1 | — | — | holds the entry |
| `Gtk.SearchEntry` | 1 | — | `search-changed`, `search-started`, `stop-search`, `activate` | placeholder "Search characters", `hexpand`, `set_key_capture_widget(window)` |
| `Gtk.ScrolledWindow` | 2 | `character-list-scroll` (content one) | `vadjustment` reset to 0 on sidebar activation | `hscrollbar-policy: never` |
| `Gtk.Stack` | 1 | — | — | `mainStack`, crossfade, four pages |
| `Adw.StatusPage` | 2 | — | — | empty state "No Recent Characters" / "Characters will appear here if you use them" (`characters-punctuation-symbolic`); error-ish state "No Results" / "Try a different search" (`system-search-symbolic`) |
| `Adw.Spinner` | 1 | — | — | the `loading` stack page |
| `Adw.Breakpoint` | 1 | — | — | `max-width: 500px` → split view collapsed, sidebar `mode: page` |
| `Gio.Menu` (`primary_menu`) | 1 item ×2 | — | — | "_Keyboard Shortcuts" → `app.shortcuts`; "_About Characters" → `win.about` |
| action `win.about` | 1 | — | — | presents the about dialog |
| action `win.find` | 1 | — | — | toggles the search button |

Property: `max-recent-characters` (uint, default 100), bound to GSettings.
State: `recent-characters` read from and written back to GSettings.

Repeaters: none. Conditional: the `devel` class; the stack page chosen by
search state, category and result count.

Present on `ruby`: **yes** — `lib/window.rb` carries the split view, both
toolbar views and header bars, the search toggle and entry, the menu button,
the four-page stack with both status pages and the `Adwaita::Spinner` loading
page, the `Adwaita::Breakpoint`, and the `win.about` / `win.find` actions.

### 3. `data/window.ui` menu → folded into `lib/window.rb`

Two-item `Gio::Menu` section. Not a separate port file; listed because it is a
component no widget subclass owns upstream.

Present on `ruby`: **yes**.

### 4. `src/sidebar.js` + `data/sidebar.ui` → `lib/sidebar.rb` — the category sidebar

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | emits `activated` | `vexpand`, `hexpand`; `mode` property proxies the inner sidebar's `Adw.SidebarMode` |
| `Adw.Sidebar` | 1 | — | `activated` → re-emitted | `selected` index is the selection API; `Gtk.INVALID_LIST_POSITION` unselects all |
| `Adw.SidebarSection` | 3 | — | — | untitled (Recently Used), "Emojis", "Letters & Symbols" |
| `SidebarItem` (app class, see 5) | 17 | — | — | 1 recent + 8 emoji + 8 letters/symbols |

Behaviour to reproduce: `restoreSelection`, `itemByName(name)` over the 17 slugs
(`recent`, `smileys`, `people`, `animals`, `food`, `activities`, `travel`,
`objects`, `symbols`, `flags`, `punctuation`, `arrows`, `bullets`, `pictures`,
`currency`, `math`, `latin`), `selectRowByName`, `unselectAll`, and
`lastSelectedItem` tracking.

Repeaters: the 17 items are written out one by one upstream; in the port they
are naturally one repeater over a constant table of `[slug, icon, title, category]`.

Present on `ruby`: **yes**.

### 5. `src/sidebarItem.js` → `lib/sidebar_item.rb` — one sidebar row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.SidebarItem` | 1 | — | — | adds one property, `category` (a `Gc.Category`, default `NONE`) |

Its `icon-name` and `title` come from `sidebar.ui`. The 17 icon names are
`document-open-recent-symbolic`, `emoji-people-symbolic`, `emoji-body-symbolic`,
`emoji-nature-symbolic`, `emoji-food-symbolic`, `emoji-travel-symbolic`,
`emoji-activities-symbolic`, `emoji-objects-symbolic`, `emoji-symbols-symbolic`,
`emoji-flags-symbolic`, and the seven app-shipped
`characters-{punctuation,arrow,bullet,picture,currency,math,latin}-symbolic`.

Present on `ruby`: **yes** — `lib/sidebar_item.rb`. Gap: the seven app-shipped
`characters-*-symbolic` icons are referenced by name but are not in the port and
nothing adds an icon search path, so those seven rows render iconless.

### 6. `src/charactersView.js` → `lib/characters_view.rb` — the character grid

A custom `Gtk.Widget` implementing `Gtk.Scrollable`, drawn by hand. No `.ui`.
The single largest unit, and the one with no declarative half at all.

| Item | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Widget` subclass | 1 | — | emits `character-selected(string)` | `overflow: HIDDEN`; implements `Gtk.Scrollable` with overridden `vadjustment`/`hadjustment`/`vscroll-policy`/`hscroll-policy` |
| `Gtk.Adjustment` | 2 | — | `value-changed` → `queue_draw` | not widgets; the scroll state |
| `Gtk.GestureClick` (controller) | 1 | — | `pressed` → hit-test a cell, `released` → emit `character-selected` | the only input path into the dialog |
| `CharacterListRow` (plain object) | *N rows* | — | — | one per visible row of cells; repeater driven by the character list and `cellsPerRow` |

Properties: `loading` (drives the window's spinner page), `baseline` (whether to
draw the baseline rule).

Drawing, all in `vfunc_snapshot` / `CharacterListRow#snapshot`: a 50 px base cell
size scaled from the Pango font description, a `borders` style color baseline rule
per row at `BASELINE_OFFSET`, each glyph laid out and baseline-aligned, and for
invisible or unrenderable characters a translucent bounding box (text color at
alpha 0.05) plus the capitalized character name drawn at 0.8 × font size, word
wrapped, ellipsized, centered, falling back to "Unassigned".

Layout: `vfunc_measure` (3 columns minimum), `vfunc_size_allocate` reflowing when
cells-per-row changes and reconfiguring both adjustments.

Search: `searchByCategory` (with `baseline` on only for `category <= LETTER_LATIN`),
`searchByKeywords` returning a result count, `_searchByScripts`, `cancelSearch`
over a `Gio::Cancellable`, and `populateScripts` — which reads
`org.gnome.desktop.input-sources` (or the XDG settings portal under Flatpak),
resolves layouts to languages via `GnomeDesktop.XkbInfo`, optionally asks IBus
for engine languages, maps languages to Unicode scripts and always prepends
Latin while excluding Han.

Present on `ruby`: **yes**.

### 7. `src/characterDialog.js` + `data/character_dialog.ui` → `lib/character_dialog.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` (template root) | 1 | — | emits `character-copied(string)` | 360×500 content size; `title` is the capitalized character name, or `U+XXXX`, or "Unknown character name" |
| `Adw.ToastOverlay` | 1 | — | — | hosts the copy confirmation |
| `Adw.ToastOverlay` → `Adw.Toast` | 1 | — | — | "Character copied to clipboard", 2 s timeout |
| `Adw.NavigationView` | 1 | — | `navigation.push` target `'related'`, `pop` on related-row activation | two pages |
| `Adw.NavigationPage` | 2 | — | `hidden` on the related page → repopulate | main page title bound to the dialog title; second tagged `related`, titled "See Also" |
| `Adw.ToolbarView` | 2 | — | — | one per page |
| `Adw.HeaderBar` | 2 | — | — | one per page |
| `Gtk.ScrolledWindow` | 2 | — | — | `hscrollbar-policy: never`, `vexpand` |
| `Gtk.Box` | 1 | — | — | vertical, `valign: center` |
| `Gtk.Stack` | 1 | — | — | pages `character` / `missing`, chosen by `get_unknown_glyphs_count` |
| `Gtk.Label` (`characterLabel`) | 1 | `character-label` | — | the glyph itself; `ellipsize: end`, centered; takes the view's font description |
| `Gtk.Label` (`missingLabel`) | 1 | — | — | "%s is not included in %s", wrapped at 28 chars, centered |
| `Gtk.Button` ("_Copy Character") | 1 | `pill` | action `character.copy` | 18 px top/bottom margins, centered, `use-underline` |
| `Adw.Clamp` | 2 | — | — | 18 px margins (36 px top/bottom on the related page), `valign: center` |
| `Gtk.ListBox` | 2 | `boxed-list` | — | `selection-mode: none`; the detail list and the related list |
| `Adw.ActionRow` (`detailRow`) | 1 | — | — | title "Unicode"; hidden for composite characters |
| `Gtk.Label` (`detailLabel`) | 1 | `dim-label` | — | `U+%04s`, selectable |
| `Adw.ActionRow` (`seeAlsoRow`) | 1 | — | `navigation.push` → `'related'` | title "_See Also", activatable, `use-underline`; visible only when the related search found anything |
| `Gtk.Image` | 1 | — | — | `go-next-symbolic`, the see-also chevron |
| `Adw.ActionRow` (related rows) | *N* | — | `activated` → set that character and pop | **repeater** over the related search result; each adds a prefix `Gtk.Label` of the glyph, `width_request: 45`, centered |
| `Gtk.Label` (related prefix) | *N* | — | — | one per related row |
| action group `character` with `character.copy` | 1 | — | — | copies to `Gdk.Display.get_default().get_clipboard()`, emits `character-copied`, shows the toast |

Conditional: `detailRow` hidden for composite characters; `seeAlsoRow` hidden
until the related search returns; the stack page by glyph availability.

Present on `ruby`: **yes**.

### 8. `data/shortcuts.ui` → `lib/shortcuts_dialog.rb` — keyboard shortcuts

Standalone `AdwShortcutsDialog`, no backing source file; reached through
`app.shortcuts`.

| Widget | × | Notes |
|---|---:|---|
| `Adw.ShortcutsDialog` | 1 | — |
| `Adw.ShortcutsSection` | 1 | title "General" (msgctxt `shortcut window`) |
| `Adw.ShortcutsItem` | 4 | "Open Main Menu" (literal accelerator `F10`); "Search" (`action-name win.find`); "Show Keyboard Shortcuts" (`app.shortcuts`); "Quit" (`app.quit`) |

Three of the four items name an action rather than an accelerator, so their
accelerators come from the application's accel map — `<Primary>f` and
`<Primary>q` must be registered for them to render. The pilot's
`lib/shortcuts_dialog.rb` is the shape to copy, including the quirk that
`Adwaita::ShortcutsItem.new(title, accelerator)` takes positional arguments.

Present on `ruby`: **yes**.

### 9. about dialog — in `src/window.js` → folded into `lib/window.rb` (or `lib/about_dialog.rb`)

| Widget | × | Notes |
|---|---:|---|
| `Adw.AboutDialog` | 1 | application name "Characters", app icon = app id, developer name "The GNOME Project", three designers, two developers, `translator-credits`, copyright "Copyright 2014-2018 Daiki Ueno", `Gtk.License.GPL_2_0`, version, website `https://apps.gnome.org/Characters/`, issue URL |

Present on `ruby`: **yes**.

### 10. `src/searchProvider.js` + `data/ShellSearchProvider2.xml` → `lib/shell_search_provider.rb`

Not on-screen in this app, but a user-facing surface (GNOME Shell overview
results) and the pilot ports its equivalent.

| Item | Notes |
|---|---|
| D-Bus object on `ShellSearchProvider2` | `GetInitialResultSetAsync`, `GetSubsearchResultSetAsync`, `GetResultMetas`, `ActivateResult`, `LaunchSearch` |
| result metas | capitalized name or "Unknown character name"; description `U+%s` for non-composite; `clipboardText`; `icon-data` rendered from the glyph |
| `Gio.Notification` | "Character copied" / "Character was copied successfully", sent from `ActivateResult` |
| `LaunchSearch` | activates the app and calls the window's `setSearchKeywords` |
| `data/org.gnome.Characters.search-provider.ini`, `.busname`, `.service.in` | the registration files that make the above reachable |

Present on `ruby`: **yes**.

### 11. `src/util.js` → `lib/util.rb`

No widgets; the helpers every other unit needs.

| Helper | Used by |
|---|---|
| `initActions` | main, window, dialog |
| `getSettings` | main, characters view |
| `isFlatpak`, `getInputSources` | characters view |
| `capitalize` / `capitalizeWord` (CJK acronym and `IDEOGRAPH-`/`SELECTOR-` prefix special cases) | dialog, view, search provider |
| `toCodePoint` (surrogate pair aware) | dialog, search provider |
| `searchResultToArray` | view, search provider |
| `characterToIconData` (GSK render to texture, GL renderer with a Cairo fallback) | search provider |

Present on `ruby`: **yes**.

### 12. `lib/gc.*` (the C library) → `lib/gc.rb` + generated data

The `Gc` namespace every other unit calls. Upstream it is C with Python
generators producing `blocks.h`, `confusables.h`, `emoji.h`, `hangul.h`,
`languages.h`, `names.h`, `scripts.h` from the Unicode data files.

| Surface | Notes |
|---|---|
| `Gc.Category` enum | 19 values: `NONE`, `LETTER`, the 7 `LETTER_*`, `EMOJI`, the 8 `EMOJI_*` |
| `Gc.SearchCriteria` | `new_category`, `new_keywords`, `new_scripts`, `new_related` |
| `Gc.SearchContext` | `search(max_matches, cancellable, cb)`, `search_finish`, `is_finished`; `Gc.SearchFlag.WORD` |
| `Gc.SearchResult` | `len`, `Gc.search_result_get(result, i)` |
| character predicates | `character_name`, `character_is_composite`, `character_is_invisible` |
| language/script | `get_current_language`, `get_scripts_for_language` |

Present on `ruby`: **yes**, as a reimplementation — `lib/gc.rb` with the tables
as `lib/data/*.tsv` converted one-for-one from upstream's generated headers.
The blocker below is settled this way: nothing is loaded through
introspection, so there is no `Gc` typelib dependency.

### 13. GSettings → `lib/settings.rb`

`data/org.gnome.Characters.gschema.xml`, schema `org.gnome.Characters`, path
`/org/gnome/Characters/`:

| Key | Type | Default | Read by |
|---|---|---|---|
| `recent-characters` | `as` | `[]` | window (recent page, `addToRecent`) |
| `max-recent-characters` | `u` | 100 | window, bound to its own property |

Also read, not owned: `org.gnome.desktop.input-sources` key `sources`, via
GSettings or the XDG settings portal.

Present on `ruby`: **yes**.

### 14. Stylesheet → `lib/style.css` loaded by a `Gtk::CssProvider`

`data/style.css` defines one class: `.character-label` (`font-size: 7em;
font-weight: bold`). Applied in `character_dialog.ui`.

The other classes the app uses (`view`, `pill`, `boxed-list`, `dim-label`,
`devel`) come from libadwaita, not from this file. `character-list-scroll` is
applied in `window.ui` and **defined nowhere** — dead upstream; the port should
either drop it or note it.

Present on `ruby`: **yes**.

### 15. Translations → `po/`

75 locales in `po/LINGUAS`. `po/POTFILES.in` lists 13 files: the four `.ui`
files, the desktop, gschema and metainfo templates, and six of the seven JS
files (`src/util.js` has no translatable strings).

Translatable strings live in: `window.ui` (menu labels, tooltips, pane title,
placeholder, both status pages), `sidebar.ui` (two section titles + 17 item
titles), `shortcuts.ui` (section + four item titles, msgctxt `shortcut window`),
`character_dialog.ui` ("Unicode", "_See Also", "See Also", "_Copy Character"),
`window.js` (about dialog fields, "Search Result", `translator-credits`),
`characterDialog.js` ("Unknown character name", "Character copied to clipboard",
"%s is not included in %s"), `charactersView.js` ("Unassigned"),
`searchProvider.js` ("Unknown character name", "U+%s", "Character copied",
"Character was copied successfully"), `sidebarItem.js`, `main.js` ("Characters").

Present on `ruby`: **no** — there is still no `po/` on the branch and no gettext
wiring; every string in `lib/` is a bare Ruby literal. Translation parity is its
own step; recorded here so the string sites are known.

---

## Summary

| # | Upstream file(s) | Port file | Kind | Exists on `ruby` |
|---:|---|---|---|---|
| 1 | `src/main.js` | `lib/main.rb` | application | yes |
| 2 | `src/window.js` + `data/window.ui` | `lib/window.rb` | window | yes |
| 3 | `data/window.ui` `primary_menu` | in `lib/window.rb` | menu | yes |
| 4 | `src/sidebar.js` + `data/sidebar.ui` | `lib/sidebar.rb` | sidebar | yes |
| 5 | `src/sidebarItem.js` | `lib/sidebar_item.rb` | row | yes (icons missing) |
| 6 | `src/charactersView.js` | `lib/characters_view.rb` | custom widget / page | yes (DrawingArea, not Gtk.Scrollable) |
| 7 | `src/characterDialog.js` + `data/character_dialog.ui` | `lib/character_dialog.rb` | dialog | yes |
| 8 | `data/shortcuts.ui` | `lib/shortcuts_dialog.rb` | dialog | yes |
| 9 | `src/window.js` `_about` | `lib/about_dialog.rb` | dialog | yes |
| 10 | `src/searchProvider.js` + `data/ShellSearchProvider2.xml` | `lib/shell_search_provider.rb` | D-Bus service | yes |
| 11 | `src/util.js` | `lib/util.rb` | helpers | yes |
| 12 | `lib/gc.{c,h}` + generated headers | `lib/gc.rb` | data/search engine | yes (Ruby reimplementation + TSV tables) |
| 13 | `data/org.gnome.Characters.gschema.xml` | `lib/settings.rb` | settings | yes (JSON file, not GSettings) |
| 14 | `data/style.css` | `lib/style.css` | stylesheet | yes |
| 15 | `po/` (75 locales, 13 POTFILES) | `po/` | translations | no |

Empty states: two (`No Recent Characters`, `No Results`). Loading state: one
(`Adw.Spinner`). Error states: none surfaced to the user — upstream logs search
failures and leaves the view as it is.

## Blockers, as settled

1. **No `Gc`.** ~~Settled~~: `lib/gc.rb` reimplements libgc in Ruby over
   `lib/data/*.tsv`, converted from upstream's generated headers. No typelib.
2. **Very new libadwaita widgets.** Settled: `Adwaita::Sidebar`,
   `Adwaita::SidebarSection`, `Adwaita::SidebarItem`, `Adwaita::Spinner`,
   `Adwaita::Breakpoint`/`BreakpointCondition.parse` and
   `Adwaita::ShortcutsDialog` are all in use in the dev shell's bindings.
3. **A hand-drawn scrollable widget.** Settled by substitution rather than by
   subclassing: `lib/characters_view.rb` draws into a `Gtk::DrawingArea` sized
   to the whole list inside a `Gtk::ScrolledWindow`, so GTK scrolls it and no
   `Gtk::Scrollable` vfuncs are overridden from Ruby.
4. **`GnomeDesktop` and `IBus`.** Open. `Util.getInputSources`' equivalent is
   in `lib/util.rb`; the layout-to-language resolution that upstream does
   through `GnomeDesktop.XkbInfo` (and optionally IBus) still needs confirming
   against the dev shell's typelibs.

## Open gaps

| Gap | Where |
|---|---|
| no `po/`, no gettext — 75 locales and 13 POTFILES upstream | whole port |
| seven `characters-*-symbolic` icons not shipped, no icon search path | `lib/sidebar.rb`, `lib/window.rb` empty-state page |
| `devel` CSS class not applied for the `…Devel` app id | `lib/main.rb` |
| script search's language resolution (`GnomeDesktop.XkbInfo`, IBus) | `lib/characters_view.rb`, `lib/util.rb` |
