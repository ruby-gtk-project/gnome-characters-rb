# frozen_string_literal: true

require 'gettext'

# Translatable wires Ruby gettext's `_()`/`p_()` into any class that includes
# it, binding the gnome-characters-rb text domain to the compiled catalogues
# under po/locale (built from po/*.po by `rake gettext:compile`, mirroring
# upstream's meson-driven msgfmt step for its own .po files).
#
# Upstream marks strings translatable through its `_()` calls in src/*.js and
# through `translatable="yes"` in its data/*.ui templates; this port has no
# .ui templates, so every one of those UI strings is marked here instead, at
# the Ruby call site that sets it.
module Translatable
  DOMAIN = 'gnome-characters-rb'
  LOCALE_DIR = File.expand_path('../po/locale', __dir__)

  def self.included(base)
    base.include(GetText)
    base.bindtextdomain(DOMAIN, path: LOCALE_DIR)
  end
end
