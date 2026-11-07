# frozen_string_literal: true

require 'adwaita'

# Util is the port of upstream's src/util.js.
#
# initActions, capitalize, toCodePoint and getInputSources carry over as they
# are. searchResultToArray has no counterpart: a Gc search already hands back
# an array of strings rather than a GcSearchResult boxed pointer.
#
# characterToIconData renders through Cairo rather than through a Gsk renderer
# and Gdk::TextureDownloader, which is what the search provider needs: the
# pixel buffer the GNOME Shell search provider interface asks for, as a
# (iiibiiay) tuple.
module Util
  ACRONYMS = %w[CJK].freeze
  PREFIXES = ['IDEOGRAPH-', 'SELECTOR-'].freeze
  ICON_SIZE = 48.0

  # What JS's String.prototype.trim() considers whitespace: the full Unicode
  # White_Space property, not just ASCII. characterToIconData guards on it
  # with `!character.trim().length`.
  WHITESPACE_ONLY = /\A\p{White_Space}*\z/

  class << self
    # initActions: each entry is { name:, activate: } and gets a
    # Gio::SimpleAction added to the map.
    def init_actions(action_map, entries)
      entries.each do |entry|
        Gio::SimpleAction.new(entry[:name]).tap do |action|
          action.signal_connect('activate') { |_action, parameter| entry[:activate].call(parameter) }
          action_map.add_action(action)
        end
      end
    end

    # "LATIN SMALL LETTER A" -> "Latin Small Letter A", leaving the acronyms
    # upstream lists alone and keeping the tail of IDEOGRAPH-/SELECTOR- names
    # as it is.
    def capitalize(string)
      string.split(/\s+/).map { |word| capitalize_name_word(word) }.join(' ')
    end

    def to_code_point(string) = string.codepoints.first

    # getInputSources: the portal when running under Flatpak, the
    # org.gnome.desktop.input-sources schema otherwise. Either way, a list of
    # [type, id] pairs, and an empty list when neither is readable.
    def input_sources
      if flatpak?
        portal_input_sources
      else
        settings_input_sources
      end
    end

    def flatpak? = File.exist?('/.flatpak-info')

    # The pixel buffer for a character, as the (iiibiiay) tuple
    # org.gnome.Shell.SearchProvider2 expects in a result meta's icon-data:
    # width, height, rowstride, has-alpha, bits-per-sample, channels, bytes.
    # nil when the character draws nothing, which is what upstream returns for
    # a layout of invisible characters.
    #
    # The variant is built by parsing GVariant text: GLib::Variant.new in
    # these bindings raises NotImplementedError for a tuple, and
    # GLib::Variant.parse is what can carry one.
    def character_to_icon_data(character)
      if WHITESPACE_ONLY.match?(character.to_s)
        nil
      else
        GLib::Variant.parse(icon_data_text(character), '(iiibiiay)')
      end
    end

    private

      def icon_data_text(character)
        icon_surface(character).then do |surface|
          format(
            '(%d, %d, %d, true, 8, 4, [%s])',
            surface.width,
            surface.height,
            surface.stride,
            rgba_bytes(surface).join(', '),
          )
        end
      end

      def capitalize_name_word(word)
        if ACRONYMS.include?(word)
          word
        else
          PREFIXES.find { |prefix| word.start_with?(prefix) }.then do |prefix|
            if prefix
              capitalize_word(prefix) + word[prefix.length..]
            else
              capitalize_word(word)
            end
          end
        end
      end

      def capitalize_word(word)
        if word.empty?
          word
        else
          word[0].upcase + word[1..].downcase
        end
      end

      def portal_input_sources
        Gio::DBus.session.call_sync(
          'org.freedesktop.portal.Desktop',
          '/org/freedesktop/portal/desktop',
          'org.freedesktop.portal.Settings',
          'ReadOne',
          GLib::Variant.new(['org.gnome.desktop.input-sources', 'sources'], '(ss)'),
          nil,
          :none,
          -1,
          nil,
        ).then { |reply| reply.get_child_value(0).value }
      rescue StandardError, GLib::Error => e
        warn "Failed to read settings from the settings portal: #{e.message}"
        []
      end

      def settings_input_sources
        Gio::SettingsSchemaSource.default.lookup('org.gnome.desktop.input-sources', true).then do |schema|
          if schema
            Gio::Settings.new('org.gnome.desktop.input-sources').get_value('sources')
          else
            []
          end
        end
      rescue StandardError, GLib::Error => e
        warn "Failed to read the input sources: #{e.message}"
        []
      end

      # The character drawn white on a transparent square, scaled so the glyph
      # fills ICON_SIZE, the way characterToIconData does with a Gtk::Snapshot.
      def icon_surface(character)
        Cairo::ImageSurface.new(:argb32, ICON_SIZE, ICON_SIZE).tap do |surface|
          Cairo::Context.new(surface).tap do |context|
            context.create_pango_layout.tap do |layout|
              layout.text = character
              draw_icon_layout(context, layout)
            end
          end
        end
      end

      def draw_icon_layout(context, layout)
        layout.pixel_size.then do |(text_width, text_height)|
          [text_width, text_height].max.then do |text_size|
            if text_size.positive?
              context.scale(ICON_SIZE / text_size, ICON_SIZE / text_size)
              context.move_to((text_size - text_width) / 2.0, (text_size - text_height) / 2.0)
              context.set_source_rgba(
                1.0,
                1.0,
                1.0,
                1.0,
              )
              context.show_pango_layout(layout)
            end
          end
        end
      end

      # Cairo's ARGB32 is premultiplied native-endian; the search provider
      # wants straight R8G8B8A8.
      def rgba_bytes(surface)
        surface.flush
        surface.data.unpack('L*').flat_map { |pixel| straight_rgba(pixel) }
      end

      def straight_rgba(pixel)
        ((pixel >> 24) & 0xFF).then do |alpha|
          if alpha.zero?
            [0, 0, 0, 0]
          else
            [16, 8, 0].map { |shift| (((pixel >> shift) & 0xFF) * 255 / alpha).clamp(0, 255) } + [alpha]
          end
        end
      end
  end
end
