## Process this file with automake to produce Makefile.in
## Created by Anjuta

## The main script
bin_SCRIPTS = gnome_clocks.py

## Directory where .class files will be installed
gnome_clocksdir = $(pythondir)/gnome_clocks


gnome_clocks_PYTHON = \
	gnome_clocks.py \
	about.py \
	clocks.py \
	about.py \
	alarm.py \
	alarms_handler.py \
	clocks.py \
	storage.py \
	timer.py \
	widgets.py

# Remove ui directory on uninstall
uninstall-local:

	-rm -r $(pkgdatadir)
