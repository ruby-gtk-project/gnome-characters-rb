# frozen_string_literal: true

require 'adwaita'
require_relative 'about_dialog'
require_relative 'character_dialog'
require_relative 'characters_view'
require_relative 'gc'
require_relative 'sidebar'
require_relative 'util'

# MainWindow is the port of upstream's src/window.js together with the
# template it loads, data/window.ui — including the primary menu that .ui file
# declares, which is built here as a Gio::Menu.
#
# The split view, its sidebar page and content page, the search bar, the four
# stack pages (recently used when empty, the character list, no results, and
# the spinner) and the breakpoint that collapses the split view on a narrow
# window are all upstream's.
class MainWindow
  DEFAULT_WIDTH = 800
  DEFAULT_HEIGHT = 600
  MINIMUM_WIDTH = 360
  MINIMUM_HEIGHT = 294
  COLLAPSE_WIDTH = 500

  def initialize(application, settings)
    @application = application
    @settings = settings
    @search_keywords = []
    @recent_characters = settings.recent_characters
    @max_recent_characters = settings.max_recent_characters
  end

  def build
    window.tap do |widget|
      widget.content = split_view
      widget.add_breakpoint(breakpoint)

      Util.init_actions(
        widget,
        [
          { name: 'about', activate: ->(_parameter) { show_about } },
          { name: 'find', activate: ->(_parameter) { toggle_search } },
        ],
      )

      split_view.tap do |view|
        view.sidebar = sidebar_page
        view.content = content_page
      end

      sidebar_toolbar.tap do |toolbar|
        toolbar.add_top_bar(sidebar_header)
        toolbar.add_top_bar(search_bar)
        toolbar.content = sidebar_scrolled

        sidebar_header.tap do |header|
          header.pack_start(search_button)
          header.pack_end(primary_menu_button)
        end

        search_bar.tap do |bar|
          bar.child = search_entry
          bar.key_capture_widget = widget
        end

        sidebar_scrolled.tap { |scrolled| scrolled.child = sidebar.build }
      end

      content_toolbar.tap do |toolbar|
        toolbar.add_top_bar(Adwaita::HeaderBar.new)
        toolbar.content = main_stack

        main_stack.tap do |stack|
          stack.add_named(empty_recent_page, 'empty-recent')
          stack.add_named(characters_view.build, 'character-list')
          stack.add_named(no_results_page, 'no-results')
          stack.add_named(Adwaita::Spinner.new, 'loading')
        end
      end

      connect_search(widget)
      widget.signal_connect_after('map') { select_initial_page }
    end
  end

  def present
    window.present
  end

  # LaunchSearch on the search provider interface: fill the search bar in and
  # show what the shell was searching for.
  def search_keywords=(terms)
    search_entry.text = terms.join(' ')
    search_button.active = true
  end

  def max_recent_characters = @max_recent_characters

  def max_recent_characters=(value)
    @max_recent_characters = value
    @recent_characters = @recent_characters.first(value)
  end

  private

    def connect_search(widget)
      search_button.tap do |button|
        button.bind_property(
          'active',
          search_bar,
          'search-mode-enabled',
          %i[sync_create bidirectional],
        )

        button.signal_connect('toggled') { update_search_entry(button.active?) }
      end

      search_entry.tap do |entry|
        entry.signal_connect('search-changed') { handle_search_changed(entry) }
        entry.signal_connect('search-started') { start_search }
        entry.signal_connect('stop-search') { stop_search }
        entry.signal_connect('activate') { split_view.show_content = true }
      end

      widget
    end

    def update_search_entry(active)
      if active
        search_entry.grab_focus
      else
        search_entry.text = ''
      end

      self.search_active = active
    end

    def start_search
      self.search_active = true
      search_button.active = true
    end

    def stop_search
      self.search_active = false
      search_button.active = false
    end

    # Searching clears the sidebar selection; leaving the search restores it,
    # but only on desktop — a sudden page change on mobile is disorienting.
    def search_active=(active)
      if active
        sidebar.unselect_all
        content_page.title = 'Search Result'
      elsif sidebar.mode != Adwaita::SidebarMode::PAGE
        sidebar.restore_selection
      end
    end

    def handle_search_changed(entry)
      entry.text.strip.then do |text|
        if text.empty?
          []
        else
          text.split(/\s+/).map(&:upcase)
        end
      end.then do |keywords|
        characters_view.cancel_search
        @search_keywords = keywords
        if keywords.any?
          search_by_keywords(keywords)
        end
      end
    end

    def search_by_keywords(keywords)
      characters_view.search_by_keywords(keywords, on_finished: method(:finish_keyword_search))
    end

    def finish_keyword_search(total)
      if total.zero?
        main_stack.visible_child_name = 'no-results'
      else
        main_stack.visible_child_name = 'character-list'
      end
    end

    def handle_sidebar_activated
      characters_view.reset_scroll
      sidebar.selected_item.then do |item|
        if item
          sidebar.last_selected_item = item
          set_page(item)
          content_page.title = item.title
          split_view.show_content = true
        end
      end
    end

    def set_page(item)
      if item.category == :none
        show_recent_page
      else
        characters_view.search_by_category(item.category)
        main_stack.visible_child_name = 'character-list'
      end
    end

    # The recently used page always draws a baseline.
    def show_recent_page
      characters_view.baseline = true
      if @recent_characters.empty?
        main_stack.visible_child_name = 'empty-recent'
      else
        characters_view.characters = @recent_characters
        main_stack.visible_child_name = 'character-list'
      end
    end

    # Select the recently used page when there is something on it, and the
    # first emoji page otherwise.
    def select_initial_page
      if @recent_characters.empty?
        sidebar.select_row_by_name('smileys')
      else
        sidebar.select_row_by_name('recent')
      end
    end

    def handle_loading_changed(loading)
      if loading
        main_stack.visible_child_name = 'loading'
      else
        main_stack.visible_child_name = 'character-list'
      end
    end

    def handle_character_selected(character)
      CharacterDialog.new(
        character,
        characters_view.font_description,
        on_character_copied: method(:add_to_recent),
      ).tap do |dialog|
        dialog.build
        dialog.present(window)
      end
    end

    def add_to_recent(character)
      unless @recent_characters.include?(character)
        @recent_characters = @recent_characters.unshift(character).first(@max_recent_characters)
        @settings.recent_characters = @recent_characters
      end
    end

    def show_about
      AboutDialog.new.tap do |dialog|
        dialog.build
        dialog.present(window)
      end
    end

    def toggle_search
      search_button.active = !search_button.active?
    end

    # --- widgets ---------------------------------------------------------

    def window
      @window ||= Adwaita::ApplicationWindow.new(@application).tap do |widget|
        widget.title = GLib.application_name
        widget.set_default_size(DEFAULT_WIDTH, DEFAULT_HEIGHT)
        widget.width_request = MINIMUM_WIDTH
        widget.height_request = MINIMUM_HEIGHT
      end
    end

    def sidebar = @sidebar ||= Sidebar.new(on_activated: method(:handle_sidebar_activated))

    def characters_view
      @characters_view ||= CharactersView.new(
        on_character_selected: method(:handle_character_selected),
        on_loading_changed:    method(:handle_loading_changed),
      )
    end

    def split_view = @split_view ||= Adwaita::NavigationSplitView.new
    def sidebar_page = @sidebar_page ||= Adwaita::NavigationPage.new(sidebar_toolbar, 'Characters')
    def sidebar_toolbar = @sidebar_toolbar ||= Adwaita::ToolbarView.new
    def sidebar_header = @sidebar_header ||= Adwaita::HeaderBar.new
    def content_toolbar = @content_toolbar ||= Adwaita::ToolbarView.new.tap { |view| view.add_css_class('view') }

    def content_page
      @content_page ||= Adwaita::NavigationPage.new(content_toolbar, 'Characters').tap do |page|
        page.tag = 'content'
      end
    end

    def sidebar_scrolled
      @sidebar_scrolled ||= Gtk::ScrolledWindow.new.tap do |scrolled|
        scrolled.hscrollbar_policy = :never
      end
    end

    def search_button
      @search_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = 'edit-find-symbolic'
        button.tooltip_text = 'Search'
      end
    end

    def primary_menu_button
      @primary_menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.menu_model = primary_menu
        button.icon_name = 'open-menu-symbolic'
        button.tooltip_text = 'Main Menu'
        button.primary = true
      end
    end

    # The primary_menu of data/window.ui.
    def primary_menu
      @primary_menu ||= Gio::Menu.new.tap do |menu|
        Gio::Menu.new.tap do |section|
          section.append('_Keyboard Shortcuts', 'app.shortcuts')
          section.append('_About Characters', 'win.about')
          menu.append_section(nil, section)
        end
      end
    end

    def search_bar = @search_bar ||= Gtk::SearchBar.new

    def search_entry
      @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.placeholder_text = 'Search characters'
        entry.hexpand = true
      end
    end

    def main_stack
      @main_stack ||= Gtk::Stack.new.tap do |stack|
        stack.hexpand = true
        stack.vexpand = true
        stack.transition_type = :crossfade
      end
    end

    def empty_recent_page
      @empty_recent_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = 'characters-punctuation-symbolic'
        page.title = 'No Recent Characters'
        page.description = 'Characters will appear here if you use them'
      end
    end

    def no_results_page
      @no_results_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = 'system-search-symbolic'
        page.title = 'No Results'
        page.description = 'Try a different search'
      end
    end

    # adw_breakpoint_add_setter takes a GValue, and these bindings do not box
    # a plain Ruby value for it.
    def boolean_value(value) = GLib::Value.new(GLib::Type::BOOLEAN, value)
    def sidebar_mode_value(value) = GLib::Value.new(Adwaita::SidebarMode.gtype, value)

    def breakpoint
      @breakpoint ||= Adwaita::Breakpoint.new(
        Adwaita::BreakpointCondition.parse("max-width: #{COLLAPSE_WIDTH}px"),
      ).tap do |point|
        point.add_setter(split_view, 'collapsed', boolean_value(true))
        point.add_setter(sidebar.widget, 'mode', sidebar_mode_value(Adwaita::SidebarMode::PAGE))
      end
    end
end
