# frozen_string_literal: true

require_relative '../../util'
require_relative '../../gc'
require_relative "rb/version"

# Gem entry point: `require "gnome/characters/rb"` is what `bundler/gem_tasks`
# and RSpec's spec_helper expect for a gem named gnome-characters-rb, and it
# pulls in the two pieces of the port that are plain Ruby and testable without
# a display: Util (lib/util.rb, the port of upstream's src/util.js) and Gc
# (lib/gc.rb, the port of upstream's libgc). The widgets under lib/*.rb are
# reached through exe/gnome-characters and lib/main.rb instead, the way
# upstream's own tests exercise libgc and src/util.js without booting a
# window.
module Gnome
  module Characters
    module Rb
    end
  end
end
