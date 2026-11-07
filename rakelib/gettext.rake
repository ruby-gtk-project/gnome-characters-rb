# frozen_string_literal: true

# Compiles and refreshes the gnome-characters-rb text domain's catalogues
# under po/. Mirrors what upstream's meson build does with msgfmt/msgmerge
# for its own po/*.po files, run by hand here since this port has no build
# system of its own.
namespace :gettext do
  DOMAIN = 'gnome-characters-rb'
  PO_DIR = File.expand_path('../po', __dir__)
  LOCALE_DIR = File.join(PO_DIR, 'locale')
  POT_FILE = File.join(PO_DIR, "#{DOMAIN}.pot")

  desc 'Compile po/*.po into po/locale/<lang>/LC_MESSAGES/gnome-characters-rb.mo'
  task :compile do
    linguas = File.readlines(File.join(PO_DIR, 'LINGUAS')).map(&:strip).reject(&:empty?)
    linguas.each do |lang|
      po_file = File.join(PO_DIR, "#{lang}.po")
      next unless File.exist?(po_file)

      mo_dir = File.join(LOCALE_DIR, lang, 'LC_MESSAGES')
      FileUtils.mkdir_p(mo_dir)
      sh('msgfmt', '-o', File.join(mo_dir, "#{DOMAIN}.mo"), po_file)
    end
  end

  desc "Regenerate po/#{DOMAIN}.pot from the lib/*.rb and data/* files po/POTFILES.in lists"
  task :update_pot do
    potfiles = File.readlines(File.join(PO_DIR, 'POTFILES.in'))
                    .map(&:strip)
                    .reject { |line| line.empty? || line.start_with?('#') }
                    .map { |path| File.expand_path(path, File.expand_path('..', __dir__)) }
    ruby_files = potfiles.select { |path| path.end_with?('.rb') }
    desktop_file = potfiles.find { |path| path.end_with?('.desktop') }

    sh(
      'rxgettext',
      '--package-name', DOMAIN,
      '--copyright-holder', 'The GNOME Project',
      '--msgid-bugs-address', 'https://github.com/ruby-gtk-project/gnome-characters-rb/issues',
      '--sort-by-file',
      '-o', POT_FILE,
      *ruby_files,
    )

    if desktop_file
      sh(
        'xgettext',
        '--language=Desktop',
        '--from-code=UTF-8',
        '--join-existing',
        '--sort-by-file',
        '--package-name', DOMAIN,
        '--copyright-holder', 'The GNOME Project',
        '--msgid-bugs-address', 'https://github.com/ruby-gtk-project/gnome-characters-rb/issues',
        '-o', POT_FILE,
        desktop_file,
      )
    end

    # data/*.metainfo.xml has no gettext extractor available in this devshell
    # (no itstool/appstreamcli); its handful of strings are merged in by hand
    # when the file changes, same as they were when this .pot was built.
  end

  desc 'Merge each po/<lang>.po against the current .pot (msgmerge)'
  task :update_po do
    linguas = File.readlines(File.join(PO_DIR, 'LINGUAS')).map(&:strip).reject(&:empty?)
    linguas.each do |lang|
      po_file = File.join(PO_DIR, "#{lang}.po")
      next unless File.exist?(po_file)

      sh('msgmerge', '--quiet', '--update', po_file, POT_FILE)
    end
  end
end

desc "Alias for gettext:compile"
task gettext: 'gettext:compile'
