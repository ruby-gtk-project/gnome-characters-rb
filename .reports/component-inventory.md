# Component inventory — gnome-characters-rb

Surveyed against `origin/main` (GJS/Vala upstream), compared to `lib/` on the
`ruby` branch. One section per upstream unit, in the order a user meets it:
application, main window, sidebar, character grid, character dialog, the two
standalone dialogs, the search provider, then the two non-UI support units
(settings, the `Gc` library).

Legend for **Status**: `EXISTS` — the `lib/*.rb` file is present and its
widget tree / signals / actions were read and match upstream's unit.
`MISSING` — no `lib/*.rb` counterpart exists at all.

## App — `src/main.js` → `lib/main.rb` — EXISTS

The `Adw.Application` subclass: actions, accelerators, stylesheet load,
search-provider export, startup/activate/shutdown.

| Facet | Upstream | Port |
|---|---|---|
| Actions | `app.quit` | `app.quit`, `app.shortcuts` (ported from the primary menu's `app.shortcuts` item, see below) |
| Accels | `<Primary>q` (quit), `<Primary>f` (win.find) | same, plus `<Primary>question` for `app.shortcuts` |
| Signals | `vfunc_startup`, `vfunc_activate`, `vfunc_dbus_register`, `vfunc_shutdown` | `startup`/`activate` signal handlers (no `Adw::Application` in these bindings, see `lib/main.rb` header comment) |
| Notes | color-scheme forced to `PREFER_LIGHT`; search provider exported from `vfunc_dbus_register` | same color-scheme; search provider exported on `startup` off `app.dbus_connection` instead of the virtual function |

Kind: **application class**. Status: **EXISTS**, parity-equivalent with one
documented structural deviation (`Gtk::Application` + manual Adwaita init,
because `Adwaita::Application` is broken in the bindings — see comment at top
of `lib/main.rb`).

## MainWindow — `src/window.js` + `data/window.ui` → `lib/window.rb` — EXISTS

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template root) | 1 | — | `map` (select initial page) | default 800×600, min 360×294 |
| `Adw.NavigationSplitView` | 1 | — | — | `splitView` |
| `Adw.NavigationPage` (sidebar) | 1 | — | — | title "Characters" |
| `Adw.NavigationPage` (content) | 1 | — | — | `contentChild`, tag `content` |
| `Adw.ToolbarView` × 2 | 2 | `view` (content one only) | — | sidebar + content |
| `Adw.HeaderBar` × 2 | 2 | — | — | sidebar bar has children below |
| `Gtk.ToggleButton` (search button) | 1 | — | `toggled` | icon `edit-find-symbolic` |
| `Gtk.MenuButton` (primary menu) | 1 | — | — | `menu-model` = `primary_menu` (built as `Gio::Menu`, 2 items: `app.shortcuts`, `win.about`) |
| `Gtk.SearchBar` | 1 | — | — | bound bidirectionally to the toggle button's `active` |
| `Gtk.SearchEntry` | 1 | — | `search-changed`, `search-started`, `stop-search`, `activate` | `set_key_capture_widget(window)` |
| `Gtk.ScrolledWindow` × 2 | 2 | `character-list-scroll` (content one) | — | sidebar scroller + character-list scroller |
| `Gjs_Sidebar` (own widget) | 1 | — | `activated` | see Sidebar unit |
| `Gtk.Stack` (`mainStack`) | 1 | — | — | 4 named pages: `empty-recent`, `character-list`, `no-results`, `loading` |
| `Adw.StatusPage` × 2 | 2 | — | — | empty-recent, no-results |
| `Gjs_CharactersView` (own widget) | 1 | — | `character-selected`, `notify::loading` | see CharactersView unit |
| `Adw.Spinner` | 1 | — | — | `loading` page |
| `Adw.Breakpoint` | 1 | — | — | `max-width: 500px` → collapses split view, sidebar mode `page` |
| Actions | — | — | — | `win.about`, `win.find` |

Repeaters: none. Conditional: none (all 4 stack pages always built).

Port coverage: every row above has a matching memoized method in
`lib/window.rb` — `window`, `split_view`, `sidebar_page`/`content_page`,
`sidebar_toolbar`/`content_toolbar`, `sidebar_header`, `search_button`,
`primary_menu_button`/`primary_menu`, `search_bar`/`search_entry`,
`sidebar_scrolled`, `sidebar` (delegates), `main_stack`,
`empty_recent_page`/`no_results_page`, `characters_view` (delegates),
`breakpoint`. All signal connections (`toggled`, `search-changed`,
`search-started`, `stop-search`, `activate` on the entry; `map` on the
window) are wired in `build`/`connect_search`. The `about`/`find` actions are
installed via `Util.init_actions`.

