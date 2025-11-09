alarms_resources = [
  'beep-beep.flac',
]

foreach alarm: alarms_resources
  resource_deps += custom_target(
    fs.replace_suffix(alarm, '.oga'),
    output: '@BASENAME@.oga',
    input: alarm,
    command: to_vorbis,
  )
endforeach
