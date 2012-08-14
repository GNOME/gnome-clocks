#!/usr/bin/env python

from distutils.version import StrictVersion

try:
    import DistUtilsExtra.auto
except ImportError:
    import sys
    print >> sys.stderr, 'To build gnome-clocks you need https://launchpad.net/python-distutils-extra'
    sys.exit(1)

DistUtilsExtra.auto.setup(
    name='gnome-clocks',
    description='Clock application for the GNOME Desktop',
    version='0.1.0',
    url='https://live.gnome.org/Clocks',
    license='GPL',
    author='Seif Lotfy, Emily Gonyer, Eslam Mostafa',
)

