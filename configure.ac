AC_PREREQ(2.63)

AC_INIT([gnome-clocks],
        [3.7.91],
        [http://bugzilla.gnome.org/enter_bug.cgi?product=gnome-clocks],
        [gnome-clocks])

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_HEADERS(config.h)
AC_CONFIG_SRCDIR(src/main.vala)

AM_INIT_AUTOMAKE([1.11 tar-ustar dist-xz no-dist-gzip foreign])
m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

IT_PROG_INTLTOOL(0.40)
AM_GNU_GETTEXT([external])
AM_GNU_GETTEXT_VERSION([0.17])
GETTEXT_PACKAGE=AC_PACKAGE_NAME
AC_SUBST([GETTEXT_PACKAGE])
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE,"$GETTEXT_PACKAGE",[The name of the gettext domain])

AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AM_PROG_VALAC([0.17.4])

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

PKG_PROG_PKG_CONFIG([0.22])

PKG_CHECK_MODULES(CLOCKS, [
    gio-2.0 >= 2.30.0
    gtk+-3.0 >= 3.7.12
    libcanberra >= 0.30
    gweather-3.0 >= 3.7.90
    gnome-desktop-3.0 >= 3.7.90
    libnotify >= 0.7.0
])

LIBGD_INIT([
    static
    header-bar
    stack
    vapi
])

AC_CONFIG_FILES([
    Makefile
    libgd/Makefile
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
