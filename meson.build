project(
  'gnome-clocks',
  ['vala', 'c'],
  version: '49.0',
  license: 'GPL-2.0-or-later',
  meson_version: '>= 0.59.0',
)

gnome = import('gnome')
i18n = import('i18n')

glib = dependency('glib-2.0', version: '>= 2.72')
gio = dependency('gio-2.0', version: '>= 2.72')
gobject = dependency('gobject-2.0', version: '>= 2.72')
gtk = dependency('gtk4', version: '>= 4.15.3')
gweather = dependency('gweather4')
gweather_soup_version = gweather.get_variable(pkgconfig: 'soupapiversion')
if gweather_soup_version == '3.0'
  geocodeglib = dependency('geocode-glib-2.0', version: '>=1.0')
else
  geocodeglib = dependency('geocode-glib-1.0', version: '>=1.0')
endif
gnomedesktop = dependency('gnome-desktop-4')
libgeoclue = dependency('libgeoclue-2.0', version: '>=2.4')
libadwaita = dependency ('libadwaita-1', version: '>=1.8.alpha')

cc = meson.get_compiler('c')
math = cc.find_library('m', required: false)

have_first_weekday = cc.compiles('''
#include <langinfo.h>
int main() {
  nl_langinfo(_NL_TIME_FIRST_WEEKDAY);
}
''',
  name: '_NL_TIME_FIRST_WEEKDAY check program'
)

msgfmt = find_program('msgfmt')
podir = join_paths(meson.project_source_root(), 'po')

if get_option('profile') == 'development'
  name_prefix = '(Development) '
  profile = 'Devel'
else
  name_prefix = ''
  profile = ''
endif

app_id = 'org.gnome.clocks@0@'.format(profile)

conf = configuration_data()
conf.set_quoted('APP_ID', app_id)
conf.set_quoted('G_LOG_DOMAIN', 'org.gnome.Clocks@0@'.format(profile))
conf.set_quoted('NAME_PREFIX', name_prefix)
conf.set_quoted('PACKAGE_NAME', meson.project_name())
conf.set_quoted('PACKAGE_VERSION', meson.project_version())
conf.set_quoted('PROFILE', profile)
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('DATADIR', join_paths(get_option('prefix'), get_option('datadir')))
conf.set_quoted('GNOMELOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
if have_first_weekday
  conf.set('HAVE__NL_TIME_FIRST_WEEKDAY', '1')
endif
configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

subdir('data')
subdir('help')
subdir('po')
subdir('src')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
