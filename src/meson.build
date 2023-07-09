vapi_sources = files(
  'config.vapi',
)

clocks_vala_sources = files(
  'alarm-day-picker-row.vala',
  'alarm-face.vala',
  'alarm-item.vala',
  'alarm-ringing-panel.vala',
  'alarm-row.vala',
  'alarm-setup-dialog.vala',
  'application.vala',
  'clock.vala',
  'geocoding.vala',
  'header-bar.vala',
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
  'world-location-dialog-row.vala',
  'world-row.vala',
  'world-shell-world-clocks.vala',
  'world-standalone.vala',
)

clocks_c_sources = files(
  'cutils.c',
  'twilight.c',
)

clocks_sources = [
  vapi_sources,
  clocks_vala_sources,
  clocks_c_sources,
  resources
]

clocks_vala_args = [
  '--target-glib', '2.72',
  '--vapidir', meson.current_source_dir(),
  '--gresources', resource_files,
  # '--enable-experimental-non-null',
]

clocks_c_args = [
  '-include', 'config.h',
  '-DGWEATHER_I_KNOW_THIS_IS_UNSTABLE',
  '-DGNOME_DESKTOP_USE_UNSTABLE_API',
]

clocks_dependencies = [
  glib,
  gio,
  gobject,
  gtk,
  gweather,
  gnomedesktop,
  geocodeglib,
  libgeoclue,
  libadwaita,
  math
]

executable('gnome-clocks', clocks_sources,
  include_directories: config_h_dir,
  vala_args: clocks_vala_args,
  c_args: clocks_c_args,
  dependencies: clocks_dependencies,
  install: true
)

if get_option('docs')
  valadoc = find_program('valadoc')
  custom_target('docs',
    input: clocks_vala_sources,
    output: 'docs',
    command: [
      valadoc,
      '--doclet=html',
      '--force',
      '--package-name=@0@'.format(meson.project_name()),
      '--package-version=@0@'.format(meson.project_version()),
      '--pkg=glib-2.0',
      '--pkg=gio-2.0',
      '--pkg=gio-unix-2.0',
      '--pkg=gtk+-3.0',
      '--pkg=gobject-2.0',
      '--pkg=libhandy-1',
      '--pkg=gweather-3.0',
      '--pkg=gnome-desktop-3.0',
      '--pkg=geocode-glib-1.0',
      '--pkg=libgeoclue-2.0',
      '--pkg=config',
      '--directory=@OUTDIR@/../docs',
      '--vapidir=@0@'.format(meson.current_source_dir()),
      '--use-svg-images',
      '--internal',
      '--private',
      clocks_vala_sources
    ],
    build_by_default: true,
  )
endif
