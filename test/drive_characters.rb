# frozen_string_literal: true

# Drives the whole app headlessly: builds the window, walks the sidebar
# categories, lets a search run to completion, clicks a character cell open
# into its dialog, copies a character, opens See Also, triggers the collapse
# breakpoint, and opens the shortcuts and about dialogs. Screenshots each
# state.
#
# Why this file exists: a GTK app that loads is not a GTK app that works.
# `ruby -c` passes on code that builds an empty window, and the first real run
# of this script is what proved the sidebar's `private` section had locked
# every widget accessor away from anything outside the class, including this
# driver — nothing upstream of GTK itself would ever have caught that.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_characters.rb
#
# GTK4 here has no offscreen backend - gtk_init fails outright with no
# display - so xvfb-run is not optional on this machine.

require 'fileutils'
require 'tmpdir'

# A scratch config directory, so a run never reads or writes the real one.
ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('characters-drive')

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'main'
require_relative 'gtk_driver'

SHOTS = File.expand_path('../tmp/shots', __dir__)
FileUtils.rm_rf(SHOTS)

# Turns the main loop over for `ms` milliseconds and comes back.
#
# A step cannot sleep: every step runs inside a GLib timeout, so the clock the
# step is waiting on is dispatched by the very loop a sleep would block. This
# iterates the default context without blocking until the deadline passes,
# which dispatches the idle handler Gc::SearchContext#search arms.
def pump(ms)
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) + (ms / 1000.0)).then do |deadline|
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      GLib::MainContext.default.iteration(false)
    end
  end
end

# Every Gtk::Label text in a widget tree, used to confirm the shortcuts and
# about dialogs really built the rows upstream's data describes rather than
# an empty page.
def labels(widget, found = [])
  found.tap do
    if widget.is_a?(Gtk::Label)
      found << widget.label
    end
    widget.first_child.then do |first|
      child = first
      while child
        labels(child, found)
        child = child.next_sibling
      end
    end
  end
end

# The Gtk::DrawingArea CharactersView draws into, reached the way the widget
# tree really nests it (ScrolledWindow -> Viewport -> DrawingArea) rather than
# through a private accessor, so the click below exercises the same gesture a
# pointer would deliver.
def drawing_area(characters_view)
  characters_view.widget.child.child
end

# The Gtk::GestureClick CharactersView attached to its drawing area.
def click_gesture(area)
  area.observe_controllers.to_a.find { |controller| controller.is_a?(Gtk::GestureClick) }
end

APP_ID = 'org.gnome.CharactersRb.Drive'

