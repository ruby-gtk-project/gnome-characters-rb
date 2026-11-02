# frozen_string_literal: true

require 'set'
require 'glib2'

# Gc is the port of upstream's libgc: lib/gc.c and lib/gc.h, the small C
# library that GJS imports as the `Gc` namespace.
#
# Upstream compiles the Unicode tables into the library from generated headers
# (lib/names.h, lib/emoji.h, lib/blocks.h, lib/hangul.h, lib/confusables.h,
# lib/scripts.h, lib/languages.h, built by lib/gen-*.py). This port carries the
# same tables as tab-separated data files under lib/data/, converted from those
# headers one-for-one, and reads character properties — printable, graphic,
# general category, script, case mappings, canonical decomposition — from
# Ruby's own Unicode tables instead of from glib's.
#
# The one behaviour of gc.c that is absent here is the mirrored-character
# entry in "See Also": gc.c calls g_unichar_get_mirror_char, the Ruby bindings
# expose no equivalent, and BidiMirroring.txt is not in the upstream tree to
# convert, so the port cannot build that table. Related characters from case
# mappings, decomposition, emoji sequences and the confusables table are all
# present.
module Gc
  # GcCategory, in upstream's declaration order — searchByCategory compares
  # against LETTER_LATIN to decide whether to draw a baseline, so the order is
  # part of the interface, not decoration.
  CATEGORIES = %i[
    none
    letter
    letter_punctuation
    letter_arrow
    letter_bullet
    letter_picture
    letter_currency
    letter_math
    letter_latin
    emoji
    emoji_smileys
    emoji_people
    emoji_animals
    emoji_food
    emoji_activities
    emoji_travel
    emoji_objects
    emoji_symbols
    emoji_flags
  ].freeze

  # g_unichar_isprint and g_unichar_isgraph, as the general categories they
  # exclude.
  NOT_PRINTABLE = /[\p{Cc}\p{Cf}\p{Cs}\p{Co}\p{Cn}\p{Zl}\p{Zp}]/
  NOT_GRAPHIC = /[\p{Cc}\p{Cf}\p{Cs}\p{Co}\p{Cn}\p{Zl}\p{Zp}\p{Zs}]/

  # The seven G_UNICODE_*_PUNCTUATION types filter_is_punctuation lists.
  PUNCTUATION = /\p{P}/
  CURRENCY_SYMBOL = /\p{Sc}/
  MATH_SYMBOL = /\p{Sm}/

  SURROGATES = (0xD800..0xDFFF)

  ARROW_BLOCK_STARTERS = [0x2190, 0x27F0, 0x2900].freeze
  PICTURE_BLOCK_STARTERS = [0x2600, 0x2700, 0x1F000, 0x1F030, 0x1F0A0, 0x1F300].freeze
  LATIN_BLOCK_STARTERS = [0x0000, 0x0080, 0x0100, 0x0180].freeze
  HIRAGANA_BLOCK_STARTERS = [0x3040].freeze
  KATAKANA_BLOCK_STARTERS = [0x30A0, 0x31F0].freeze

  CJK_BLOCK_STARTERS = [
    0x4E00, 0x3400, 0x20000, 0x2A700, 0x2B740, 0x2B820,
    0x2CEB0, 0x2EBF0, 0x30000, 0x31350, 0x323B0,
  ].freeze
  TANGUT_BLOCK_STARTERS = [0x17000, 0x18D00].freeze
  HANGUL_BLOCK_STARTER = 0xAC00

  VARIATION_SELECTOR_16 = 0xFE0F
  ZERO_WIDTH_JOINER = 0x200D

  # Bullets are not a Unicode category; the list is UTR#25's, copied from
  # gc.c's bullet_characters.
  BULLET_CHARACTERS = [
    0x25C2, 0x25C3, 0x25C0, 0x25C1,
    0x25B8, 0x2023, 0x25B9, 0x25B6, 0x25B7,
    0x25B4, 0x25B5, 0x25B2, 0x25B3,
    0x25BE, 0x25BF, 0x25BC, 0x25BD,
    0x2B1D, 0x2B1E, 0x25AA, 0x25AB, 0x25FD, 0x25FE, 0x25FC, 0x25FB,
    0x25A0, 0x25A1, 0x2B1B, 0x2B1C,
    0x2B29, 0x22C4, 0x2B25, 0x2B26, 0x25C6, 0x25C7,
    0x2B2A, 0x2B2B, 0x2B27, 0x2B28, 0x29EB, 0x25CA,
    0x2B1F, 0x2B20,
    0x2B53, 0x2B54,
    0x2B23, 0x2394,
    0x2B22, 0x2B21,
    0x2B51, 0x2B52, 0x22C6, 0x2B50, 0x2605, 0x2606,
    0x2B2C, 0x2B2D,
    0x2B2E, 0x2B2F,
    0x22C5, 0x2219, 0x00B7, 0x2218, 0x2022, 0x25E6, 0x2981, 0x26AC,
    0x26AB, 0x26AA, 0x25CF, 0x25CB, 0x2B24, 0x25EF,
    0x2299, 0x2609, 0x233E, 0x2A00, 0x29BF, 0x229A, 0x29BE, 0x25C9, 0x25CE,
  ].freeze

  # Data holds the tables converted from upstream's generated headers. Every
  # table is read from disk on first use: the character names are 1.2MB and a
  # category search never touches them.
  module Data
    DIR = File.expand_path('data', __dir__)

    class << self
      def blocks
        @blocks ||= rows('blocks.tsv').map do |start, finish, name|
          { start: Integer(start, 16), end: Integer(finish, 16), name: name }
        end
      end

      def character_names
        @character_names ||= rows('character_names.tsv').to_h do |code, name|
          [Integer(code, 16), name]
        end
      end

      def hangul_short_names
        @hangul_short_names ||= rows('hangul.tsv').to_h do |code, name|
          [Integer(code, 16), name]
        end
      end

      # [[codepoints, name, categories], ...] in upstream's emoji.h order,
      # which is the order the emoji pages are listed in.
      def emoji
        @emoji ||= rows('emoji.tsv').map do |codepoints, name, categories|
          [codepoints.split.map { |code| Integer(code, 16) }, name, categories.to_s.split(',')]
        end
      end

      def emoji_names
        @emoji_names ||= emoji.to_h { |codepoints, name, _| [codepoints, name] }
      end

      def emoji_sequences = @emoji_sequences ||= Set.new(emoji.map { |codepoints, _, _| codepoints })

      def emoji_by_category
        @emoji_by_category ||= emoji.each_with_object({}) do |(codepoints, _, categories), index|
          categories.each { |category| (index[category] ||= []) << codepoints }
        end
      end

      # is_character_emoji: the first codepoints of the emoji that gc.c lists
      # in emoji_singular_characters, used to keep emoji out of the plain
      # block walk.
      def emoji_singular
        @emoji_singular ||= Set.new(rows('emoji_singular.tsv').map { |(code)| Integer(code, 16) })
      end

      def confusables
        @confusables ||= rows('confusables.tsv').to_h do |code, members|
          [Integer(code, 16), members.split.map { |member| Integer(member, 16) }]
        end
      end

      def language_scripts
        @language_scripts ||= rows('language_scripts.tsv').to_h do |language, names|
          [language, names.to_s.split(',')]
        end
      end

      def language_aliases
        @language_aliases ||= rows('language_aliases.tsv').to_h { |alias_name, name| [alias_name, name] }
      end

      def block_at(codepoint)
        blocks.find { |block| block[:start] <= codepoint && codepoint <= block[:end] }
      end

      def blocks_starting_at(starters)
        starters.filter_map { |starter| block_at(starter) }
      end

      private

        def rows(name)
          File.readlines(File.join(DIR, name), chomp: true).map { |line| line.split("\t", -1) }
        end
    end
  end

  # SearchCriteria, the boxed type gc_search_criteria_new_* builds.
  class SearchCriteria
    attr_reader :type, :value

    def self.category(category) = new(:category, category)
    def self.keywords(keywords) = new(:keywords, keywords)
    def self.scripts(scripts) = new(:scripts, scripts)
    def self.related(character) = new(:related, character)

    def initialize(type, value)
      @type = type
      @value = value
    end
  end

  # SearchContext runs a search without blocking the UI, the way
  # gc_search_context_search does with a thread: it walks the character
  # enumeration from a GLib idle handler in short slices, handing each slice of
  # matches to on_batch, and calls on_finished once the walk is over or the
  # search is cancelled.
  class SearchContext
    SLICE_SECONDS = 0.02

    attr_reader :criteria, :flags

    def initialize(criteria, flags: [])
      @criteria = criteria
      @flags = flags
      @finished = false
      @cancelled = false
      @total = 0
    end

    def finished? = @finished

    def search(max_matches: -1, on_batch: nil, on_finished: nil)
      tap do
        @max_matches = max_matches
        @on_batch = on_batch
        @on_finished = on_finished
        @characters = Gc.characters(criteria, flags)
        GLib::Idle.add { step }
      end
    end

    def cancel
      tap do
        @cancelled = true
        @finished = true
      end
    end

    private

      # Returns true to stay on the idle queue, false to come off it.
      def step
        if @cancelled
          false
        else
          slice.then do |batch|
            @on_batch&.call(batch)
            if @finished
              @on_finished&.call(@total)
            end
            !@finished
          end
        end
      end

      def slice
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + SLICE_SECONDS
        batch = []
        while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline && !@finished
          collect(batch)
        end
        batch
      end

      # The enumeration yields nil as a progress tick, so that a long stretch
      # of non-matching codepoints still gives the main loop a chance to run.
      def collect(batch)
        begin
          @characters.next.then do |character|
            if character
              batch << character
              @total += 1
            end
          end
        rescue StopIteration
          @finished = true
        end

        if @max_matches >= 0 && @total >= @max_matches
          @finished = true
        end
      end
  end

  class << self
    def category_index(category) = CATEGORIES.index(category)

    # searchByCategory draws a baseline for everything up to and including
    # LETTER_LATIN, and none for the emoji pages.
    def baseline_category?(category)
      category_index(category) <= category_index(:letter_latin)
    end

    def character_is_composite?(character) = character.codepoints.length > 1

    def character_is_invisible?(character)
      character.each_char.none? { |char| graphic?(char) }
    end

    # gc_character_name: the generated CJK, Tangut and Hangul names first, then
    # the emoji table, then the Unicode names table. nil when the character has
    # no name, which the callers render as "Unassigned".
    def character_name(character)
      character.codepoints.then do |codepoints|
        if codepoints.length == 1
          single_character_name(codepoints[0])
        else
          Data.emoji_names[codepoints]
        end
      end
    end

    # gc_get_current_language, which reads nl_langinfo(_NL_IDENTIFICATION_LANGUAGE)
    # and falls back to the locale name. The locale environment is what both
    # end up reporting.
    def current_language
      locale = ENV['LC_ALL'] || ENV['LC_CTYPE'] || ENV['LANG'] || 'C'
      locale.split(/[.@]/).first.to_s.downcase.tr('-', '_').then do |language|
        if language.empty? || %w[c posix].include?(language)
          'en'
        else
          language
        end
      end
    end

    # gc_get_scripts_for_language, as script names rather than GUnicodeScript
    # values: Ruby's character properties are named, so the names are what the
    # scripts filter needs.
    def scripts_for_language(language)
      normalize_language(language).then do |normalized|
        Data.language_scripts[normalized] ||
          Data.language_scripts[normalized.split('_').first] ||
          []
      end
    end

    def normalize_language(language)
      language.to_s.downcase.tr('-', '_').split(/[.@]/).first.to_s.then do |name|
        Data.language_aliases[name] || name
      end
    end

    def printable?(character) = !NOT_PRINTABLE.match?(character)
    def graphic?(character) = !NOT_GRAPHIC.match?(character)

    def character_for(codepoint)
      if SURROGATES.cover?(codepoint) || codepoint > 0x10FFFF
        nil
      else
        codepoint.chr(Encoding::UTF_8)
      end
    end

    # The enumeration a SearchContext walks. It yields matching characters as
    # strings, and nil every so often as a progress tick.
    def characters(criteria, flags = [])
      Enumerator.new do |yielder|
        case criteria.type
        when :category then enumerate_category(criteria.value, yielder)
        when :keywords then enumerate_keywords(criteria.value, flags, yielder)
        when :scripts then enumerate_scripts(criteria.value, yielder)
        when :related then enumerate_related(criteria.value, yielder)
        end
      end
    end

    private

      def single_character_name(codepoint)
        if cjk?(codepoint)
          format('CJK UNIFIED IDEOGRAPH-%X', codepoint)
        elsif tangut?(codepoint)
          format('TANGUT IDEOGRAPH-%X', codepoint)
        elsif hangul_syllable?(codepoint)
          hangul_syllable_name(codepoint)
        else
          Data.emoji_names[[codepoint]] || Data.character_names[codepoint]
        end
      end

      def cjk_blocks = @cjk_blocks ||= Data.blocks_starting_at(CJK_BLOCK_STARTERS)
      def tangut_blocks = @tangut_blocks ||= Data.blocks_starting_at(TANGUT_BLOCK_STARTERS)
      def hangul_block = @hangul_block ||= Data.block_at(HANGUL_BLOCK_STARTER)

      def in_blocks?(blocks, codepoint)
        blocks.any? { |block| block[:start] <= codepoint && codepoint <= block[:end] }
      end

      def cjk?(codepoint) = in_blocks?(cjk_blocks, codepoint)
      def tangut?(codepoint) = in_blocks?(tangut_blocks, codepoint)
      def hangul_syllable?(codepoint) = in_blocks?([hangul_block].compact, codepoint)

      # "HANGUL SYLLABLE " plus the short name of each jamo the syllable
      # decomposes into.
      def hangul_syllable_name(codepoint)
        character_for(codepoint).unicode_normalize(:nfd).codepoints
                                .filter_map { |jamo| Data.hangul_short_names[jamo] }
                                .then do |short_names|
          if short_names.empty?
            'HANGUL SYLLABLE UNKNOWN'
          else
            "HANGUL SYLLABLE #{short_names.join}"
          end
        end
      end

      # --- enumerations ---------------------------------------------------

      def enumerate_category(category, yielder)
        case category
        when :letter_punctuation
          enumerate_blocks(Data.blocks, yielder) { |char| printable?(char) && PUNCTUATION.match?(char) }
        when :letter_arrow
          enumerate_blocks(Data.blocks_starting_at(ARROW_BLOCK_STARTERS), yielder) { |char| printable?(char) }
        when :letter_bullet
          BULLET_CHARACTERS.each { |codepoint| yielder << character_for(codepoint) }
        when :letter_picture
          enumerate_blocks(Data.blocks_starting_at(PICTURE_BLOCK_STARTERS), yielder) { |char| printable?(char) }
        when :letter_currency
          enumerate_blocks(Data.blocks, yielder) { |char| printable?(char) && CURRENCY_SYMBOL.match?(char) }
        when :letter_math
          enumerate_blocks(Data.blocks, yielder) { |char| printable?(char) && MATH_SYMBOL.match?(char) }
        when :letter_latin
          enumerate_scripts(['Latin'], yielder)
        else
          enumerate_emoji_category(category, yielder)
        end
      end

      def enumerate_emoji_category(category, yielder)
        category.to_s.delete_prefix('emoji_').then do |name|
          Data.emoji_by_category.fetch(name, []).each do |codepoints|
            yielder << codepoints.filter_map { |codepoint| character_for(codepoint) }.join
          end
        end
      end

      def enumerate_scripts(scripts, yielder)
        script_pattern(scripts).then do |pattern|
          if pattern
            enumerate_blocks(Data.blocks, yielder) { |char| printable?(char) && pattern.match?(char) }
          end
        end
      end

      # A Unicode script name Ruby does not know is skipped rather than
      # aborting the search: upstream's table carries script names from
      # ISO 15924, and Ruby's property names do not cover every one of them.
      def script_pattern(scripts)
        scripts.map { |script| script.to_s.tr(' ', '_') }
               .select { |script| known_script?(script) }
               .then do |known|
          if known.empty?
            nil
          else
            Regexp.new("[#{known.map { |script| "\\p{#{script}}" }.join}]")
          end
        end
      end

      def known_script?(script)
        @known_scripts ||= {}
        if @known_scripts.key?(script)
          @known_scripts[script]
        else
          @known_scripts[script] = begin
            Regexp.new("\\p{#{script}}")
            true
          rescue RegexpError
            false
          end
        end
      end

      def enumerate_blocks(blocks, yielder, &filter)
        blocks.each do |block|
          (block[:start]..block[:end]).each do |codepoint|
            if (codepoint % 4096).zero?
              yielder << nil
            end

            character_for(codepoint).then do |character|
              if character && filter.call(character) && !Data.emoji_singular.include?(codepoint)
                yielder << character
              end
            end
          end
        end
      end

      # filter_keywords over the blocks and then the whole emoji table, which
      # is what gc_character_iter_init_for_keywords sets up.
      def enumerate_keywords(keywords, flags, yielder)
        keywords.then do |words|
          enumerate_blocks(Data.blocks, yielder) { |char| keywords_match?(char, words, flags) }

          Data.emoji.each do |codepoints, _, _|
            codepoints.filter_map { |codepoint| character_for(codepoint) }.join.then do |character|
              if keywords_match?(character, words, flags)
                yielder << character
              end
            end
          end
        end
      end

      def keywords_match?(character, keywords, flags)
        if character.each_char.none? { |char| printable?(char) }
          false
        elsif keywords.length == 1 && literal_match?(character, keywords[0])
          true
        else
          name_matches?(character, keywords, flags)
        end
      end

      # The single-keyword special case: the keyword is the character itself,
      # or its hexadecimal code point.
      def literal_match?(character, keyword)
        if character == keyword
          true
        else
          character.codepoints.length == 1 &&
            keyword.length <= 6 &&
            keyword.match?(/\A[0-9A-Fa-f]+\z/) &&
            Integer(keyword, 16) == character.codepoints[0]
        end
      end

      def name_matches?(character, keywords, flags)
        character_name(character).then do |name|
          if name
            keywords.all? { |keyword| name_contains?(name, keyword, flags) }
          else
            false
          end
        end
      end

      # GC_SEARCH_FLAG_WORD makes a keyword match only at the start of a word
      # in the character's name.
      def name_contains?(name, keyword, flags)
        if flags.include?(:word)
          name.enum_for(:scan, keyword)
              .map { Regexp.last_match.begin(0) }
              .any? { |offset| offset.zero? || name[offset - 1] == ' ' }
        else
          name.include?(keyword)
        end
      end

      # populate_related_characters: the variation-selector sequence, the case
      # mappings, the decomposition base and everything composed from it, the
      # Hangul jamo, and the confusables class.
      def enumerate_related(character, yielder)
        related_characters(character).each { |related| yielder << related }
      end

      def related_characters(character)
        character.codepoints.then do |codepoints|
          if codepoints.length > 1
            sequence_parts(codepoints)
          else
            single_related(codepoints[0])
          end
        end
      end

      # For a sequence, the longest leading sub-sequences that are themselves
      # emoji, skipping the whole sequence and any part holding a joiner.
      def sequence_parts(codepoints)
        [].tap do |parts|
          index = 0
          while index < codepoints.length
            length = usable_part_length(codepoints, index)
            parts << codepoints[index, length].filter_map { |code| character_for(code) }.join
            index += length
          end
        end
      end

      def usable_part_length(codepoints, index)
        (codepoints.length - index).downto(1).find do |length|
          usable_part?(codepoints, index, length)
        end || 1
      end

      def usable_part?(codepoints, index, length)
        codepoints[index, length].then do |part|
          if length == codepoints.length
            false
          elsif length > 1
            Data.emoji_sequences.include?(part) && !part.include?(ZERO_WIDTH_JOINER)
          else
            true
          end
        end
      end

      def single_related(codepoint)
        [].tap do |related|
          character_for(codepoint).then do |character|
            if Data.emoji_sequences.include?([codepoint, VARIATION_SELECTOR_16])
              related << "#{character}#{character_for(VARIATION_SELECTOR_16)}"
            end

            related.concat(case_related(character))
            related.concat(script_related(character, codepoint))
            related.concat(Data.confusables.fetch(codepoint, []).filter_map { |code| character_for(code) })
          end

          related.uniq!
        end
      end

      def case_related(character)
        [character.upcase, character.downcase, character.capitalize]
          .select { |mapped| mapped.length == 1 && mapped != character }
          .uniq
      end

      def script_related(character, codepoint)
        [].tap do |related|
          if character.match?(/\p{Hangul}/)
            related.concat(character.unicode_normalize(:nfd).each_char.to_a)
          elsif character.match?(/\p{Alpha}/)
            decomposition_base(character).then do |base|
              if base != character
                related << base
              end

              related.concat(composited(character, base))
            end
          end
        end
      end

      def decomposition_base(character)
        character.unicode_normalize(:nfd)[0]
      end

      # add_composited: every character in the script's blocks whose
      # decomposition base is this one.
      def composited(character, base)
        composited_blocks(character).then do |blocks|
          blocks.flat_map do |block|
            (block[:start]..block[:end]).filter_map do |codepoint|
              character_for(codepoint).then do |candidate|
                if candidate && candidate != base && decomposition_base(candidate) == base
                  candidate
                end
              end
            end
          end
        end
      end

      def composited_blocks(character)
        if character.match?(/\p{Latin}/)
          Data.blocks_starting_at(LATIN_BLOCK_STARTERS)
        elsif character.match?(/\p{Hiragana}/)
          Data.blocks_starting_at(HIRAGANA_BLOCK_STARTERS)
        elsif character.match?(/\p{Katakana}/)
          Data.blocks_starting_at(KATAKANA_BLOCK_STARTERS)
        else
          []
        end
      end
  end
end
