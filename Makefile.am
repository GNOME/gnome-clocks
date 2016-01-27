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
dist_noinst_DATA += data/org.gnome.clocks.service.in

data/org.gnome.clocks.service: data/org.gnome.clocks.service.in Makefile
	$(AM_V_GEN) sed -e "s|\@bindir\@|$(bindir)|" $< > $@

# appdata file
appdatadir = $(datadir)/appdata
appdata_DATA = $(appdata_in_files:.xml.in=.xml)
appdata_in_files = data/appdata/org.gnome.clocks.appdata.xml.in
@INTLTOOL_XML_RULE@

# gnome-shell search provider
searchproviderdir = $(datadir)/gnome-shell/search-providers
searchprovider_DATA = data/org.gnome.clocks.search-provider.ini

# gsettings
gsettings_SCHEMAS = data/org.gnome.clocks.gschema.xml
@GSETTINGS_RULES@

# icons
icon16dir = $(datadir)/icons/hicolor/16x16/apps
icon16_DATA = data/icons/hicolor/16x16/apps/org.gnome.clocks.png
icon22dir = $(datadir)/icons/hicolor/22x22/apps
icon22_DATA = data/icons/hicolor/22x22/apps/org.gnome.clocks.png
icon32dir = $(datadir)/icons/hicolor/32x32/apps
icon32_DATA = data/icons/hicolor/32x32/apps/org.gnome.clocks.png
icon48dir = $(datadir)/icons/hicolor/48x48/apps
icon48_DATA = data/icons/hicolor/48x48/apps/org.gnome.clocks.png
icon256dir = $(datadir)/icons/hicolor/256x256/apps
icon256_DATA = data/icons/hicolor/256x256/apps/org.gnome.clocks.png
iconsymbolicdir = $(datadir)/icons/hicolor/symbolic/apps
iconsymbolic_DATA = data/icons/hicolor/symbolic/apps/org.gnome.clocks-symbolic.svg
icon_files = \
	$(icon16_DATA) \
	$(icon22_DATA) \
	$(icon32_DATA) \
	$(icon48_DATA) \
	$(icon256_DATA) \
	$(iconsymbolic_DATA) \
	data/icons/hicolor/org.gnome.clocks.svg


gtk_update_icon_cache = gtk-update-icon-cache -f -t $(datadir)/icons/hicolor

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
	-DGWEATHER_I_KNOW_THIS_IS_UNSTABLE \
	-DGNOME_DESKTOP_USE_UNSTABLE_API \
	-DGETTEXT_PACKAGE=\""$(GETTEXT_PACKAGE)"\" \
	-DGNOMELOCALEDIR=\""$(localedir)"\" \
	-DDATADIR=\""$(datadir)"\"

AM_VALAFLAGS = \
	--target-glib=2.38 \
	--pkg gio-2.0 \
	--pkg gtk+-3.0 \
	--pkg gweather-3.0 \
	--pkg gsound \
	--pkg geocode-glib-1.0 \
	--pkg Geoclue-2.0 \
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
	src/search-provider.vala \
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
	$(appdata_in_files) \
	$(searchprovider_DATA) \
	$(icon_files) \
	$(images_DATA) \
	$(resource_files) \
	data/appdata/org.gnome.clocks.appdata.xml \
	data/gnome-clocks.gresource.xml

CLEANFILES = \
	$(appdata_DATA) \
	$(applications_DATA) \
	$(service_DATA)

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
	$(VALA_SOURCES:.vala=.c) \
	*.stamp

-include $(top_srcdir)/git.mk
