AC_PREREQ(2.63)

AC_INIT([gnome-clocks],
        [0.1.7],
        [http://bugzilla.gnome.org/enter_bug.cgi?product=gnome-clocks],
        [gnome-clocks])

AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([1.11 tar-ustar dist-xz no-dist-gzip foreign])
m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

AM_PATH_PYTHON([3.2])

IT_PROG_INTLTOOL(0.40)
AM_GNU_GETTEXT([external])
AM_GNU_GETTEXT_VERSION([0.17])
GETTEXT_PACKAGE=AC_PACKAGE_NAME
AC_SUBST([GETTEXT_PACKAGE])
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE,"$GETTEXT_PACKAGE",[The name of the gettext domain])

GLIB_GSETTINGS

PKG_PROG_PKG_CONFIG([0.22])

PKG_CHECK_MODULES(CLOCKS, [
    py3cairo
    pygobject-3.0 >= 3.4.2
])

AC_CONFIG_FILES([
    Makefile
    gnomeclocks/defs.py
    po/Makefile.in
])

AC_OUTPUT

echo "
    gnome-clocks ${VERSION}

    prefix: ${prefix}
    Python interpreter: ${PYTHON}

    Now type 'make' to build ${PACKAGE}
"
