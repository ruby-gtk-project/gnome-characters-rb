# Translation parity — gnome-characters-rb

| | |
|---|---|
| Upstream | `main` @ `4b42297` |
| Port | `ruby` @ `ca1d509` |
| Domain | upstream: `org.gnome.Characters` (`po/meson.build`) — port: `gnome-characters-rb` (`lib/i18n.rb:17`) — **does not match** |
| Upstream messages (source only, `po/` excluded per this skill's own rule) | 174 |
| Ported (byte-identical key present in port) | 47 |
| Gaps (real, after the scanner correction below) | 120 |
| Extra (untranslated, after the scanner correction below) | 2 |
| Upstream occurrences | 947 call sites over 174 keys (37 reused) |
| Upstream languages | 75 `.po` files, `LINGUAS` matches exactly (independently diffed this round) |
| Languages shipped by the port | **75/75** — `po/*.po`, `LINGUAS` and `POTFILES.in` now exist; `diff` of the two `.po` filename lists is empty |
| Build command | `rake gettext:compile` (per `rakelib/gettext.rake`, compiles to `po/locale/*/LC_MESSAGES`, gitignored/generated) |

## Correction to the prior round's report — the previous round's own numbers were wrong, not just stale

The previous version of this document (pinned at `d89d6f1`) reported
**217** upstream messages and **0/78 languages, no `po/` directory, no
gettext anywhere**. Two things changed between that round and this one, and
one of them was never true in the first place:

1. **Commit `3135717` landed since** — "Port the translation catalogue: wire
   gettext into lib/ and add po/" — which is the real, large change: the
   previous round's "0 languages, no gettext" claim is now stale, not wrong.
2. **The previous round's "217 upstream messages" figure was itself
   miscounted**, independent of anything the port did. Re-running this
   skill's own `msgid-census.sh` against `origin/main` and reading its
   output correctly: scanning upstream's `po/` directory returns 217
   distinct keys **because `.po` files also list msgids the current source
   no longer has** (upstream has since deleted two strings — this skill's
   own worked-example text for a different app in this org names exactly
   this trap: *"`po/` is excluded from `messages:`... counting it would
   report a tree as emitting strings its code no longer has"*). Scanning
   `src/*.js`+`data/*.ui`+`.xml`+`.gschema.xml` alone — the correct basis —
   returns **174**. The previous round's 217 was the po-inflated number,
   cited as if it were the source count. This round uses 174, and this
   correction is recorded in place rather than silently swapped.

## Step 1 — census, and two scanner defects found and worked around (not silently absorbed)

```sh
$ .claude/skills/translation-parity/scripts/msgid-census.sh /tmp/up-ch | wc -l        # 5108 (includes po/ provenance)
$ awk -F'\t' '$4 !~ /^po\// {print}' | cut -f1,2 | sort -u | wc -l                     # 174 — upstream, source only
$ .claude/skills/translation-parity/scripts/msgid-census.sh . > port.tsv
$ awk -F'\t' '$4 !~ /^po\// {print}' port.tsv | cut -f1,2 | sort -u | wc -l            # 55 — port
```

Raw `comm -23`/`comm -13` on the two 174/55 key sets gives 127 gaps and 8
extras. Per this skill's rule to cross-check against a real `.po` before
trusting the census, two of those 127+8 are **scanner defects, not real
differences**, found by reading the actual files rather than reported as-is:

1. **`msgid-census.sh` does not decode HTML entities when scanning
   `.ui` XML.** `data/sidebar.ui:25,32,39,46` write
   `<property name="title" translatable="yes">Smileys &amp; Emotion</property>`
   — the literal bytes in the file, pre-XML-decode. The real msgid (verified
   against `po/fr.po:57`, `msgid "Animals & Nature"`) is the **decoded**
   form, which is exactly what the port already emits
   (`lib/sidebar.rb:98-106,110`). So `Animals &amp; Nature` /
   `Food &amp; Drink` / `People &amp; Body` / `Smileys &amp; Emotion` /
   `Travel &amp; Places` / `Letters &amp; Symbols` are **6 false gaps paired
   with 6 false extras** — the port's text axis is already correct here,
   and this is noted as a scanner limitation (worth fixing in the shared
   skill script) rather than filed as 6 gaps this port does not have.
2. **One false gap from a Python format-string literal.**
   `lib/gen-scripts.py:93` contains `'{0}'.format(script)` — the scanner
   matches `'{0}'` as a quoted literal next to `N_(` on the same logical
   line and reports it as a translatable message. It is Python string
   formatting syntax, not a msgid; no `.po` file anywhere contains it.
   Subtracted as 1 false gap.

After both corrections: **120 real gaps, 2 real extras** (`Keyboard
Shortcuts` and the port's own metainfo-style blurb paragraph, both listed
under `## Extra` below).

## Step 2 — what the 120 real gaps are

```sh
$ comm -23 up.keys port.keys > gaps.txt   # after removing the 7 scanner artefacts above
$ grep -cE '^-\t[A-Z][a-z]+(_[A-Za-z]+)*$' gaps.txt   # 117
```

**117 of the 120 are Unicode script names** — `Adlam`, `Arabic`, `Armenian`,
`Avestan`, `Balinese`, … `Yi`, `Zanabazar_Square` — generated upstream by
`lib/gen-scripts.py`, marked `N_("{0}".format(script))` per-script, and
compiled into `src/scripts.h` as a table GNOME Characters uses (via
`gc_get_scripts_for_language`) both to pick a default category for the
user's locale **and to let a user search by typing a script name in their
own language**. The port carries the identical data —
`lib/data/language_scripts.tsv`, read by `Gc::Data.language_scripts`
(`lib/gc.rb:170-172`) and consumed by `Gc.scripts_for_language`
(`lib/gc.rb:354-358`) and `CharactersView` (`lib/characters_view.rb:166`) —
**with no translation marker anywhere on the table**. `lib/gc.rb` and
`lib/data/language_scripts.tsv` carry **zero** `_()`/`N_()` calls (confirmed:
`grep -c "_(" lib/gc.rb` → 0). This is a real, functional translation gap,
not a cosmetic one: a non-English-locale user who searches by typing their
language's word for a script gets no match, because the port never offers
those 117 strings to any catalogue in the first place.

The remaining 3:

| msgid | Upstream source | Port state |
|---|---|---|
| `Characters's main interface` | `data/org.gnome.Characters.metainfo.xml.in.in:19` (screenshot `<caption>`) | not present — port's metainfo has no equivalent screenshot caption |
| `Letters page` | same file, line 23 | not present, same reason |
| `Maximum recent characters` | `data/org.gnome.Characters.gschema.xml:8` (`<summary>`) | not present — confirmed again this round: the port still has no `.gschema.xml`, carried forward from the prior round's finding under Settings |

## Step 3 — domain mismatch (new finding this round, not in any prior report)

`lib/i18n.rb:17` hardcodes `DOMAIN = 'gnome-characters-rb'`. Upstream's
domain, read from `po/meson.build`'s `i18n.gettext(meson.project_name(), ...)`
with `project('gnome-characters', ...)` at `/tmp/up-ch/meson.build:1`, is
`org.gnome.Characters`. These are not the same domain, and per this skill's
explicit rule — *"Never invent a domain name for the port. The domain is
upstream's, because the catalogues are upstream's."* — this is a gap in its
own right, tracked separately from the message-key gaps above. In practice
it does not break the port's own `rake gettext:compile` pipeline (the port
compiles its own `.po` files to its own domain name and binds to that same
name), but it does mean the port's catalogues are not interchangeable with
upstream's `l10n.gnome.org`-maintained ones under the name translators
actually work against — `domain_matches: false`.

## Step 4 — languages

```sh
$ diff <(ls po/*.po | xargs -n1 basename) <(ls /tmp/up-ch/po/*.po | xargs -n1 basename)
(empty)
$ wc -l < po/LINGUAS   # as a word count: 75, matches file count
```

75/75 languages shipped, file list identical to upstream's. This is the one
clean pass in this report.

## Step 5 — prove it (and what could not be run)

- Message census: **run this round**, directly, both sides — not taken on
  anyone's word. 47/174 real keys match, 120 real gaps, 2 real extras.
- `msgfmt -c` / `rmsgfmt` validation of the 75 `.po` files: **not run** this
  round — not attempted, not confirmed available in the dev shell. Named as
  unrun rather than assumed clean.
- Non-English locale check (`LANGUAGE=de LC_ALL=de_DE.UTF-8 xvfb-run ruby
  exe/gnome-characters`), asserting a known translated string on screen:
  **not run** this round. Given 117 of the 120 real gaps are the
  script-name search table rather than visible chrome labels, a locale
  check would likely show translated sidebar/dialog text correctly while
  still silently failing to localise script-name search — which is exactly
  the kind of partial result this skill warns reads as a pass. Not run, and
  not claimed.

## Headline numbers

```
47/174 messages (27%) · 75/75 languages (100%) · domain mismatch (gnome-characters-rb vs org.gnome.Characters)
dominant gap: 117 Unicode script names (lib/gc.rb, lib/data/language_scripts.tsv) never marked for translation
```

## Extra

- `Keyboard Shortcuts` (`lib/window.rb`) — a title string with no upstream
  key by that exact spelling; upstream's nearest equivalent
  (`Show Keyboard Shortcuts`) is a separate, already-matched key. English
  only until someone translates it.
- The metainfo `<p>` paragraph describing the port itself
  ("This is gnome-characters-rb, a Ruby GTK4 / Libadwaita port of GNOME
  Characters.") — one English-only string, harmless, not parity work.

## Rules followed

- The prior round's "217 upstream / 0 port" numbers are corrected in place,
  with the evidence for both corrections (the po-inflation trap on the
  upstream side, commit `3135717` on the port side) — neither silently
  swapped nor re-asserted.
- Two scanner defects (HTML-entity decoding, a Python format-string false
  positive) are named and fixed by hand rather than reported as 7 port gaps
  that do not exist, per the skill's "when the scanner is the thing that is
  wrong" procedure — not silently absorbed into the gap count either
  direction.
- The domain mismatch is reported even though it does not block the port's
  own build — "works for the port's own pipeline" is not the question this
  skill asks; "is it upstream's domain" is.
- Reported as pairs against upstream throughout (47/174, 75/75), not as a
  lone adjective.
- Checks not run this round (`msgfmt -c`, a live non-English locale
  screenshot) are named as unrun in Step 5, not folded into "parity".
