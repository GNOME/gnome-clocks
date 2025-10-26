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

alarms_data = [
  'bird.flac',
  'bonfire.flac',
  'boudoir.flac',
  'bouncing.flac',
  'cautious-steps.flac',
  'chirping.flac',
  'class-act.flac',
  'crossing-bell.flac',
  'daydreaming.flac',
  'digitone.flac',
  'enchanting.flac',
  'glass-bell.flac',
  'guitar.flac',
  'jolly.flac',
  'mystery.flac',
  'ping-ping.flac',
  'school-bell.flac',
  'sonar.flac',
  'sparkling.flac',
  'tingling.flac',
  'toys.flac',
]

foreach alarm: alarms_data
  custom_target(
    fs.replace_suffix(alarm, '.oga'),
    output: '@BASENAME@.oga',
    input: alarm,
    command: to_vorbis,
    install: true,
    install_dir: get_option('datadir') / 'sounds' / 'gnome' / 'default' / 'alarms',
  )
endforeach
