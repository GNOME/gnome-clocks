project(
  'gnome-clocks',
  ['vala', 'c'],
  version: '3.28.0',
  license: 'GPL2+',
  meson_version: '>= 0.41.0',
)

gnome = import('gnome')
i18n = import('i18n')
python3 = import('python3')

glib = dependency('glib-2.0', version: '>=2.44')
gio = dependency('gio-2.0', version: '>=2.44')
gobject = dependency('gobject-2.0', version: '>=2.44')
gtk = dependency('gtk+-3.0', version: '>=3.20')
gsound = dependency('gsound', version: '>=0.98')
gweather = dependency('gweather-3.0', version: '>=3.27.2')
gnomedesktop = dependency('gnome-desktop-3.0', version: '>=3.8')
geocodeglib = dependency('geocode-glib-1.0', version: '>=1.0')
libgeoclue = dependency('libgeoclue-2.0', version: '>=2.4')

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
podir = join_paths(meson.source_root(), 'po')

conf = configuration_data()
conf.set_quoted('G_LOG_DOMAIN', 'org.gnome.Clocks')
conf.set_quoted('PACKAGE_NAME', meson.project_name())
conf.set_quoted('PACKAGE_VERSION', meson.project_version())
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('DATADIR', join_paths(get_option('prefix'), get_option('datadir')))
conf.set_quoted('GNOMELOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
if have_first_weekday
  conf.set('HAVE__NL_TIME_FIRST_WEEKDAY', '1')
endif
configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

meson.add_install_script(python3.find_python().path(),
  join_paths(meson.source_root(), 'build-aux', 'post-install.py'))

subdir('data')
subdir('help')
subdir('po')
subdir('src')
