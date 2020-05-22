vapi_sources = [
  'config.vapi',
]

clocks_vala_sources = [
  'alarm-day-picker-row.vala',
  'alarm-face.vala',
  'alarm-item.vala',
  'alarm-ringing-panel.vala',
  'alarm-row.vala',
  'alarm-setup-dialog.vala',
  'application.vala',
  'clock.vala',
  'geocoding.vala',
  'headerbar.vala',
  'main.vala',
  'search-provider.vala',
  'stopwatch-face.vala',
  'stopwatch-lap.vala',
  'stopwatch-laps-row.vala',
  'timer-face.vala',
  'timer-item.vala',
  'timer-row.vala',
  'timer-setup.vala',
  'timer-setup-dialog.vala',
  'utils.vala',
  'widgets.vala',
  'window.vala',
  'world-face.vala',
  'world-item.vala',
  'world-location-dialog.vala',
  'world-row.vala',
  'world-shell-world-clocks.vala',
  'world-standalone.vala',
]

clocks_c_sources = [
  'cutils.c',
  'twilight.c',
]

clocks_sources = [
  vapi_sources,
  clocks_vala_sources,
  clocks_c_sources,
  resources
]

clocks_vala_args = [
  '--target-glib', '2.58',
  '--vapidir', meson.current_source_dir(),
  '--gresources', resource_files,
  '--enable-experimental-non-null',
  '--disable-since-check',
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
