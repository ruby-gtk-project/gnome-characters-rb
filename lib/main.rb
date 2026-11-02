# frozen_string_literal: true

require 'adwaita'

require_relative 'gc'
require_relative 'settings'
require_relative 'shell_search_provider'
require_relative 'shortcuts_dialog'
require_relative 'util'
require_relative 'window'

# App is the port of upstream's src/main.js: the application object, its
# actions and accelerators, the stylesheet, the search provider export, and
# the single main window.
#
# Upstream is an Adw.Application; Adwaita::Application is broken in the Ruby
# bindings, so this is a Gtk::Application with Adwaita initialised by hand.
# Upstream also exports the search provider from vfunc_dbus_register, which is
# a virtual function rather than a signal; the export happens on startup here,
# off the connection the application has already registered on.
class App
  APP_ID = 'org.gnome.CharactersRb'
  OBJECT_PATH = '/org/gnome/CharactersRb'
  INACTIVITY_TIMEOUT = 10_000

  # The accelerators upstream installs in vfunc_startup, plus the one
  # Adwaita's shortcuts dialog is advertised under.
  ACCELERATORS = {
    'app.quit'      => ['<Primary>q'],
    'app.shortcuts' => ['<Primary>question'],
    'win.find'      => ['<Primary>f'],
  }.freeze

  attr_reader :settings

  def initialize(settings: nil, app_id: APP_ID, present: true)
    @settings = settings || Settings.new
    @app_id = app_id
    @present = present
  end

  def build
    app.tap do |application|
      application.signal_connect('startup') { start_up }

      application.signal_connect('activate') { present_main_window }
    end
  end

  def run = app.run([])

  def main_window = @main_window ||= MainWindow.new(app, settings)

  private

    # Upstream's vfunc_activate builds the window on the first activation and
    # only presents it on the ones after that.
    def present_main_window
      unless @built
        main_window.build
        @built = true
      end

      if @present
        main_window.present
      end
    end

    def start_up
      Adwaita::StyleManager.default.color_scheme = Adwaita::ColorScheme::PREFER_LIGHT
      load_stylesheet

      Util.init_actions(
        app,
        [
          { name: 'quit', activate: ->(_parameter) { app.quit } },
          { name: 'shortcuts', activate: ->(_parameter) { show_shortcuts } },
        ],
      )

      ACCELERATORS.each { |action, accelerators| app.set_accels_for_action(action, accelerators) }

      export_search_provider
      hold_for_service
    end

    def load_stylesheet
      Gtk::CssProvider.new.tap do |provider|
        provider.load_from_path(File.expand_path('style.css', __dir__))
        Gtk::StyleContext.add_provider_for_display(
          Gdk::Display.default,
          provider,
          Gtk::StyleProvider::PRIORITY_APPLICATION,
        )
      end
    end

    def show_shortcuts
      ShortcutsDialog.new.tap do |dialog|
        dialog.build
        dialog.present(app.active_window)
      end
    end

    def export_search_provider
      app.dbus_connection.then do |connection|
        if connection
          search_provider.export(connection, "#{app.dbus_object_path || OBJECT_PATH}/SearchProvider")
        end
      end
    end

    def search_provider
      @search_provider ||= ShellSearchProvider.new(app, on_launch_search: method(:launch_search))
    end

    # LaunchSearch: show the window with the shell's terms already in the
    # search bar.
    def launch_search(terms, timestamp)
      present_main_window
      main_window.search_keywords = terms
      app.active_window&.present_with_time(timestamp)
    end

    # A service-activated instance exits once the shell stops asking it
    # anything, which is what set_inactivity_timeout gives upstream.
    def hold_for_service
      if app.flags.to_i.anybits?(Gio::ApplicationFlags::IS_SERVICE.to_i)
        app.inactivity_timeout = INACTIVITY_TIMEOUT
      end
    end

    def app
      @app ||= begin
        Adwaita.init
        GLib.application_name = 'Characters'
        Gtk::Application.new(@app_id, :default_flags)
      end
    end
end
