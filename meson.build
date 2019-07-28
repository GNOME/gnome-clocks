project(
  'gnome-clocks',
  ['vala', 'c'],
  version: '3.33.1',
  license: 'GPL2+',
  meson_version: '>= 0.46.0',
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
libhandy = dependency('libhandy-0.0', version: '>= 0.0.9', required: false)
if not libhandy.found()
  libhandy_proj = subproject(
    'libhandy',
    default_options: [
      'examples=false',
      'glade_catalog=disabled',
      'introspection=enabled',
      'static=false',
      'tests=false',
      'vapi=true',
    ]
  )
  # Of course this should be libhandy_dep but apparently
  # libhandy_vapi isn't built by default and as a dependency
  # object seems to get the job done
  libhandy = libhandy_proj.get_variable('libhandy_vapi')
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
