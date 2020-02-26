HACKME
======

This file is intended to help new developers to get started with developing for
Clocks. Feel free to skip sections if you know what they are about.

Another good source for general information is:

 https://wiki.gnome.org/Apps/Clocks

1. How to Provide a Good Patch
==============================

 * Make sure you have just what belongs there in the changeset.
 * Read https://wiki.gnome.org/Git/CommitMessages carefully.
 * The preferred way of appending patches to bugs is via git bz.
   * As an alternative you can use "git format-patch HEAD~1".
 * The bugtracker has some quite cool features; use them!
 * Click on review to write comments to other or your patches or to comment
   comments on these patches.
 * Dont be afraid about criticism! The review process is probably going to be
   long.
 * We dont dislike you! We really appreciate your work.

2. Getting Started With Vala
============================

Check out:

 https://wiki.gnome.org/Projects/Vala/Documentation

Vala basics in 5 minutes:

 https://www.youtube.com/watch?v=k9hE0mumsCM

Good reference for the libraries used here:

 http://www.valadoc.org/

Information about UI-templates:

 http://blogs.gnome.org/tvb/2013/05/29/composite-templates-lands-in-vala/

3. Getting Started With Clocks
==============================

The best way to get started is to fix small bugs. If you don't find them, ask
on IRC.

4. Getting Started With coala
=============================

coala is a helping tool for developers to check for inconsistencies in the code.

You can install coala from:

 https://github.com/coala-analyzer/coala

To use coala, just open terminal and browse to code directory; then type:

 $ coala

coala will test for the following things:

 * No trailing spaces.
 * No tabs.
 * Line lengths less than 120.

If any of the above tests fail for any line(s) coala will prompt you to fix it
alongwith the location of that line.