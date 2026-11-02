# frozen_string_literal: true

require 'adwaita'
require_relative 'gnome/characters/rb/version'

# AboutDialog is the port of the _about method of upstream's src/window.js,
# which builds an Adw.AboutDialog inline. The credits, copyright, licence and
# links are upstream's; the version is this port's.
class AboutDialog
  APPLICATION_NAME = 'Characters'
  APPLICATION_ICON = 'org.gnome.Characters'
  DEVELOPER_NAME = 'The GNOME Project'
  COPYRIGHT = 'Copyright 2014-2018 Daiki Ueno'
  WEBSITE = 'https://apps.gnome.org/Characters/'
  ISSUE_URL = 'https://gitlab.gnome.org/GNOME/gnome-characters/-/issues/'

  DESIGNERS = [
    'Allan Day <allanpday@gmail.com>',
    'Jakub Steiner <jimmac@gmail.com>',
    'Hylke Bons <hello@planetpeanut.studio>',
  ].freeze

  DEVELOPERS = [
    'Daiki Ueno <dueno@src.gnome.org>',
    'Giovanni Campagna <scampa.giovanni@gmail.com>',
  ].freeze

  def build
    dialog.tap do |widget|
      widget.application_name = APPLICATION_NAME
      widget.application_icon = APPLICATION_ICON
      widget.developer_name = DEVELOPER_NAME
      widget.designers = DESIGNERS
      widget.developers = DEVELOPERS
      # TRANSLATORS: put your names here, one name per line.
      widget.translator_credits = 'translator-credits'
      widget.copyright = COPYRIGHT
      widget.license_type = Gtk::License::GPL_2_0
      widget.version = Gnome::Characters::Rb::VERSION
      widget.website = WEBSITE
      widget.issue_url = ISSUE_URL
    end
  end

  def present(parent)
    dialog.present(parent)
  end

  private

    def dialog = @dialog ||= Adwaita::AboutDialog.new
end
