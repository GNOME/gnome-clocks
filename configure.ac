AC_PREREQ(2.63)

AC_INIT([gnome-clocks],
        [3.23.90],
        [http://bugzilla.gnome.org/enter_bug.cgi?product=gnome-clocks],
        [gnome-clocks])

dnl http://people.gnome.org/~walters/docs/build-api.txt
dnl We don't support separate builddir when building from git
echo \#buildapi-variable-no-builddir >/dev/null

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_HEADERS(config.h)
AC_CONFIG_SRCDIR(src/main.vala)

AM_INIT_AUTOMAKE([1.11 tar-ustar dist-xz no-dist-gzip foreign])
m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

AM_GNU_GETTEXT([external])
AM_GNU_GETTEXT_VERSION([0.19.8])
GETTEXT_PACKAGE=AC_PACKAGE_NAME
AC_SUBST([GETTEXT_PACKAGE])
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE,"$GETTEXT_PACKAGE",[The name of the gettext domain])

AC_PROG_CC
AC_PROG_CC_STDC
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AM_PROG_VALAC([0.23.3])

# _NL_TIME_FIRST_WEEKDAY is an enum and not a define
AC_MSG_CHECKING([for _NL_TIME_FIRST_WEEKDAY])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <langinfo.h>]],
                                   [[nl_langinfo(_NL_TIME_FIRST_WEEKDAY);]])],
               [langinfo_ok=yes], [langinfo_ok=no])
AC_MSG_RESULT($langinfo_ok)
if test "$langinfo_ok" = "yes"; then
  AC_DEFINE([HAVE__NL_TIME_FIRST_WEEKDAY], [1],
            [Define if _NL_TIME_FIRST_WEEKDAY is available])
fi

AC_PATH_PROG(GLIB_COMPILE_RESOURCES, glib-compile-resources)

GLIB_GSETTINGS

LT_INIT([disable-static])
LT_LIB_M

PKG_PROG_PKG_CONFIG([0.22])

PKG_CHECK_MODULES(CLOCKS, [
    gio-2.0 >= 2.44
    glib-2.0 >= 2.44
    gtk+-3.0 >= 3.19.8
    gsound >= 0.98
    gweather-3.0 >= 3.13.91
    gnome-desktop-3.0 >= 3.7.90
    geocode-glib-1.0 >= 0.99.4
    libgeoclue-2.0 >= 2.3.1
])

YELP_HELP_INIT

AC_CONFIG_FILES([
    Makefile
    data/org.gnome.clocks.gschema.xml
    help/Makefile
    po/Makefile.in
])

AC_OUTPUT

echo "
    gnome-clocks ${VERSION}

    prefix: ${prefix}
    Vala compiler: ${VALAC}
    C compiler: ${CC}

    Now type 'make' to build ${PACKAGE}
"
