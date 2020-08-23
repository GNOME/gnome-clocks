project(
  'gnome-clocks',
  ['vala', 'c'],
  version: '3.37.91',
  license: 'GPL2+',
  meson_version: '>= 0.50.0',
)

gnome = import('gnome')
i18n = import('i18n')
python3 = import('python3')

glib = dependency('glib-2.0', version: '>= 2.58')
gio = dependency('gio-2.0', version: '>= 2.58')
gobject = dependency('gobject-2.0', version: '>= 2.58')
gtk = dependency('gtk+-3.0', version: '>=3.20')
gsound = dependency('gsound', version: '>=0.98')
gweather = dependency('gweather-3.0', version: '>=3.32.0')
gnomedesktop = dependency('gnome-desktop-3.0', version: '>=3.8')
geocodeglib = dependency('geocode-glib-1.0', version: '>=1.0')
libgeoclue = dependency('libgeoclue-2.0', version: '>=2.4')
libhandy = dependency ('libhandy-1', version: '>= 0.90.0', required: false)

if not libhandy.found()
  libhandy_subproj = subproject(
    'libhandy',
    default_options: [
      'examples=false',
      'glade_catalog=disabled',
      'tests=false',
    ]
  )

  # When using libhandy as subproject, make sure we get the VAPI file
  libhandy = declare_dependency(
    dependencies: [
      libhandy_subproj.get_variable('libhandy_dep'),
      libhandy_subproj.get_variable('libhandy_vapi'),
    ]
  )
endif

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

meson.add_install_script(python3.find_python().path(),
  join_paths(meson.source_root(), 'build-aux', 'post-install.py'))

subdir('data')
subdir('help')
subdir('po')
subdir('src')
