# frozen_string_literal: true

require 'adwaita'

require_relative 'i18n'

# ShortcutsDialog is the port of upstream's data/shortcuts.ui: the
# Adw.ShortcutsDialog with a single "General" section.
#
# Upstream gives three of the four items an action-name and lets Adwaita look
# the accelerator up from the application; the accelerators below are the ones
# the application actually installs, written out.
#
# Upstream marks every title here translatable with msgctxt "shortcut
# window" (so a translator sees "General"/"Search" in that context rather
# than confused with the same words elsewhere); p_ is gettext's context
# lookup, matching that.
class ShortcutsDialog < Adwaita::ShortcutsDialog
  include Translatable

  def initialize
    super()
    self.title = _('Keyboard Shortcuts')
  end

  def build
    tap do |dialog|
      sections.each do |title, items|
        dialog.add(section(title, items))
      end
    end
  end

  private

    # The context string is written out at each call (rather than held in a
    # constant) because the gettext extractor needs a literal at the call
    # site to pull the msgctxt out of.
    def sections
      {
        p_('shortcut window', 'General') => [
          [p_('shortcut window', 'Open Main Menu'), 'F10'],
          [p_('shortcut window', 'Search'), '<Control>f'],
          [p_('shortcut window', 'Show Keyboard Shortcuts'), '<Control>question'],
          [p_('shortcut window', 'Quit'), '<Control>q'],
        ],
      }
    end

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |section|
        section.title = title
        items.each { |label, accelerator| section.add(item(label, accelerator)) }
      end
    end

    # Positional, not keyword, arguments — even though the error a no-argument
    # new raises advertises the signatures as "title: utf8, accelerator: utf8".
    def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
end
