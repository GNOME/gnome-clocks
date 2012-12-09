#!/bin/bash
# Run this to generate all the initial makefiles, etc.

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

PKG_NAME="gnome-clocks"

test -f $srcdir/configure.ac || {
    echo "**Error**: Directory "\`$srcdir\'" does not look like the top-level $PKG_NAME directory"
    exit 1
}

which gnome-autogen.sh || {
    echo "You need to install gnome-common from GNOME Git (or from your OS vendor's package manager)."
    exit 1
}

. gnome-autogen.sh "$@"
