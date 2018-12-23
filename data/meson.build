scalable_iconsdir = join_paths('icons', 'hicolor', 'scalable', 'apps')
install_data(
  join_paths(scalable_iconsdir, 'org.gnome.clocks.svg'),
  install_dir: join_paths(get_option('datadir'), scalable_iconsdir),
  rename: '@0@.svg'.format(app_id)
)

symbolic_iconsdir = join_paths('icons', 'hicolor', 'symbolic', 'apps')
install_data(
  join_paths(symbolic_iconsdir, 'org.gnome.clocks-symbolic.svg'),
  install_dir: join_paths(get_option('datadir'), symbolic_iconsdir),
  rename: '@0@-symbolic.svg'.format(app_id)
)

install_subdir('images/', install_dir: join_paths(get_option('datadir'), meson.project_name()))

resource_files = files('gnome-clocks.gresource.xml')
resources = gnome.compile_resources('org.gnome.clocks', resource_files,
  c_name: 'resources'
)

desktop_conf = configuration_data()
desktop_conf.set('icon', app_id)
custom_target('desktop-file',
  input: configure_file(
    input: 'org.gnome.clocks.desktop.in.in',
    output: 'org.gnome.clocks.desktop.in',
    configuration: desktop_conf
  ),
  output: '@0@.desktop'.format(app_id),
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
dbusconf.set('name', app_id)
configure_file(
  input: 'org.gnome.clocks.service.in',
  output: '@0@.service'.format(app_id),
  configuration: dbusconf,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'dbus-1', 'services'),
)

appdata_conf = configuration_data()
appdata_conf.set('appid', app_id)
custom_target('appdata-file',
  input: configure_file(
    input: 'org.gnome.clocks.appdata.xml.in.in',
    output: 'org.gnome.clocks.appdata.xml.in',
    configuration: appdata_conf,
  ),
  output: '@0@.appdata.xml'.format(app_id),
  install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo'),
  command: [msgfmt, '--xml', '--template', '@INPUT@', '-d', podir, '-o', '@OUTPUT@'],
)

search_conf = configuration_data()
search_conf.set('appid', app_id)
search_conf.set('profile', profile)
configure_file(
  input: 'org.gnome.clocks.search-provider.ini.in',
  output: '@0@.search-provider.ini'.format(app_id),
  configuration: search_conf,
  install: true,
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