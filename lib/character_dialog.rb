# frozen_string_literal: true

require 'adwaita'
require_relative 'gc'
require_relative 'util'

# CharacterDialog is the port of upstream's src/characterDialog.js together
# with the template it loads, data/character_dialog.ui: the character blown up
# large, a Copy Character button, its Unicode code point, and a See Also page
# listing related characters.
#
# Upstream's seeAlsoRow pushes the related page through the navigation.push
# action with a page tag; here the row's activation pushes the page itself,
# which is the same navigation with one fewer indirection.
class CharacterDialog
  CONTENT_WIDTH = 360
  CONTENT_HEIGHT = 500
  RELATED_PREFIX_WIDTH = 45
  TOAST_TIMEOUT = 2

  def initialize(character, font_description, on_character_copied: nil)
    @character = character
    @font_description = font_description
    @on_character_copied = on_character_copied
    @related = []
  end

  def build
    dialog.tap do |widget|
      widget.child = toast_overlay
      widget.insert_action_group('character', action_group)

      toast_overlay.tap do |overlay|
        overlay.child = navigation_view

        navigation_view.tap do |view|
          view.add(main_page)
          view.add(related_page)
        end
      end

      main_toolbar.tap do |toolbar|
        toolbar.add_top_bar(Adwaita::HeaderBar.new)
        toolbar.content = main_scrolled
      end

      main_scrolled.tap do |scrolled|
        scrolled.child = main_box

        main_box.tap do |box|
          box.append(character_stack)
          box.append(copy_button)
          box.append(detail_clamp)

          character_stack.tap do |stack|
            stack.add_named(character_label, 'character')
            stack.add_named(missing_label, 'missing')
          end

          detail_clamp.tap do |clamp|
            clamp.child = detail_list

            detail_list.tap do |list|
              list.append(detail_row)
              list.append(see_also_row)

              detail_row.tap { |row| row.add_suffix(detail_label) }

              see_also_row.tap do |row|
                row.add_suffix(Gtk::Image.new.tap { |image| image.icon_name = 'go-next-symbolic' })
                row.signal_connect('activated') { navigation_view.push(related_page) }
              end
            end
          end
        end
      end

      related_toolbar.tap do |toolbar|
        toolbar.add_top_bar(Adwaita::HeaderBar.new)
        toolbar.content = related_scrolled
      end

      related_scrolled.tap do |scrolled|
        scrolled.child = related_clamp
        related_clamp.tap { |clamp| clamp.child = related_listbox }
      end

      related_page.signal_connect('hidden') { populate_related_page }

      show_character(@character)
    end
  end

  def present(parent)
    dialog.present(parent)
  end

  private

    def show_character(character)
      @character = character
      character_name_for(character).then do |name|
        dialog.title = name.to_s
        main_page.title = name.to_s
        character_label.label = character
        update_detail_row(character, name)
        update_character_stack(character, name)
      end

      search_related(character)
    end

    def character_name_for(character)
      Gc.character_name(character).then do |name|
        if name
          Util.capitalize(name)
        else
          fallback_name(character)
        end
      end
    end

    def fallback_name(character)
      if Gc.character_is_composite?(character)
        'Unknown character name'
      else
        code_point_label(character)
      end
    end

    def code_point_label(character)
      format('U+%04X', Util.to_code_point(character))
    end

    def update_detail_row(character, _name)
      if Gc.character_is_composite?(character)
        detail_row.visible = false
      else
        detail_label.label = code_point_label(character)
        detail_row.visible = true
      end
    end

    def update_character_stack(character, name)
      measure_layout(character).then do |layout|
        if layout.unknown_glyphs_count.zero?
          character_stack.visible_child_name = 'character'
        else
          # TRANSLATORS: the first variable is a character, the second a font.
          missing_label.label = format('%s is not included in %s', name, @font_description.family)
          character_stack.visible_child_name = 'missing'
        end
      end
    end

    def measure_layout(character)
      Pango::Layout.new(character_label.pango_context).tap do |layout|
        layout.font_description = @font_description
        layout.text = character
      end
    end

    def search_related(character)
      see_also_row.visible = false
      @search_context&.cancel
      Gc::SearchContext.new(Gc::SearchCriteria.related(character)).tap do |context|
        @search_context = context
        @related = []
        context.search(
          on_batch:    method(:add_related),
          on_finished: method(:finish_related_search),
        )
      end
    end

    def add_related(batch)
      @related.concat(batch)
    end

    def finish_related_search(_total)
      see_also_row.visible = @related.any?
      unless related_page.mapped?
        populate_related_page
      end
    end

    def populate_related_page
      related_listbox.remove_all
      @related.each do |character|
        Gc.character_name(character).then do |name|
          if name
            related_listbox.append(related_row(character, name))
          end
        end
      end
    end

    def related_row(character, name)
      Adwaita::ActionRow.new.tap do |row|
        row.title = Util.capitalize(name)
        row.activatable = true
        row.add_prefix(related_prefix(character))
        row.signal_connect('activated') do
          show_character(character)
          navigation_view.pop
        end
      end
    end

    def related_prefix(character)
      Gtk::Label.new(character).tap do |label|
        label.valign = :center
        label.halign = :center
        label.width_request = RELATED_PREFIX_WIDTH
      end
    end

    def copy_character
      Gdk::Display.default.clipboard.tap do |clipboard|
        clipboard.set(@character)
        @on_character_copied&.call(@character)
        toast_overlay.add_toast(copy_toast)
      end
    end

    def copy_toast
      Adwaita::Toast.new('Character copied to clipboard').tap do |toast|
        toast.timeout = TOAST_TIMEOUT
      end
    end

    def action_group
      @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
        Util.init_actions(group, [{ name: 'copy', activate: ->(_parameter) { copy_character } }])
      end
    end

  public

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |widget|
        widget.content_width = CONTENT_WIDTH
        widget.content_height = CONTENT_HEIGHT
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
    def navigation_view = @navigation_view ||= Adwaita::NavigationView.new
    def main_page = @main_page ||= Adwaita::NavigationPage.new(main_toolbar, 'Character')
    def main_toolbar = @main_toolbar ||= Adwaita::ToolbarView.new

    def related_page
      @related_page ||= Adwaita::NavigationPage.new(related_toolbar, 'See Also').tap do |page|
        page.tag = 'related'
      end
    end

    def related_toolbar = @related_toolbar ||= Adwaita::ToolbarView.new

    def main_scrolled
      @main_scrolled ||= Gtk::ScrolledWindow.new.tap do |scrolled|
        scrolled.hscrollbar_policy = :never
        scrolled.vexpand = true
      end
    end

    def main_box
      @main_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.halign = :fill
        box.valign = :center
      end
    end

    def character_stack = @character_stack ||= Gtk::Stack.new

    def character_label
      @character_label ||= Gtk::Label.new.tap do |label|
        label.ellipsize = :end
        label.halign = :center
        label.valign = :center
        label.add_css_class('character-label')
      end
    end

    def missing_label
      @missing_label ||= Gtk::Label.new.tap do |label|
        label.halign = :center
        label.valign = :center
        label.wrap = true
        label.wrap_mode = :word
        label.width_chars = 28
        label.max_width_chars = 28
        label.justify = :center
      end
    end

    def copy_button
      @copy_button ||= Gtk::Button.new.tap do |button|
        button.margin_top = 18
        button.margin_bottom = 18
        button.halign = :center
        button.label = '_Copy Character'
        button.use_underline = true
        button.action_name = 'character.copy'
        button.add_css_class('pill')
      end
    end

    def detail_clamp
      @detail_clamp ||= Adwaita::Clamp.new.tap do |clamp|
        clamp.margin_top = 18
        clamp.margin_bottom = 18
        clamp.margin_start = 18
        clamp.margin_end = 18
        clamp.vexpand = true
        clamp.valign = :center
      end
    end

    def detail_list
      @detail_list ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class('boxed-list')
      end
    end

    def detail_row = @detail_row ||= Adwaita::ActionRow.new.tap { |row| row.title = 'Unicode' }

    def detail_label
      @detail_label ||= Gtk::Label.new.tap do |label|
        label.selectable = true
        label.add_css_class('dim-label')
      end
    end

    def see_also_row
      @see_also_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = '_See Also'
        row.use_underline = true
        row.activatable = true
      end
    end

    def related_scrolled
      @related_scrolled ||= Gtk::ScrolledWindow.new.tap do |scrolled|
        scrolled.hscrollbar_policy = :never
        scrolled.vexpand = true
      end
    end

    def related_clamp
      @related_clamp ||= Adwaita::Clamp.new.tap do |clamp|
        clamp.margin_top = 36
        clamp.margin_bottom = 36
        clamp.margin_start = 18
        clamp.margin_end = 18
        clamp.vexpand = true
        clamp.valign = :center
      end
    end

    def related_listbox
      @related_listbox ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class('boxed-list')
      end
    end
end
