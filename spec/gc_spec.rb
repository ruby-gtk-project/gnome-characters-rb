# frozen_string_literal: true

# Ports tests/testUtil.js's search assertions from upstream: a keyword search
# for 'pizza' finds the pizza emoji, 'joy' finds the face with tears of joy,
# and a keyword with no matches ('space') comes back empty.
#
# Upstream drives Gc::SearchContext (gc_search_context_search) through a
# GLib::MainLoop that the search's own callback quits; this does the same
# rather than reaching past the public search API into Gc.characters
# directly.
RSpec.describe Gc do
  def search(keywords, max_matches: 5)
    criteria = Gc::SearchCriteria.keywords(keywords.split(' ').map(&:upcase))
    context = Gc::SearchContext.new(criteria, flags: [:word])
    characters = []
    loop = GLib::MainLoop.new(nil, false)

    context.search(
      max_matches: max_matches,
      on_batch:    ->(batch) { characters.concat(Gc.search_result_to_array(batch)) },
      on_finished: ->(_total) { loop.quit },
    )
    loop.run

    characters
  end

  describe 'keyword search' do
    it 'finds the pizza emoji for "pizza"' do
      expect(search('pizza')).to include('🍕')
    end

    it 'finds the face with tears of joy for "joy"' do
      expect(search('joy')).to include('😂')
    end

    it 'finds nothing for "space"' do
      expect(search('space')).to be_empty
    end
  end

  # Extra coverage, not from testUtil.js: gc.c's "See Also" includes the
  # mirrored character via g_unichar_get_mirror_char, which the Ruby bindings
  # don't expose. This port carries the BidiMirroring.txt table itself
  # (lib/data/mirroring.tsv) — pin it so a regression there is caught.
  describe 'related characters (mirroring)' do
    it 'lists the mirrored closing paren for an opening paren' do
      expect(Gc.send(:related_characters, '(')).to include(')')
    end

    it 'lists the mirrored closing bracket for an opening bracket' do
      expect(Gc.send(:related_characters, '[')).to include(']')
    end

    it 'has no mirror entry for a character with no Bidi_Mirroring_Glyph' do
      expect(Gc::Data.mirroring).not_to have_key('a'.codepoints.first)
    end
  end
end