GtkDriver.drive(App.new(app_id: APP_ID), shots: SHOTS) do |d, app|
  d.window { app.main_window.window }

  d.step('the window builds and shows the initial sidebar page') do
    window = app.main_window
    d.check('the window is an Adwaita::ApplicationWindow') do
      window.window.is_a?(Adwaita::ApplicationWindow)
    end
    d.check('it is the only toplevel') { Gtk::Window.list_toplevels.length == 1 }
    d.check('its title comes from the application name') { window.window.title == 'Characters' }
    d.check('nothing is recent, so the first emoji page is selected') do
      window.sidebar.selected_item.title == 'Smileys & Emotion'
    end
    d.check('the character list is the stack page') do
      window.main_stack.visible_child_name == 'character-list'
    end
  end

  # The shot waits a tick of its own: a window whose content changed in this
  # tick has not been laid out again yet, and Gtk::WidgetPaintable then
  # produces no render node at all rather than a stale picture.
  d.step('the smileys page renders') { d.shot('01-smileys') }

  d.step('the search runs to completion') { pump(600) }

  d.step('the smileys page has characters, and draws no baseline') do
    window = app.main_window
    d.check('at least one character loaded') { window.characters_view.characters.any? }
    d.check('emoji pages draw no baseline') { !window.characters_view.instance_variable_get(:@baseline) }
  end

  d.step('selecting Recently Used with nothing recent shows the empty state') do
    app.main_window.sidebar.select_row_by_name('recent')
  end

  d.step('the empty-recent status page is showing') do
    window = app.main_window
    d.check('the stack is on empty-recent') { window.main_stack.visible_child_name == 'empty-recent' }
    d.check('the recent page draws a baseline') { window.characters_view.instance_variable_get(:@baseline) }
  end

  d.step('the empty-recent page renders') { d.shot('02-empty-recent') }

  d.step('selecting Letters searches by the current script') do
    app.main_window.sidebar.select_row_by_name('latin')
  end

  d.step('the Latin search runs') { pump(600) }

  d.step('the letters page is populated with a baseline') do
    window = app.main_window
    d.check('on the character list') { window.main_stack.visible_child_name == 'character-list' }
    d.check('characters loaded') { window.characters_view.characters.any? }
    d.check('letters draw a baseline') { window.characters_view.instance_variable_get(:@baseline) }
  end

  d.step('the letters page renders') { d.shot('03-latin') }

  d.step('clicking a drawn cell opens the character dialog') do
    window = app.main_window
    area = drawing_area(window.characters_view)
    gesture = click_gesture(area)
    gesture.signal_emit(
      'pressed',
      1,
      25.0,
      25.0,
    )
    gesture.signal_emit(
      'released',
      1,
      25.0,
      25.0,
    )
  end

  d.step('the dialog is open on the clicked character') do
    window = app.main_window
    d.check('character_dialog was built') { !window.character_dialog.nil? }
    d.check('it is the window\'s visible dialog') { window.window.visible_dialog.equal?(window.character_dialog.dialog) }
    d.check('the character label shows text') { !window.character_dialog.character_label.label.to_s.empty? }
  end

  d.step('the character dialog renders') { d.shot('04-character-dialog') }

  d.step('copying the character adds a toast and fires the callback') do
    window = app.main_window
    character = window.character_dialog.instance_variable_get(:@character)
    # gtk_widget_activate declines on a widget that is not mapped, and the
    # copy button has only just been built inside a freshly presented dialog
    # — "clicked" is the signal a pointer would actually send.
    window.character_dialog.copy_button.signal_emit('clicked')
    d.check('the clipboard holds plain text now') do
      Gdk::Display.default.clipboard.formats.contain_mime_type('text/plain;charset=utf-8')
    end
    d.check('the character is now recorded as recent') do
      app.settings.recent_characters.include?(character)
    end
  end

  d.step('See Also pushes the related page when there are related characters') do
    window = app.main_window
    dialog = window.character_dialog
    if dialog.see_also_row.visible?
      dialog.see_also_row.signal_emit('activated')
    end
  end

  d.step('the related page, if pushed, renders') do
    window = app.main_window
    dialog = window.character_dialog
    d.check('the related listbox has no raise even with none selected') { !dialog.related_listbox.nil? }
  end

  d.step('the See Also state renders') { d.shot('05-see-also') }

  d.step('closing the dialog clears visible_dialog') do
    window = app.main_window
    window.character_dialog.dialog.close
    d.check('no dialog is showing now') { window.window.visible_dialog.nil? }
  end

  d.step('typing in the search bar filters by keyword') do
    window = app.main_window
    window.search_button.active = true
    window.search_entry.text = 'a'
  end

  d.step('the search bar search runs') { pump(600) }

  d.step('the search produced a page, either results or none') do
    window = app.main_window
    d.check('the stack moved off the sidebar categories') do
      %w[character-list no-results loading].include?(window.main_stack.visible_child_name)
    end
  end

  d.step('the search result page settles') { pump(300) }

  # The grid inside the stack page gets its size-allocate pass on a
  # frame-clock tick, not merely from iterating the main context without
  # blocking, so one `pump` can still land one tick too early and the
  # renderer gets back no render node — more likely still under whatever
  # else is sharing this machine's CPU. Retrying with a fresh pump between
  # attempts rides out that scheduling jitter without hiding a real
  # failure: if the page genuinely never renders, every attempt fails and
  # the check below still reports it.
  d.step('the search result page renders') do
    path = nil
    5.times do
      path = d.shot('06-search')
      break if path
      pump(300)
    end
    d.check('the search result page produced a screenshot') { !path.nil? }
  end

  d.step('closing search restores the previous sidebar selection') do
    app.main_window.search_button.active = false
  end

  d.step('the Letters page is back') do
    window = app.main_window
    d.check('sidebar selection restored to Letters') do
      window.sidebar.selected_item.title == 'Letters'
    end
  end

  d.step('narrowing the window trips the collapse breakpoint') do
    window = app.main_window.window
    window.default_width = 400
    window.default_height = 400
  end

  d.step('the split view collapsed and the sidebar switched to page mode') do
    window = app.main_window
    d.check('the split view is collapsed') { window.split_view.collapsed? }
    d.check('the sidebar mode switched to PAGE') do
      window.sidebar.mode == Adwaita::SidebarMode::PAGE
    end
  end

  d.step('the collapsed layout renders') { d.shot('07-collapsed') }

  d.step('widening the window back restores the split view') do
    window = app.main_window.window
    window.default_width = 800
    window.default_height = 600
  end

  d.step('the split view is uncollapsed again') do
    window = app.main_window
    d.check('no longer collapsed') { !window.split_view.collapsed? }
  end

  d.step('the app.shortcuts action opens the shortcuts dialog') do
    app.build.activate_action('shortcuts', nil)
  end

  d.step('the shortcuts dialog shows upstream\'s four General items') do
    window = app.main_window.window
    d.check('a dialog is showing') { !window.visible_dialog.nil? }
    found = labels(window.visible_dialog)
    ['Open Main Menu', 'Search', 'Show Keyboard Shortcuts', 'Quit'].each do |item|
      d.check("the shortcuts dialog lists \"#{item}\"") { found.include?(item) }
    end
  end

  d.step('the shortcuts dialog renders') { d.shot('08-shortcuts') }

  d.step('closing the shortcuts dialog and opening About instead') do
    app.main_window.window.visible_dialog&.close
    app.main_window.window.activate_action('about', nil)
  end

  d.step('the about dialog carries this port\'s identity') do
    window = app.main_window.window
    d.check('the about dialog is showing') { window.visible_dialog.is_a?(Adwaita::AboutDialog) }
    d.check('the application name is Characters') { window.visible_dialog.application_name == 'Characters' }
  end

  d.step('the about dialog renders') { d.shot('09-about') }

  d.step('closing the about dialog leaves no dialog showing') do
    app.main_window.window.visible_dialog&.close
  end

  d.step('the window is clean again') do
    window = app.main_window.window
    d.check('no dialog remains') { window.visible_dialog.nil? }
  end
end
