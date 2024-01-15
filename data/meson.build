scalable_iconsdir = join_paths('icons', 'hicolor', 'scalable', 'apps')
install_data(
  join_paths(scalable_iconsdir, '@0@.svg'.format(app_id)),
  install_dir: join_paths(get_option('datadir'), scalable_iconsdir)
)

symbolic_iconsdir = join_paths('icons', 'hicolor', 'symbolic', 'apps')
install_data(
  join_paths(symbolic_iconsdir, 'org.gnome.clocks-symbolic.svg'),
  install_dir: join_paths(get_option('datadir'), symbolic_iconsdir),
  rename: '@0@-symbolic.svg'.format(app_id)
)

resource_files = files('gnome-clocks.gresource.xml')
resources = gnome.compile_resources('org.gnome.clocks', resource_files,
  c_name: 'resources'
)

desktop_conf = configuration_data()
desktop_conf.set('icon', app_id)
desktop_file = i18n.merge_file(
  type: 'desktop',
  input: configure_file(
    input: 'org.gnome.clocks.desktop.in.in',
    output: '@BASENAME@',
    configuration: desktop_conf
  ),
  output: '@0@.desktop'.format(app_id),
  po_dir: podir,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

# Validate Desktop file
desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
  test(
    'validate-desktop',
    desktop_file_validate,
    args: [
      desktop_file.full_path()
    ]
  )
endif


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

metainfo_conf = configuration_data()
metainfo_conf.set('appid', app_id)
metainfo_file = i18n.merge_file (
  input: configure_file(
    input: 'org.gnome.clocks.metainfo.xml.in.in',
    output: '@BASENAME@',
    configuration: metainfo_conf
  ),
  output: '@0@.metainfo.xml'.format(app_id),
  po_dir: podir,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# Validate metainfo
appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test(
    'validate-metainfo', appstreamcli,
    args: [
      'validate', '--no-net', '--explain', metainfo_file.full_path()
    ]
  )
endif

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
  output: '@BASENAME@',
  configuration: gsettingsconf,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas'),
)

glib_compile_schemas = find_program('glib-compile-schemas', required: false)
# Validata GSchema
if glib_compile_schemas.found()
  test(
    'validate-gschema', glib_compile_schemas,
    args: [
      '--strict', '--dry-run', meson.current_source_dir()
    ]
  )
endif

