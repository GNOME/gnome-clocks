vala_sources = [
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

vapi_sources = [
    'config.vapi',
]

c_sources = [
    'cutils.c'
]

sources = [
    vala_sources,
    vapi_sources,
    c_sources,
    resources
]

vala_args = [
    '--target-glib', '2.44',
    '--vapidir', meson.current_source_dir(),
    '--gresources', resource_files,
]

c_args = [
    '-include', 'config.h',
    '-DGWEATHER_I_KNOW_THIS_IS_UNSTABLE',
    '-DGNOME_DESKTOP_USE_UNSTABLE_API'
]

dependencies = [
    glib,
    gio,
    gobject,
    gtk,
    gsound,
    gweather,
    gnomedesktop,
    geocodeglib,
    libgeoclue,
    math
]

executable('gnome-clocks', sources,
    include_directories: config_h_dir,
    vala_args: vala_args,
    c_args: c_args,
    install: true,
    dependencies: dependencies
)
