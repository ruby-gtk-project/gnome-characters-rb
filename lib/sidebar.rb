# frozen_string_literal: true

require 'adwaita'
require_relative 'sidebar_item'

# Sidebar is the port of upstream's src/sidebar.js together with the template
# it loads, data/sidebar.ui: the category list down the left of the window.
#
# Upstream is an Adw.Bin wrapping an Adw.Sidebar whose three sections and
# seventeen items come from the .ui file, with an InternalChild per row and an
# itemByName switch mapping a name to the row. Here the same three sections and
# seventeen items are a table, and itemByName is a lookup in it.
class Sidebar
  SECTIONS = [
    {
      title: nil,
      items: [
        { name: 'recent', title: 'Recently Used', icon: 'document-open-recent-symbolic', category: :none },
      ],
    },
    {
      title: 'Emojis',
      items: [
        { name: 'smileys', title: 'Smileys & Emotion', icon: 'emoji-people-symbolic', category: :emoji_smileys },
        { name: 'people', title: 'People & Body', icon: 'emoji-body-symbolic', category: :emoji_people },
        { name: 'animals', title: 'Animals & Nature', icon: 'emoji-nature-symbolic', category: :emoji_animals },
        { name: 'food', title: 'Food & Drink', icon: 'emoji-food-symbolic', category: :emoji_food },
        { name: 'travel', title: 'Travel & Places', icon: 'emoji-travel-symbolic', category: :emoji_travel },
        { name: 'activities', title: 'Activities', icon: 'emoji-activities-symbolic', category: :emoji_activities },
        { name: 'objects', title: 'Objects', icon: 'emoji-objects-symbolic', category: :emoji_objects },
        { name: 'symbols', title: 'Symbols', icon: 'emoji-symbols-symbolic', category: :emoji_symbols },
        { name: 'flags', title: 'Flags', icon: 'emoji-flags-symbolic', category: :emoji_flags },
      ],
    },
    {
      title: 'Letters & Symbols',
      items: [
        {
          name:     'punctuation',
          title:    'Punctuation',
          icon:     'characters-punctuation-symbolic',
          category: :letter_punctuation,
        },
        { name: 'arrows', title: 'Arrows', icon: 'characters-arrow-symbolic', category: :letter_arrow },
        { name: 'bullets', title: 'Bullets', icon: 'characters-bullet-symbolic', category: :letter_bullet },
        { name: 'pictures', title: 'Pictures', icon: 'characters-picture-symbolic', category: :letter_picture },
        { name: 'currency', title: 'Currencies', icon: 'characters-currency-symbolic', category: :letter_currency },
        { name: 'math', title: 'Math', icon: 'characters-math-symbolic', category: :letter_math },
        { name: 'latin', title: 'Letters', icon: 'characters-latin-symbolic', category: :letter_latin },
      ],
    },
  ].freeze

  attr_accessor :last_selected_item

  def initialize(on_activated: nil)
    @on_activated = on_activated
    @last_selected_item = nil
  end

  def build
    sidebar.tap do |widget|
      SECTIONS.each do |section|
        widget.append(section_for(section))
      end

      widget.signal_connect('activated') { notify_activated }
    end
  end

  def widget = sidebar
  def selected_item = sidebar.selected_item

  # Restores the latest selected item, after a search has cleared the
  # selection.
  def restore_selection
    last_selected_item.then do |item|
      if item
        sidebar.selected = item.index
        notify_activated
      end
    end
  end

  def item_by_name(name) = items.fetch(name, items['recent'])

  def select_row_by_name(name)
    sidebar.selected = item_by_name(name).index
    notify_activated
  end

  def unselect_all
    sidebar.selected = Gtk::INVALID_LIST_POSITION
  end

  def mode = sidebar.mode

  def mode=(value)
    sidebar.mode = value
  end

  def sidebar
    @sidebar ||= Adwaita::Sidebar.new.tap do |widget|
      widget.vexpand = true
      widget.hexpand = true
    end
  end

  # name => SidebarItem, in the order the sections list them, which is the
  # order Adw.Sidebar indexes them in.
  def items
    @items ||= SECTIONS.flat_map { |section| section[:items] }.to_h do |item|
      [item[:name], SidebarItem.new(item[:title], item[:icon], item[:category])]
    end
  end

  private

    def section_for(section)
      Adwaita::SidebarSection.new.tap do |widget|
        if section[:title]
          widget.title = section[:title]
        end
        section[:items].each { |item| widget.append(items[item[:name]]) }
      end
    end

    def notify_activated
      @on_activated&.call
    end
end
