/*
 * Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#include "config.h"

#include <stdio.h>
#ifdef HAVE__NL_TIME_FIRST_WEEKDAY
#include <langinfo.h>
#endif
#include <glib/gi18n-lib.h>
#include <gtk/gtk.h>
#include <locale.h>
#include <unicode/unumberformatter.h>

G_DEFINE_AUTOPTR_CLEANUP_FUNC (UNumberFormatter, unumf_close);
G_DEFINE_AUTOPTR_CLEANUP_FUNC (UFormattedNumber, unumf_closeResult);

const struct {
  GTimeSpan span;
  uint64_t max;
  const char *string;
} TIME_UNIT[] = {
    { G_TIME_SPAN_DAY, G_MAXUINT64, "day" },
    { G_TIME_SPAN_HOUR, 24, "hour" },
    { G_TIME_SPAN_MINUTE, 60, "minute" },
    { G_TIME_SPAN_SECOND, 60, "second" },
    { G_TIME_SPAN_MILLISECOND, 1000, "millisecond" },
    { 1, 1000, "microsecond" },
};

static inline char *
unicode_build_duration_unit_for_time_span (GTimeSpan time_span)
{
  const char *segments[G_N_ELEMENTS (TIME_UNIT) + 1] = { NULL };
  int j = 0;

  for (int i = 0; i < G_N_ELEMENTS (TIME_UNIT); i++) {
    uint64_t n = (time_span / TIME_UNIT[i].span) % TIME_UNIT[i].max;
    if (n > 0) {
      segments[j++] = TIME_UNIT[i].string;
    }
  }

  return g_strjoinv ("-and-", (GStrv) segments);
}

static inline char *
unicode_format_number (const char *skeleton,
                       double      number)
{
  char *locale = setlocale (LC_TIME, NULL);
  g_autofree gunichar2 *skeleton_utf16 = NULL;
  g_autoptr (UNumberFormatter) formatter = NULL;
  g_autoptr (UFormattedNumber) result = NULL;
  int32_t string_utf16_length = 0;
  const UChar *string_utf16 = NULL;
  g_autofree char *string = NULL;
  UErrorCode error_code = U_ZERO_ERROR;
  g_autoptr (GError) error = NULL;

  skeleton_utf16 = g_utf8_to_utf16 (skeleton, -1, NULL, NULL, &error);
  if (error != NULL) {
    g_critical ("Failed to convert from UTF-8 to UTF-16: %s", error->message);
    return NULL;
  }

  formatter = unumf_openForSkeletonAndLocale (skeleton_utf16, -1, locale, &error_code);
  if (U_FAILURE (error_code)) {
    g_critical ("Failed to create a Unicode number formatter: %s", u_errorName (error_code));
    return NULL;
  }

  result = unumf_openResult (&error_code);
  if (U_FAILURE (error_code)) {
    g_critical ("Failed to create a Unicode result object: %s", u_errorName (error_code));
    return NULL;
  }

  unumf_formatDouble (formatter, number, result, &error_code);
  if (U_FAILURE (error_code)) {
    g_critical ("Failed to format a number with Unicode: %s", u_errorName (error_code));
    return NULL;
  }

  string_utf16 = ufmtval_getString (unumf_resultAsValue(result, &error_code), &string_utf16_length, &error_code);
  if (U_FAILURE (error_code)) {
    g_critical ("Failed to retrieved the Unicode number string: %s", u_errorName (error_code));
    return NULL;
  }

  string = g_utf16_to_utf8 (string_utf16, string_utf16_length, NULL, NULL, &error);
  if (error != NULL) {
    g_critical ("Failed to convert from UTF-16 to UTF-8: %s", error->message);
    return NULL;
  }

  return g_steal_pointer (&string);
}

char *
clocks_cutils_format_time_span (GTimeSpan   time_span,
                                gboolean    abbreviated)
{
  double number;
  g_autofree char *duration_unit = NULL;
  g_autofree char *skeleton = NULL;

  time_span = labs (time_span);
  number = time_span >= G_TIME_SPAN_DAY ? time_span / (double) G_TIME_SPAN_DAY
         : time_span >= G_TIME_SPAN_HOUR ? time_span / (double) G_TIME_SPAN_HOUR
         : time_span >= G_TIME_SPAN_MINUTE ? time_span / (double) G_TIME_SPAN_MINUTE
         : time_span >= G_TIME_SPAN_SECOND ? time_span / (double) G_TIME_SPAN_SECOND
         : time_span >= G_TIME_SPAN_MILLISECOND ? time_span / (double) G_TIME_SPAN_MILLISECOND
         : (double) time_span;

  duration_unit = unicode_build_duration_unit_for_time_span (time_span);
  skeleton = g_strdup_printf ("unit/%s unit-width-%s precision-integer",
                              duration_unit,
                              abbreviated ? "narrow" : "full-name");

  return unicode_format_number (skeleton, number);
}

/* Copied from gtkcalendar.c */
int
clocks_cutils_get_week_start (void)
{
  int week_start;
#ifdef HAVE__NL_TIME_FIRST_WEEKDAY
  union { unsigned int word; char *string; } langinfo;
  int week_1stday = 0;
  int first_weekday = 1;
  guint week_origin;
#else
  char *gtk_week_start;
#endif

#ifdef HAVE__NL_TIME_FIRST_WEEKDAY
  langinfo.string = nl_langinfo (_NL_TIME_FIRST_WEEKDAY);
  first_weekday = langinfo.string[0];
  langinfo.string = nl_langinfo (_NL_TIME_WEEK_1STDAY);
  week_origin = langinfo.word;
  if (week_origin == 19971130) /* Sunday */
    week_1stday = 0;
  else if (week_origin == 19971201) /* Monday */
    week_1stday = 1;
  else
    g_warning ("Unknown value of _NL_TIME_WEEK_1STDAY.\n");

  week_start = (week_1stday + first_weekday - 1) % 7;
#else
  /* Use a define to hide the string from xgettext */
# define GTK_WEEK_START "calendar:week_start:0"
  gtk_week_start = dgettext ("gtk40", GTK_WEEK_START);

  if (strncmp (gtk_week_start, "calendar:week_start:", 20) == 0)
    week_start = *(gtk_week_start + 20) - '0';
  else
    week_start = -1;

  if (week_start < 0 || week_start > 6)
    {
      g_warning ("Whoever translated calendar:week_start:0 for GTK+ "
                 "did so wrongly.\n");
      week_start = 0;
    }
#endif

  return week_start;
}

