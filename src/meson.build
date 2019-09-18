vapi_sources = [
  'config.vapi',
]

clocks_vala_sources = [
  'alarm.vala',
  'application.vala',
  'clock.vala',
  'geocoding.vala',
  'main.vala',
  'search-provider.vala',
  'stopwatch.vala',
  'timer.vala',
  'utils.vala',
  'widgets.vala',
  'window.vala',
  'world.vala'
]

clocks_c_sources = [
  'cutils.c'
]

clocks_sources = [
  vapi_sources,
  clocks_vala_sources,
  clocks_c_sources,
  resources
]

clocks_vala_args = [
  '--target-glib', '2.44',
  '--vapidir', meson.current_source_dir(),
  '--gresources', resource_files,
]

clocks_c_args = [
  '-include', 'config.h',
  '-DGWEATHER_I_KNOW_THIS_IS_UNSTABLE',
  '-DGNOME_DESKTOP_USE_UNSTABLE_API',
  '-DHANDY_USE_UNSTABLE_API',
]

clocks_dependencies = [
  glib,
  gio,
  gobject,
  gtk,
  gsound,
  gweather,
  gnomedesktop,
  geocodeglib,
  libgeoclue,
  libhandy,
  math
]

executable('gnome-clocks', clocks_sources,
  include_directories: config_h_dir,
  vala_args: clocks_vala_args,
  c_args: clocks_c_args,
  dependencies: clocks_dependencies,
  install: true
)
