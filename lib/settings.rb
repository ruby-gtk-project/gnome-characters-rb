# frozen_string_literal: true

require 'json'
require 'fileutils'

# Settings holds the keys of upstream's org.gnome.Characters GSettings schema
# (data/org.gnome.Characters.gschema.xml): the list of recently used
# characters, and how many of them to keep.
#
# Upstream uses GSettings, which needs a compiled schema installed into the
# system's glib-2.0/schemas directory. Requiring an install step before the app
# runs from a checkout is worse than the alternative, so the same keys,
# defaults and semantics are backed by a small JSON file under
# XDG_CONFIG_HOME instead. This is the same arrangement the pilot port
# (gnome-contacts-rb lib/settings.rb) uses.
class Settings
  DEFAULTS = {
    'recent-characters'     => [],
    'max-recent-characters' => 100,
  }.freeze

  def initialize(path: nil)
    @path = path || default_path
    @values = DEFAULTS.merge(read)
  end

  def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

  def []=(key, value)
    @values[key.to_s] = value
    write
    value
  end

  def location = @path

  def recent_characters = self['recent-characters']
  def max_recent_characters = self['max-recent-characters']

  def recent_characters=(value)
    self['recent-characters'] = value
  end

  def max_recent_characters=(value)
    self['max-recent-characters'] = value
  end

  private

    def default_path
      File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.expand_path('~/.config')),
        'gnome-characters-rb',
        'settings.json',
      )
    end

    def read
      if File.exist?(@path)
        parse(File.read(@path))
      else
        {}
      end
    end

    def parse(contents)
      JSON.parse(contents)
    rescue JSON::ParserError => e
      warn "Ignoring unreadable settings at #{@path}: #{e.message}"
      {}
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, "#{JSON.pretty_generate(@values)}\n")
    rescue SystemCallError => e
      warn "Could not save settings to #{@path}: #{e.message}"
    end
end
