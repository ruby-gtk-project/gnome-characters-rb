# frozen_string_literal: true

require 'adwaita'
require_relative 'gc'

# SidebarItem is the port of upstream's src/sidebarItem.js: an
# Adw.SidebarItem carrying the Gc category its page shows.
#
# Upstream registers `category` as a GObject enum property so that
# data/sidebar.ui can set it from the .ui file. This port builds the sidebar in
# Ruby instead of from a template, so the category is a plain attribute and no
# property registration is needed.
class SidebarItem < Adwaita::SidebarItem
  attr_writer :category

  # Adwaita::SidebarItem.new takes the title positionally.
  def initialize(title, icon_name, category)
    super(title)
    self.icon_name = icon_name
    @category = category
  end

  def category = @category || :none
end
