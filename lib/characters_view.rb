# frozen_string_literal: true

require 'adwaita'
require_relative 'gc'
require_relative 'util'

# CharactersView is the port of upstream's src/charactersView.js: the grid of
# characters, drawn glyph by glyph rather than built out of widgets, and the
# searches that fill it.
#
# Upstream is a Gtk.Widget implementing Gtk.Scrollable, with vfunc_measure,
# vfunc_size_allocate and vfunc_snapshot, plus a CharacterListRow class that
# snapshots one row. This port draws into a Gtk::DrawingArea sized to the whole
# character list and held in its own Gtk::ScrolledWindow, so the scrolling the
# Scrollable implementation provides upstream comes from the scrolled window
# here. The drawing — cell size from the font description, the baseline at
# 0.85 of the cell, the bounding box and wrapped character name for anything
# the font cannot render — is the same, through Cairo instead of Gsk.
class CharactersView
  BASELINE_OFFSET = 0.85
  CELLS_PER_ROW = 5
  NUM_ROWS = 5
  NUM_COLUMNS = 3
  CELL_SIZE = 50
  OVERLAY_FONT_SCALE = 0.8
  BOX_ALPHA = 0.05
  BORDER_WIDTH = 1

  attr_reader :characters

  def initialize(on_character_selected: nil, on_loading_changed: nil)
    @on_character_selected = on_character_selected
    @on_loading_changed = on_loading_changed
    @characters = []
    @rows = []
    @cells_per_row = CELLS_PER_ROW
    @baseline = true
    @loading = false
    @scripts = []
    @scripts_loaded = false
    @offset_x = 0
  end

  def build
    scrolled_window.tap do |window|
      window.child = drawing_area

      drawing_area.tap do |area|
        area.set_draw_func { |_widget, context, width, height| draw(context, width, height) }
        area.signal_connect('resize') { |_widget, width, _height| resize(width) }
        area.add_controller(gesture_click)

        gesture_click.tap do |gesture|
          gesture.signal_connect('pressed') { |_gesture, _presses, x, y| press(x, y) }
          gesture.signal_connect('released') { release }
        end
      end
    end
  end

  def widget = scrolled_window

  def font_description
    @font_description ||= drawing_area.pango_context.font_description.dup.tap do |description|
      description.absolute_size = CELL_SIZE * Pango::SCALE * 96 / 72
    end
  end

  def baseline=(value)
    @baseline = value
    drawing_area.queue_draw
  end

  def characters=(list)
    @characters = list
    reflow
  end

  def reset_scroll
    scrolled_window.vadjustment.value = 0.0
  end

  # searchByCategory: the baseline is drawn for everything up to the Letters
  # page and for the recently used page, and not for the emoji pages.
  def search_by_category(category)
    self.characters = []
    self.baseline = Gc.baseline_category?(category)

    if category == :letter_latin
      search_latin
    else
      start_search(Gc::SearchCriteria.category(category))
    end
  end

  def search_by_keywords(keywords, on_finished: nil)
    self.characters = []
    start_search(
      Gc::SearchCriteria.keywords(keywords),
      flags:       [:word],
      on_finished: on_finished,
    )
  end

  def cancel_search
    @search_context&.cancel
    @search_context = nil
  end

  private

    def start_search(criteria, flags: [], on_finished: nil)
      cancel_search
      Gc::SearchContext.new(criteria, flags: flags).tap do |context|
        @search_context = context
        context.search(
          on_batch:    method(:add_search_result),
          on_finished: on_finished,
        )
      end
    end

    def add_search_result(batch)
      if batch.any?
        self.characters = characters + batch
      end
    end

    # populateScripts: upstream asks gnome-desktop to turn each configured
    # input source into a list of languages, then asks libgc for the scripts
    # of each. gnome-desktop has no Ruby bindings here, so the languages are
    # the current locale's plus any input source id that is itself a language
    # upstream's table knows — which is what the ibus ids ("anthy", "pinyin")
    # and the xkb layouts ("us", "ru") amount to in that table.
    def search_latin
      if @scripts_loaded
        search_by_scripts
      else
        self.loading = true
        populate_scripts
      end
    end

    def populate_scripts
      languages.then do |names|
        @scripts = script_names(names)
        @scripts_loaded = true
        self.loading = false
        search_by_scripts
      end
    end

    def languages
      Util.input_sources.map { |(_type, id)| Gc.normalize_language(id.to_s) }
          .push(Gc.current_language)
    end

    # Latin always comes first, and Han is left out because it holds far too
    # many characters for one page.
    def script_names(languages)
      languages.flat_map { |language| Gc.scripts_for_language(language) }
               .reject { |script| %w[Latin Han].include?(script) }
               .uniq
               .unshift('Latin')
    end

    def search_by_scripts
      start_search(Gc::SearchCriteria.scripts(@scripts))
    end

    def loading=(value)
      @loading = value
      @on_loading_changed&.call(value)
    end

    def cell_size
      font_description.then do |description|
        if description.size.zero?
          CELL_SIZE
        else
          absolute_size(description) * 2 / Pango::SCALE
        end
      end
    end

    def absolute_size(description)
      if description.size_is_absolute?
        description.size * 72 / 96
      else
        description.size
      end
    end

    def reflow
      @rows = characters.each_slice(@cells_per_row).to_a
      drawing_area.content_height = (([@rows.length, NUM_ROWS].max + BASELINE_OFFSET) * cell_size).floor
      drawing_area.content_width = NUM_COLUMNS * cell_size
      drawing_area.queue_draw
    end

    def resize(width)
      [1, (width / cell_size).floor].max.then do |cells_per_row|
        if cells_per_row != @cells_per_row
          @cells_per_row = cells_per_row
          reflow
        end
      end
    end

    def press(x, y)
      [@cells_per_row - 1, ((x - @offset_x) / cell_size).floor].min.then do |column|
        (y / cell_size).floor.then do |row|
          (row * @cells_per_row) + [0, column].max
        end
      end.then do |index|
        if index < characters.length
          @selected_character = characters[index]
        else
          @selected_character = nil
        end
      end
    end

    def release
      @selected_character.then do |character|
        if character
          @on_character_selected&.call(character)
        end
      end
    end

    # --- drawing ---------------------------------------------------------

    def draw(context, width, _height)
      @offset_x = (width - (cell_size * @cells_per_row)) / 2.0
      visible_rows.each do |index|
        draw_row(context, index, width)
      end
    end

    def visible_rows
      scrolled_window.vadjustment.then do |adjustment|
        [0, (adjustment.value / cell_size).floor].max.then do |first|
          [@rows.length, ((adjustment.value + adjustment.page_size) / cell_size).ceil + 1].min.then do |last|
            (first...last)
          end
        end
      end
    end

    def draw_row(context, index, width)
      (index * cell_size).then do |y|
        if @baseline
          draw_baseline(context, y, width)
        end

        @rows[index].each_with_index do |character, column|
          draw_character(
            context,
            character,
            @offset_x + (cell_size * column),
            y,
          )
        end
      end
    end

    def draw_baseline(context, y, width)
      context.save
      set_source(context, border_color)
      context.rectangle(
        0,
        y + (BASELINE_OFFSET * cell_size),
        width,
        1.0,
      )
      context.fill
      context.restore
    end

    def draw_character(context, character, x, y)
      character_layout.then do |layout|
        layout.text = character
        if Gc.character_is_invisible?(character) || layout.unknown_glyphs_count.positive?
          draw_bounding_box(
            context,
            layout,
            x,
            y,
          )
          draw_character_name(
            context,
            character,
            x,
            y,
          )
        else
          draw_glyph(
            context,
            layout,
            x,
            y,
          )
        end
      end
    end

    def draw_glyph(context, layout, x, y)
      layout.extents.then do |(ink, _logical)|
        context.save
        set_source(context, text_color)
        context.move_to(
          x - (ink.x / Pango::SCALE) + ((cell_size - (ink.width / Pango::SCALE)) / 2.0),
          y + (BASELINE_OFFSET * cell_size) - (layout.baseline / Pango::SCALE),
        )
        context.show_pango_layout(layout)
        context.restore
      end
    end

    # The faint square shown in place of a glyph the font has not got, sized
    # from the layout when there is one and from 'AA' when there is not.
    def draw_bounding_box(context, layout, x, y)
      shape_rect(layout, x, y).then do |rect|
        context.save
        set_source(context, box_color)
        context.rectangle(
          rect[:x] - (BORDER_WIDTH * 2),
          rect[:y] - (BORDER_WIDTH * 2),
          rect[:width] + (BORDER_WIDTH * 2),
          rect[:height] + (BORDER_WIDTH * 2),
        )
        context.fill
        context.restore
      end
    end

    def shape_rect(layout, x, y)
      shape_extents(layout).then do |(rect, baseline)|
        {
          x:      x - (rect.x / Pango::SCALE) + ((cell_size - (rect.width / Pango::SCALE)) / 2.0),
          y:      y + (BASELINE_OFFSET * cell_size) - (baseline / Pango::SCALE),
          width:  rect.width / Pango::SCALE,
          height: rect.height / Pango::SCALE,
        }
      end
    end

    def shape_extents(layout)
      if layout.unknown_glyphs_count.zero?
        [layout.extents[1], layout.baseline]
      else
        base_glyph_extents
      end
    end

    def base_glyph_extents
      @base_glyph_extents ||= base_glyph_layout.then do |layout|
        [layout.extents[1], layout.baseline]
      end
    end

    # The 'AA' layout upstream measures once and keeps, to size the box drawn
    # for a character the font has not got.
    def base_glyph_layout
      @base_glyph_layout ||= Pango::Layout.new(drawing_area.pango_context).tap do |layout|
        layout.font_description = font_description
        layout.text = 'AA'
      end
    end

    def draw_character_name(context, character, x, y)
      overlay_layout.tap do |layout|
        layout.text = character_name_text(character)
        layout.extents.then do |(ink, _logical)|
          context.save
          set_source(context, text_color)
          context.move_to(
            x - (ink.x / Pango::SCALE) + ((cell_size - (ink.width / Pango::SCALE)) / 2.0),
            y - (ink.y / Pango::SCALE) + ((cell_size - (ink.height / Pango::SCALE)) / 2.0),
          )
          context.show_pango_layout(layout)
          context.restore
        end
      end
    end

    def character_name_text(character)
      Gc.character_name(character).then do |name|
        if name
          Util.capitalize(name)
        else
          'Unassigned'
        end
      end
    end

    def set_source(context, color)
      context.set_source_rgba(
        color.red,
        color.green,
        color.blue,
        color.alpha,
      )
    end

    def text_color = drawing_area.style_context.color

    def border_color
      drawing_area.style_context.lookup_color('borders').then do |(found, color)|
        if found
          color
        else
          text_color
        end
      end
    end

    def box_color
      Gdk::RGBA.new(
        text_color.red,
        text_color.green,
        text_color.blue,
        BOX_ALPHA,
      )
    end

    def character_layout
      @character_layout ||= Pango::Layout.new(drawing_area.pango_context).tap do |layout|
        layout.font_description = font_description
      end
    end

    def overlay_layout
      @overlay_layout ||= Pango::Layout.new(drawing_area.pango_context).tap do |layout|
        layout.width = (cell_size * Pango::SCALE * OVERLAY_FONT_SCALE).to_i
        layout.height = (cell_size * Pango::SCALE * OVERLAY_FONT_SCALE).to_i
        layout.wrap = :word
        layout.ellipsize = :end
        layout.alignment = :center
        layout.font_description = overlay_font_description
      end
    end

    def overlay_font_description
      @overlay_font_description ||= drawing_area.pango_context.font_description.dup.tap do |description|
        description.size = (description.size * OVERLAY_FONT_SCALE).to_i
      end
    end

    def gesture_click = @gesture_click ||= Gtk::GestureClick.new

    def drawing_area
      @drawing_area ||= Gtk::DrawingArea.new.tap do |area|
        area.hexpand = true
        area.vexpand = true
      end
    end

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
        window.hscrollbar_policy = :never
        window.hexpand = true
        window.vexpand = true
        window.add_css_class('character-list-scroll')
      end
    end
end