Kind: **window**. Status: **EXISTS**, full parity.

## Sidebar — `src/sidebar.js` + `data/sidebar.ui` → `lib/sidebar.rb` — EXISTS

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | — | `vexpand`/`hexpand` true |
| `Adw.Sidebar` | 1 | — | `activated` (re-emitted) | property `mode` (delegated) |
| `Adw.SidebarSection` | 3 | — | — | unnamed (Recently Used), "Emojis", "Letters & Symbols" |
| `Gjs_SidebarItem` | 17 | — | — | 1 recent + 9 emoji + 7 letter rows, each with `icon-name`/`title`/`category` |

Repeaters: the 17 items are template-literal in upstream's `.ui`
(`InternalChildren` lists each by name) but are a data-driven table
(`SECTIONS`) in the port — same count, same names/icons/categories, confirmed
by diffing the 17 rows against `data/sidebar.ui`.

Port coverage: `lib/sidebar.rb`'s `SECTIONS` constant reproduces all 3
sections and all 17 items 1:1 (name, title, icon, category). `item_by_name`
ports `itemByName`'s switch as a hash lookup. `restore_selection`,
`select_row_by_name`, `unselect_all`, `mode`/`mode=` all present.

Kind: **composite widget** (one component split across `.js` + `.ui`).
Status: **EXISTS**, full parity.

## SidebarItem — `src/sidebarItem.js` → `lib/sidebar_item.rb` — EXISTS

`Adw.SidebarItem` subclass adding a `category` property. Upstream registers
it as a GObject enum property (needed because `.ui` sets it declaratively);
the port builds items in Ruby so `category` is a plain attribute. No signals,
no CSS. Kind: **widget subclass**. Status: **EXISTS**, full parity.

## CharactersView — `src/charactersView.js` → `lib/characters_view.rb` — EXISTS

