ACLOCAL_AMFLAGS = -I m4

SUBDIRS = po

# desktop file
# (we can't use INTLTOOL_DESKTOP_RULE here due to lp#605826)
%.desktop: %.desktop.in
	$(MKDIR_P) $(dir $@); LC_ALL=C $(INTLTOOL_MERGE) -d -u -c $(top_builddir)/po/.intltool-merge-cache $(top_srcdir)/po $< $@
applicationsdir = $(datadir)/applications
applications_DATA = data/gnome-clocks.desktop
dist_noinst_DATA = data/gnome-clocks.desktop.in

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

# css
cssdir = $(datadir)/gnome-clocks/css
css_DATA = \
	data/css/gnome-clocks.css \
	data/css/button-border-go-active.svg \
	data/css/button-border-go.svg \
	data/css/button-border-stop-active.svg \
	data/css/button-border-stop.svg

# main script
bin_SCRIPTS = gnome-clocks

# python module (nobase means dirname is preserved in site-packages
packagesdir = $(pythondir)
nobase_dist_packages_PYTHON = \
	$(wildcard $(srcdir)/gnomeclocks/*.py)

EXTRA_DIST = \
	$(icon_files) \
	$(hcicon_files) \
	$(images_DATA) \
	$(css_DATA) \
	$(bin_SCRIPTS)

CLEANFILES = \
	$(applications_DATA) \
	$(wildcard $(srcdir)/gnomeclocks/*.pyc)

DISTCLEANFILES = \
	gnomeclocks/defs.py

MAINTAINERCLEANFILES = 		\
	ABOUT-NLS \
	aclocal.m4 \
	config.guess \
	config.rpath \
	config.sub \
	install-sh \
	missing \
	po/Makevars.template \
	po/Rules-quot \
	po/boldquot.sed \
	po/en@boldquot.header \
	po/en@quot.header \
	po/insert-header.sin \
	po/quot.sed \
	po/remove-potcdate.sin \
	py-compile

-include $(top_srcdir)/git.mk
