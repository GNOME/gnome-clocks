ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}

SUBDIRS = help po

# desktop file
# (we can't use INTLTOOL_DESKTOP_RULE here due to lp#605826)
%.desktop: %.desktop.in
	$(MKDIR_P) $(dir $@); LC_ALL=C $(INTLTOOL_MERGE) -d -u -c $(top_builddir)/po/.intltool-merge-cache $(top_srcdir)/po $< $@
applicationsdir = $(datadir)/applications
applications_DATA = data/org.gnome.clocks.desktop
dist_noinst_DATA = data/org.gnome.clocks.desktop.in

# DBus service file
servicedir = $(datadir)/dbus-1/services
service_DATA = data/org.gnome.clocks.service
dist_noinst_DATA = data/org.gnome.clocks.service.in

data/org.gnome.clocks.service: data/org.gnome.clocks.service.in Makefile
	$(AM_V_GEN) sed -e "s|\@bindir\@|$(bindir)|" $< > $@

# appdata file
appdatadir = $(datadir)/appdata
appdata_DATA = data/appdata/gnome-clocks.appdata.xml

# gsettings
gsettings_SCHEMAS = data/org.gnome.clocks.gschema.xml
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

# icons
icon16dir = $(datadir)/icons/hicolor/16x16/apps
icon16_DATA = data/icons/hicolor/16x16/apps/gnome-clocks.png
icon22dir = $(datadir)/icons/hicolor/22x22/apps
icon22_DATA = data/icons/hicolor/22x22/apps/gnome-clocks.png
icon32dir = $(datadir)/icons/hicolor/32x32/apps
icon32_DATA = data/icons/hicolor/32x32/apps/gnome-clocks.png
icon48dir = $(datadir)/icons/hicolor/48x48/apps
icon48_DATA = data/icons/hicolor/48x48/apps/gnome-clocks.png
icon256dir = $(datadir)/icons/hicolor/256x256/apps
icon256_DATA = data/icons/hicolor/256x256/apps/gnome-clocks.png
icon_files = \
	$(icon16_DATA) \
	$(icon22_DATA) \
	$(icon32_DATA) \
	$(icon48_DATA) \
	$(icon256_DATA) \
	data/icons/hicolor/gnome-clocks.svg

hcicon16dir = $(datadir)/icons/HighContrast/16x16/apps
hcicon16_DATA = data/icons/HighContrast/16x16/apps/gnome-clocks.png
hcicon22dir = $(datadir)/icons/HighContrast/22x22/apps
hcicon22_DATA = data/icons/HighContrast/22x22/apps/gnome-clocks.png
hcicon24dir = $(datadir)/icons/HighContrast/24x24/apps
hcicon24_DATA = data/icons/HighContrast/24x24/apps/gnome-clocks.png
hcicon32dir = $(datadir)/icons/HighContrast/32x32/apps
hcicon32_DATA = data/icons/HighContrast/32x32/apps/gnome-clocks.png
hcicon48dir = $(datadir)/icons/HighContrast/48x48/apps
hcicon48_DATA = data/icons/HighContrast/48x48/apps/gnome-clocks.png
hcicon256dir = $(datadir)/icons/HighContrast/256x256/apps
hcicon256_DATA = data/icons/HighContrast/256x256/apps/gnome-clocks.png
hcicon_files = \
	$(hcicon16_DATA) \
	$(hcicon22_DATA) \
	$(hcicon24_DATA) \
	$(hcicon32_DATA) \
	$(hcicon48_DATA) \
	$(hcicon256_DATA)

gtk_update_icon_cache = gtk-update-icon-cache -f -t $(datadir)/icons/hicolor; gtk-update-icon-cache -f -t $(datadir)/icons/HighContrast

install-data-hook: update-icon-cache
uninstall-hook: update-icon-cache
update-icon-cache:
	@-if test -z "$(DESTDIR)"; then \
		echo "Updating Gtk icon cache."; \
		$(gtk_update_icon_cache); \
	else \
		echo "*** Icon cache not updated.  After (un)install, run this:"; \
		echo "***   $(gtk_update_icon_cache)"; \
	fi

# images
imagesdir = $(datadir)/gnome-clocks/images
images_DATA = \
	data/images/day.png \
	data/images/night.png

AM_CPPFLAGS = \
	-I$(top_srcdir)/egg-list-box \
	-DGWEATHER_I_KNOW_THIS_IS_UNSTABLE \
	-DGNOME_DESKTOP_USE_UNSTABLE_API \
	-DGETTEXT_PACKAGE=\""$(GETTEXT_PACKAGE)"\" \
	-DGNOMELOCALEDIR=\""$(localedir)"\" \
	-DDATADIR=\""$(datadir)"\"

AM_VALAFLAGS = \
	--target-glib=2.38 \
	--vapidir=egg-list-box \
	--pkg gio-2.0 \
	--pkg gtk+-3.0 \
	--pkg gweather-3.0 \
	--pkg libcanberra \
	--pkg libnotify \
	--pkg geocode-glib-1.0 \
	--gresources  $(top_srcdir)/data/gnome-clocks.gresource.xml

bin_PROGRAMS = gnome-clocks

BUILT_SOURCES = \
	src/resources.c

resource_files = $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir=$(top_srcdir)/data $(top_srcdir)/data/gnome-clocks.gresource.xml)
src/resources.c: $(top_srcdir)/data/gnome-clocks.gresource.xml $(resource_files)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(top_srcdir)/data --generate-source $<

VALA_SOURCES = \
	src/application.vala \
	src/window.vala \
	src/clock.vala \
	src/world.vala \
	src/alarm.vala \
	src/stopwatch.vala \
	src/timer.vala \
	src/utils.vala \
	src/widgets.vala \
	src/geocoding.vala \
	src/main.vala

gnome_clocks_SOURCES = \
	$(BUILT_SOURCES) \
	$(VALA_SOURCES) \
	src/cutils.c \
	src/gnome-desktop-3.0.vapi \
	src/config.vapi

AM_CFLAGS = \
	$(CLOCKS_CFLAGS) \
	-Wall \
	-Wno-unused-but-set-variable \
	-Wno-unused-variable

gnome_clocks_LDFLAGS = -export-dynamic
gnome_clocks_LDADD = \
	$(CLOCKS_LIBS) \
	-lm

EXTRA_DIST = \
	$(icon_files) \
	$(hcicon_files) \
	$(images_DATA) \
	$(resource_files) \
	data/appdata/gnome-clocks.appdata.xml \
	data/gnome-clocks.gresource.xml \
	data/org.gnome.clocks.gschema.xml.in.in

CLEANFILES = \
	$(applications_DATA)

DISTCLEANFILES = \
	$(gsettings_SCHEMAS)

MAINTAINERCLEANFILES = \
	ABOUT-NLS \
	aclocal.m4 \
	config.guess \
	config.h.in \
	config.rpath \
	config.sub \
	depcomp \
	install-sh \
	ltmain.sh \
	missing \
	$(gsettings_SCHEMAS:.xml=.valid) \
	$(VALA_SOURCES:.vala=.c) \
	*.stamp

-include $(top_srcdir)/git.mk
