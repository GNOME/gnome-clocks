iconsdir = join_paths(get_option('datadir'), 'icons/hicolor')
foreach size: ['scalable', 'symbolic']
  install_subdir('icons/hicolor/' + size, install_dir: iconsdir)
endforeach

install_subdir('images/', install_dir: join_paths(get_option('datadir'), meson.project_name()))

resource_files = files('gnome-clocks.gresource.xml')
resources = gnome.compile_resources('org.gnome.clocks', resource_files,
  c_name: 'resources'
)

custom_target('desktop-file',
  input: 'org.gnome.clocks.desktop.in',
  output: 'org.gnome.clocks.desktop',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications'),
  command: [msgfmt, '--desktop',
    '--template', '@INPUT@', '-d', podir, '-o', '@OUTPUT@',
    '--keyword=X-GNOME-FullName', '--keyword=X-Geoclue-Reason',
    '--keyword=Name', '--keyword=GenericName', '--keyword=Comment', '--keyword=Keywords'
  ]
)

dbusconf = configuration_data()
dbusconf.set('bindir', join_paths(get_option('prefix'), get_option('bindir')))
configure_file(
  input: 'org.gnome.clocks.service.in',
  output: 'org.gnome.clocks.service',
  configuration: dbusconf,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'dbus-1', 'services'),
)

custom_target('appdata-file',
  input: 'org.gnome.clocks.appdata.xml.in',
  output: 'org.gnome.clocks.appdata.xml',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo'),
  command: [msgfmt, '--xml', '--template', '@INPUT@', '-d', podir, '-o', '@OUTPUT@'],
)

install_data('org.gnome.clocks.search-provider.ini',
  install_dir: join_paths(get_option('datadir'), 'gnome-shell', 'search-providers'),
)

gsettingsconf = configuration_data()
gsettingsconf.set('GETTEXT_PACKAGE', meson.project_name())
configure_file(
  input: 'org.gnome.clocks.gschema.xml.in',
  output: 'org.gnome.clocks.gschema.xml',
  configuration: gsettingsconf,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas'),
)
