# Translation parity — gnome-characters-rb

| | |
|---|---|
| Upstream | `main` @ `4b42297` |
| Port | `ruby` @ `686d2f1` |
| Domain | `gnome-characters` (upstream's; the port has no domain at all) |
| Upstream messages | 217 |
| Ported | **9** (and see below — even those 9 are not all byte-identical) |
| Gaps | 208 |
| Extra (untranslated) | 0 |
| Upstream occurrences | not separately re-derived here; 217 distinct keys censused across `src/*.js` and `data/*.ui`/`.xml`/`.in.in` |
| Upstream languages | 78 `.po` files + `LINGUAS`, not independently re-counted beyond confirming the directory exists and this count is consistent with upstream's own documented worked example for this skill |
| Languages shipped by the port | **0** — no `po/` directory exists anywhere in the `ruby` branch |
| Build command | none — no gettext dependency wired into `lib/`, `exe/`, or the Rakefile |

## Step 1 — census

```sh
$ scripts/msgid-census.sh /tmp/up-characters | wc -l      # 5108 rows (includes po/ provenance)
$ scripts/msgid-census.sh /tmp/up-characters | cut -f1,2 | sort -u | wc -l   # 217 distinct messages
$ scripts/msgid-census.sh .                                                 # port
-	Character map application	single	data/org.gnome.CharactersRb.metainfo.xml
-	Characters is a simple utility application...	single	data/org.gnome.CharactersRb.metainfo.xml
-	Characters	single	data/org.gnome.CharactersRb.desktop:3
-	Characters	single	data/org.gnome.CharactersRb.metainfo.xml
-	characters;unicode;punctuation;math;letters;emoji;emoticon;symbols;	single	data/org.gnome.CharactersRb.desktop:12
-	The GNOME Project	single	data/org.gnome.CharactersRb.metainfo.xml
-	This is gnome-characters-rb, a Ruby GTK4 / Libadwaita port...	single	data/org.gnome.CharactersRb.metainfo.xml
-	Utility application to find and insert unusual characters	single	data/org.gnome.CharactersRb.desktop:4
-	You can also browse characters by categories, such as Punctuation, Pictures, etc.	single	data/org.gnome.CharactersRb.metainfo.xml
```

**The port's entire message set is 9 rows, all from
`data/org.gnome.CharactersRb.{desktop,metainfo.xml}`. Zero rows come from
any file in `lib/` or `exe/`.** Confirmed directly:

```sh
$ grep -rn 'require .gettext\|FastGettext\|_("' lib/ exe/
(no output)
```

No Ruby file in this port calls `_()`, `N_()`, `n_()`, or any other marker.
Every sidebar section/item title, every window/dialog label, "Copy",
"Unicode", "Related Characters", "Character copied to clipboard", the four
shortcuts-dialog entries, and the about dialog's strings are bare literals.

## Step 2 — measure, then diff

```
messages:      9 / 217     (4%)
occurrences:   9 / ~260    (upstream reuses keys — e.g. "Characters" itself —
                             across multiple files; the port's 9 are each a
                             single site)
languages:     0 / 78
domain:        none vs "gnome-characters" — domain_matches: false
```

Key-set diff (`comm -23`/`comm -13` over the sorted key lists): 208 upstream
messages have no counterpart in the port at all; the 9 the port does emit are
not safely callable "ported" either — see the byte-identity check below.
There are 0 extra port-only messages beyond the 9 that correspond to
upstream's packaging files (nothing invented).

### Byte-identity check on the 9 the port does carry

Three of upstream's `data/` files were ported with their translatable
strings; diffing them directly against upstream's source:

```
upstream (.desktop.in.in):  Exec=@bindir@/gnome-characters      Icon=@appid@
port     (.desktop):        Exec=gnome-characters                Icon=org.gnome.Characters
```
Build-time token substitution — a correspondence, not a gap, per
`component-parity`'s rule on `@tokens@`.

```
upstream (metainfo <summary>):
  Characters is a simple utility application to find and insert unusual
  characters.  It allows you to quickly find the character you are looking
  for by searching for keywords.
port (metainfo <summary>):
  Characters is a simple utility application to find and insert unusual
  characters. It allows you to quickly find the character you are looking
  for by searching for keywords.
```

**One space character differs** (upstream has two spaces after the first
sentence, the port has one). As a gettext key these are two different
`msgid`s. This row is **reworded, not transcribed** — a gap per this skill's
rule, not a nit — and it is the row most likely to be waved through because
the English still reads correctly either way.

Additionally the metainfo file has an added `<p>` block ("This is
gnome-characters-rb, a Ruby GTK4 / Libadwaita port of GNOME Characters.")
that has no upstream counterpart at all — this is an **extra** message, fine
to have, but it is one more string that will be English-only forever unless
someone translates it, and it was not flagged anywhere before this audit.

The `<id>`, `<launchable>`, `<url>` and screenshot/developer_name fields
differ for legitimate packaging reasons (different app ID, different
upstream URL). None of those fields is extracted as translatable by the
census's marker set (they carry no `<summary>`/`<description>`/`<p>` text),
so this ledger has no row for them either way.

## What the GSettings-equivalent carries, and doesn't

Upstream's `data/org.gnome.Characters.gschema.xml` has two keys
(`recent-characters`, `max-recent-characters`), and both have a `<summary>`/
`<description>` pair that `msgid-census.sh`'s marker set extracts as
translatable. The port's `lib/settings.rb` reimplements the same two keys
functionally (documented, reasonable, matches the pilot port's choice — see
`component-parity.md`) but, having no `.gschema.xml` file at all, carries
**zero** of that file's translatable strings forward in any form. Those
messages are not even present as English literals anywhere in the port; they
simply do not exist. This is counted in the 208 gaps above (they are part of
upstream's 217), not listed separately.

## Step 5 — prove it (and what could not be run)

- `summary.parity`: **false** — 208 gaps, 0/78 languages, domain does not
  match (the port has no domain).
- `msgfmt -c` / `rmsgfmt` validation: **not run** — there is no `po/`
  directory to validate, and no gettext dependency to validate it with.
- Non-English locale check (`LANGUAGE=de LC_ALL=de_DE.UTF-8 <port binary>`):
  **not run**, and cannot meaningfully be run — there is nothing for a
  locale environment variable to select. Named here, as the skill requires
  for any check that did not run, rather than left out of the report.

## Headline numbers

```
9/217 messages (4%) · 0/~260 occurrences from source · 0/78 languages ·
0 translated strings · no locale check possible (nothing to switch)
```

## Extra

- The metainfo `<p>` paragraph describing the port itself (see above) — one
  English-only string, harmless, not parity work.

## Rules followed

- Upstream's bytes were not "improved" to match the port; the one-space
  difference in the metainfo summary is recorded as a gap, not silently
  accepted because the English reads fine.
- Reported as a pair against upstream at every opportunity (9/217, 0/78), not
  as a lone adjective.
- The gschema's two untranslated keys are counted inside the 217 gaps, not
  dropped because "there's no `.gschema.xml` to scan" — the skill is explicit
  that a marked string in a widget/file the port never built is still a gap,
  not an exemption.
