iconsdir = join_paths(get_option('datadir'), 'icons/hicolor')

install_data(
    join_paths('icons/hicolor/scalable/apps/org.gnome.clocks.svg'),
    install_dir: join_paths(iconsdir, 'scalable', 'apps'),
    rename: '@0@.svg'.format(application_id)
)
install_data(
    join_paths('icons/hicolor/symbolic/apps/org.gnome.clocks-symbolic.svg'),
    install_dir: join_paths(iconsdir, 'scalable', 'apps'),
    rename: '@0@-symbolic.svg'.format(application_id)
)

install_subdir('images/', install_dir: join_paths(get_option('datadir'), meson.project_name()))

resource_files = files('gnome-clocks.gresource.xml')
resources = gnome.compile_resources('org.gnome.clocks', resource_files,
  c_name: 'resources'
)

desktop_conf = configuration_data()
desktop_conf.set('app-icon', application_id)
custom_target('desktop-file',
  input: configure_file(
    input: 'org.gnome.clocks.desktop.in.in',
    output: 'org.gnome.clocks.desktop.in',
    configuration: desktop_conf
  ),
  output: '@0@.desktop'.format(application_id),
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

appdata_conf = configuration_data()
appdata_conf.set('app-id', application_id)
appdata_conf.set('gettext', gettext_package)
custom_target('appdata-file',
  input: configure_file(
    input: 'org.gnome.clocks.appdata.xml.in.in',
    output: 'org.gnome.clocks.appdata.xml.in',
    configuration: appdata_conf
  ),
  output: '@0@.appdata.xml'.format(application_id),
  install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo'),
  command: [msgfmt, '--xml', '--template', '@INPUT@', '-d', podir, '-o', '@OUTPUT@'],
)

search_provider_conf = configuration_data()
search_provider_conf.set('app-id', application_id)
search_provider_conf.set('object-path', app_path)
configure_file(
  input: 'org.gnome.clocks.search-provider.ini.in',
  output: '@0@.search-provider.ini'.format(application_id),
  configuration: search_provider_conf,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'gnome-shell', 'search-providers')
)

gsettingsconf = configuration_data()
gsettingsconf.set('GETTEXT_PACKAGE', gettext_package)
gsettingsconf.set('schema-id', application_id)
gsettingsconf.set('schema-path', app_path)
configure_file(
  input: 'org.gnome.clocks.gschema.xml.in',
  output: '@0@.gschema.xml'.format(application_id),
  configuration: gsettingsconf,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas'),
)