| Facet | Upstream | Port |
|---|---|---|
| Type | `Gtk.Widget` implementing `Gtk.Scrollable`, custom `vfunc_measure`/`vfunc_size_allocate`/`vfunc_snapshot` | `Gtk::DrawingArea` inside its own `Gtk::ScrolledWindow` (scrolling delegated to the real scrolled window instead of a hand-rolled `Gtk.Scrollable`) |
| CSS | `character-list-scroll` (on the `.ui`'s wrapping `GtkScrolledWindow`) | same class, on the port's own `scrolled_window` |
| Signals | `character-selected`, `notify::loading` (consumed by `window.js`) | `on_character_selected`/`on_loading_changed` callbacks passed in, called from the drawing area's own `Gtk::GestureClick` (`pressed`/`released`) and `resize` |
| Controller | `Gtk.GestureClick` (`pressed`, `released`) | same, `gesture_click`, attached to `drawing_area` |
| Drawing | `CharacterListRow#snapshot` via Gsk/Graphene | same algorithm (baseline offset 0.85, cell size from font, bounding box + wrapped name for unrenderable glyphs) via Cairo |
| Behaviour | `searchByCategory`, `searchByKeywords`, `populateScripts` (IBus + xkb language detection), `_reflow`, `setCharacters` | `search_by_category`, `search_by_keywords`, `populate_scripts`, `reflow`, `characters=` — present (confirmed via earlier read of `lib/characters_view.rb`, not re-pasted here) |

Kind: **custom-drawn widget**. Status: **EXISTS**. One structural deviation
(Cairo `DrawingArea` + real `ScrolledWindow` vs. a hand-built `Gtk.Scrollable`)
is documented in the file's header comment; behaviourally equivalent.

## CharacterDialog — `src/characterDialog.js` + `data/character_dialog.ui` → `lib/character_dialog.rb` — EXISTS

| Widget | × | CSS | Signals/Actions | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` (template root) | 1 | — | — | content 360×500 |
| `Adw.ToastOverlay` | 1 | — | — | `toastOverlay` |
| `Adw.NavigationView` | 1 | — | — | 2 pages |
| `Adw.NavigationPage` (main) | 1 | — | — | title bound to dialog title |
| `Adw.NavigationPage` (related) | 1 | — | `hidden` (repopulates) | tag `related` |
| `Adw.ToolbarView` × 2 | 2 | — | — | |
| `Adw.HeaderBar` × 2 | 2 | — | — | |
| `Gtk.Stack` (`characterStack`) | 1 | — | — | pages `character`, `missing` |
| `Gtk.Label` (character) | 1 | `character-label` | — | big glyph |
| `Gtk.Label` (missing) | 1 | — | — | "not included in font" message |
| `Gtk.Button` (copy) | 1 | `pill` | action `character.copy` | |
| `Adw.Clamp` × 2 | 2 | — | — | main detail clamp + related clamp |
| `Gtk.ListBox` × 2 | 2 | `boxed-list` | — | detail list + related list |
| `Adw.ActionRow` (detail) | 1 | — | — | title "Unicode", suffix label |
| `Adw.ActionRow` (see-also) | 1 | — | `activated` → `navigation.push` | underlined "_See Also", suffix icon `go-next-symbolic` |
| `Adw.ActionRow` (related, repeated) | N | — | `activated` → sets character, pops | **repeater**: one per related character found by `Gc::SearchCriteria.related` |
| `Gtk.Label` (related prefix, repeated) | N | — | — | width-request 45, one per related row |
| `Adw.Toast` | 1 (built on copy) | — | — | "Character copied to clipboard", timeout 2 |
| Action group | — | — | `character.copy` | `Gio::SimpleActionGroup` inserted as `character` |

Port coverage: `lib/character_dialog.rb` has every widget above as a
memoized method (`dialog`, `toast_overlay`, `navigation_view`, `main_page`/
`related_page`, `main_toolbar`/`related_toolbar`, `character_stack`,
`character_label`/`missing_label`, `copy_button`, `detail_clamp`/
`related_clamp`, `detail_list`/`related_listbox`, `detail_row`/`see_also_row`,
`related_row`/`related_prefix` as the repeater, `copy_toast`, `action_group`),
and `populate_related_page` is the repeater call site. One deliberate
deviation, documented in the file header: upstream's `seeAlsoRow` pushes via
the `navigation.push` action with a page tag; the port's row activation calls
`navigation_view.push` directly — same navigation, one fewer indirection.

Kind: **dialog** (composite, `.js` + `.ui`). Status: **EXISTS**, full parity.

## ShortcutsDialog — `data/shortcuts.ui` → `lib/shortcuts_dialog.rb` — EXISTS

Standalone `.ui` object with no backing `.js` file (built by
`Util.getSettings`-adjacent `imports.gi.Gtk.Builder` plumbing from
`main.js`/app actions — the dialog itself has no JS class upstream).

| Widget | × | Notes |
|---|---:|---|
| `Adw.ShortcutsDialog` | 1 | title set to "Keyboard Shortcuts" (upstream leaves it to the window manager via `app.shortcuts`) |
| `Adw.ShortcutsSection` | 1 | "General" |
| `Adw.ShortcutsItem` | 4 | Open Main Menu (`F10`), Search (`win.find`/`<Control>f`), Show Keyboard Shortcuts (`app.shortcuts`/`<Control>question`), Quit (`app.quit`/`<Control>q`) |

Port coverage: `lib/shortcuts_dialog.rb`'s `SECTIONS` constant has all 4 items
with their accelerators written out literally (upstream resolves 3 of the 4
from the action's registered accelerator; the port's header comment explains
why they're hardcoded instead). Kind: **dialog, standalone `.ui`**. Status:
**EXISTS**, full parity.

## AboutDialog — inline in `src/window.js`'s `_about()` → `lib/about_dialog.rb` — EXISTS

Not backed by any `.ui`; built programmatically upstream (`new
Adw.AboutDialog({...})`) and presented from the `win.about` action. Fields:
`application_name`, `application_icon`, `developer_name`, `designers` (3),
`developers` (2), `translator_credits`, `copyright`, `license_type`
(`GPL_2_0`), `version`, `website`, `issue_url`.

Port coverage: `lib/about_dialog.rb` reproduces every field; `version` is
sourced from the port's own `Gnome::Characters::Rb::VERSION` rather than
`pkg.version` (expected — there is no upstream build-generated version
string on this side). Kind: **dialog, built inline**. Status: **EXISTS**,
full parity.

## ShellSearchProvider — `src/searchProvider.js` + `data/ShellSearchProvider2.xml` → `lib/shell_search_provider.rb` — EXISTS

Not a widget — the app's `org.gnome.Shell.SearchProvider2` D-Bus
implementation, included per the task's instruction to cover actions/
interfaces a user reaches indirectly (the GNOME Shell search overview).

| Facet | Upstream | Port |
|---|---|---|
| Interface | loaded from GResource `/org/gnome/shell/ShellSearchProvider2.xml` | written out as a `NODE_XML` heredoc (no GResource bundle in the port) |
| Methods | `GetInitialResultSetAsync`, `GetSubsearchResultSetAsync`, `GetResultMetas`, `ActivateResult`, `LaunchSearch` | `GetInitialResultSet`, `GetSubsearchResultSet`, `GetResultMetas`, `ActivateResult`, `LaunchSearch` dispatched through `handle_method_call` |
| Export | `Gio.DBusExportedObject.wrapJSObject` | `connection.register_object` with the parsed interface info |

Port coverage: all 5 methods present with matching behaviour (search via
`Gc::SearchContext`, icon data via `Util.character_to_icon_data`,
`LaunchSearch` calling back into `App#launch_search`). Kind: **D-Bus
service / non-widget actions**. Status: **EXISTS**, full parity.

## Settings — `data/org.gnome.Characters.gschema.xml` → `lib/settings.rb` — EXISTS (reimplemented)

Not a widget; the GSettings schema backing `recent-characters` (`as`,
default `[]`) and `max-recent-characters` (`u`, default `100`).

Port coverage: `lib/settings.rb` keeps the same two keys, same defaults, same
read/write semantics, but backs them with a JSON file under
`XDG_CONFIG_HOME/gnome-characters-rb/settings.json` instead of a compiled
GSettings schema — documented in the file's header as a deliberate choice
(the pilot port, gnome-contacts-rb, does the same) to avoid requiring a
schema-compile-and-install step before the app runs from a checkout. Kind:
**settings backend**. Status: **EXISTS**, functionally equivalent, structurally
different by design.

## Gc — `lib/gc.c` / `lib/gc.h` + the `gen-*.py` generated headers → `lib/gc.rb` — EXISTS

Not a widget; the native support library (`libgnome-characters`) that GJS
imports as the `Gc` namespace — categories, search contexts/criteria, search
flags, character-name/script/composite lookups.

Port coverage: `lib/gc.rb` ports the category enum and the search/lookup API
onto Ruby's own Unicode tables plus the `lib/data/*.tsv` files (converted
1:1 from upstream's generated `.h` tables: `blocks.tsv`, `confusables.tsv`,
`emoji.tsv`, `emoji_singular.tsv`, `hangul.tsv`, `language_aliases.tsv`,
`language_scripts.tsv`, `character_names.tsv`). One upstream behaviour is
explicitly absent and documented in the header comment: the mirrored-character
"See Also" entry (`g_unichar_get_mirror_char`), because the Ruby bindings
expose no equivalent and `BidiMirroring.txt` is not in the upstream tree to
convert from. Kind: **support library, non-widget**. Status: **EXISTS**, with
one documented, deliberate behavioural gap (mirrored-character cross-refs).

