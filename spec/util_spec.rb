# frozen_string_literal: true

# Ports tests/testUtil.js's first two assertions from upstream: every emoji
# character_to_icon_data renders to a GLib::Variant of the icon-data tuple,
# and every whitespace-or-empty string renders to nil.
RSpec.describe Util do
  describe '.character_to_icon_data' do
    %w[🍕 🤌 🥰].each do |emoji|
      it "renders #{emoji.inspect} as a GLib::Variant" do
        expect(described_class.character_to_icon_data(emoji)).to be_a(GLib::Variant)
      end
    end

    ['', ' ', "\n", "\r", "\t", "\t   \n    \n \r      "].each do |whitespace|
      it "renders #{whitespace.inspect} as nil" do
        expect(described_class.character_to_icon_data(whitespace)).to be_nil
      end
    end
  end
end
