ui_sources = files(
  'alarm-day-picker-row.blp',
  'alarm-face.blp',
  'alarm-ringing-panel.blp',
  'alarm-row.blp',
  'alarm-setup-dialog.blp',
  'header-bar.blp',
  'shortcuts-dialog.blp',
  'sound-chooser.blp',
  'sound-chooser-row.blp',
  'stopwatch-face.blp',
  'stopwatch-laps-row.blp',
  'timer-face.blp',
  'timer-row.blp',
  'timer-setup.blp',
  'timer-setup-dialog.blp',
  'window.blp',
  'world-face.blp',
  'world-location-dialog.blp',
  'world-location-dialog-row.blp',
  'world-row.blp',
  'world-standalone.blp',
)

resource_deps += custom_target(
  input: ui_sources,
  output: '.',
  command: [blueprint_compiler, 'batch-compile', '--minify', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@']
)
