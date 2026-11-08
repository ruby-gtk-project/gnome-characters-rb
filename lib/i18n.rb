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
  # Upstream's real gettext domain, per po/meson.build's
  # `i18n.gettext('org.gnome.Characters', preset: 'glib')` and
  # meson.build's project name — not this port's gem/repo name. Every
  # catalogue this port ships (po/*.po, po/locale/*/LC_MESSAGES/*.mo) is
  # built under this same domain so a .mo installed into a system
  # locale directory under this name is found the same way upstream's is.
  DOMAIN = 'org.gnome.Characters'
  LOCALE_DIR = File.expand_path('../po/locale', __dir__)

  def self.included(base)
    base.include(GetText)
    base.bindtextdomain(DOMAIN, path: LOCALE_DIR)
  end
end