## Non-widget packaging artifacts — not ported, flagged for the orchestrator

These are not UI components, so they get no `lib/*.rb` home under the house
shape, but the task's survey scope explicitly includes GSettings schemas,
GResource manifests and the `po/` catalogue, and none of the three below has
any counterpart anywhere in the `ruby` branch tree:

| Upstream file | Kind | Status | Note |
|---|---|---|---|
| `data/org.gnome.Characters.desktop.in.in` | desktop entry | **MISSING** | no `.desktop` file anywhere in the repo |
| `data/org.gnome.Characters.metainfo.xml.in.in` | AppStream metainfo | **MISSING** | no metainfo file anywhere in the repo |
| `data/org.gnome.Characters.gschema.xml` | GSettings schema (compiled) | **MISSING as a schema**, but its 2 keys are reimplemented, see Settings above | no `.gschema.xml` file; intentional per `lib/settings.rb`'s header |
| `data/org.gnome.Characters.search-provider.ini` | search-provider registration | **MISSING** | no `.ini` file; the D-Bus object itself is ported (see ShellSearchProvider) but nothing registers it with the shell via this file |
| `data/org.gnome.Characters.data.gresource.xml`, `src/org.gnome.Characters.src.gresource.xml.in` | GResource manifests | **N/A by design** | the Ruby port builds widgets in code and never has `.ui`/GResource files (house style) |
| `po/*.po`, `po/LINGUAS`, `po/POTFILES.in` | translation catalogue | **MISSING** | no `po/` directory; all strings in `lib/` are the English literals, no gettext wiring |

These six are flagged as open questions, not as unit work to start: whether a
Ruby gem packaging a desktop app needs a `.desktop`/metainfo file, a
`gschema.xml`, a search-provider `.ini`, and a `po/` catalogue is a packaging
decision for the orchestrator, not a widget-port decision for a `lib/*.rb`
unit.

## Summary

Every upstream user-facing component — the application, the main window (with
its primary menu, breakpoint and 4-page stack), the sidebar and its 17 items,
the character grid, the character dialog (with its related-characters
repeater), the standalone shortcuts dialog, the inline about dialog, and the
D-Bus search provider — already has a `lib/*.rb` counterpart on `ruby`, each
read against upstream's source (and `.ui` file, where one exists) line by
line above. No widget-level porting work remains. The only gaps found are the
six non-widget packaging artifacts listed above, which are a packaging
question rather than a `component-parity` one.
