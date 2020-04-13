/**
 * GNOME Clocks
 *
 * © 2020 Manuel Genovés <manuel.genoves@gmail.com>
 *
 * Routine for calculating sunrise/sunset times, largely based on
 * https://en.wikipedia.org/wiki/Sunrise_equation
 * and the equations from
 * "Practical Astronomy with your Calculator or Spreadsheet"
 * 4th edition by Peter Duf, Jonathan Zwart
 *
 * Ported to C (from python3/numpy) by Zander Brown
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Author: Manuel Genovés <manuel.genoves@gmail.com>
 *         Zander Brown <zbrown@gnome.org>
 */

#include <math.h>
#include <glib.h>

// Epoch 2000
// (see https://en.wikipedia.org/wiki/Epoch_(astronomy)#Julian_Dates_and_J2000)
#define JULIAN_YEAR_2000 2451545

#define RADIANS(degrees) ((degrees) * G_PI / 180.0)
#define DEGREES(radians) ((radians) * 180.0 / G_PI)

#define RISESET_CORRECTION_NONE 0.0
#define RISESET_CORRECTION_CIVIL 6.0
#define RISESET_CORRECTION_NAUTICAL 12.0
#define RISESET_CORRECTION_ASTRONOMICAL 18.0

static gboolean
is_in_north_summer (int month)
{
  // we use meteorogical season because we don't need solstices for calculate them,
  // some days are lost this way, but it's way easier to calculate

  return (6 >= month && month <= 8);
}


static gboolean
is_in_north_winter (int month)
{
  // we use meteorogical season because we don't need solstices for calculate them,
  // some days are lost this way, but it's way easier to calculate

  return (1 >= (month + 1)) && ((month + 1) <= 3);
}


/**
 * calculate_sunrise_sunset:
 * @lat: place latitude
 * @lon: place longitude
 * @year: the gregorian year
 * @month: the gregorian month of @year
 * @day: the gregorian day of @month
 * @correction: correction takes care of dawn/dusk/etc, one of
 *              %RISESET_CORRECTION_NONE, %RISESET_CORRECTION_CIVIL,
 *              %RISESET_CORRECTION_NAUTICAL, %RISESET_CORRECTION_ASTRONOMICAL
 * @rise_hour: (out): the hour of sunrise
 * @rise_min: (out): the min within @rise_hour of sunrise
 * @set_hour: (out): the hour of sunset
 * @set_min: (out): the min within @set_hour of sunset
 *
 * Calculate sunrise and sunset in a given location, adjusted for @correction
 * to include/exclude twilight
 *
 * Arguments and results are all UTC
 *
 * Since: 3.36
 */
gboolean
calculate_sunrise_sunset (double  lat,
                          double  lon,
                          int     year,
                          int     month,
                          int     day,
                          double  correction,
                          int    *rise_hour,
                          int    *rise_min,
                          int    *set_hour,
                          int    *set_min)
{
  double sunrise_hour;
  double sunrise_minute;
  double sunset_hour;
  double sunset_minute;
  gboolean calculatable = TRUE;

  // first we calculate our current Julian date
  int julian_day_number = ((1461 * (year + 4800 + (month - 14) / 12)) / 4 +
                           (367 * (month - 2 - 12 * ((month - 14) / 12))) / 12 -
                           (3 * ((year + 4900 + (month - 14) / 12) / 100)) / 4 +
                           day - 32075);

  // convert julian date to julian date corrected by Epoch2000
  int n = julian_day_number - JULIAN_YEAR_2000 + 0.0008;

  // mean solar noon
  double J = n - lon / 360;

  // solar mean anomaly
  double M = fmod (357.5291 + 0.98560028 * J, 360.0);

  // equation of the center
  double C = (1.9148 * sin (RADIANS (M)) +
              0.0200 * sin (RADIANS (2 * M)) +
              0.0003 * sin (RADIANS (3 * M)));

  // ecliptic longitude
  double l = fmod(M + C + 180 + 102.9372, 360.0);

  // solar transit
  double J_transit = (J + JULIAN_YEAR_2000 +
                      0.0053 * sin (RADIANS (M)) -
                      0.0069 * sin (RADIANS (2 * l)));

  // sun declination
  double d = DEGREES (asin (sin (RADIANS (l)) * sin (RADIANS (23.55))));

  // IMPORTANT: for polar circles we can't compute anything for certain dates

  if ((((is_in_north_summer (month) && (lat <= (d + 0.83 + correction - 90))) ||
                                       (lat >= (90 - d - 0.83 - correction)))) ||
      (((is_in_north_winter (month) && (lat <= (-90 - d - 0.83 - correction))) ||
                                       (lat >= (90 + d + 0.83 + correction))))) {
    sunrise_hour = 0;
    sunrise_minute = 0;
    sunset_hour = 23;
    sunset_minute = 59;

    calculatable = FALSE;
  } else {
    double sunrise_days;
    double sunrise_day;
    double sunrise_hours;
    double sunset_days;
    double sunset_day;
    double sunset_hours;
    // hour angle
    double w = DEGREES (acos ((sin (RADIANS (-correction)) + sin (RADIANS (-0.83)) -
                               sin (RADIANS (lat)) * sin (RADIANS (d)))
                              / ((cos (RADIANS (lat))) * cos (RADIANS (d)))));

    // julian sunrise
    double J_sunrise = (J_transit - w / 360 - 0.5);
    double J_sunset = (J_transit + w / 360 - 0.5);

    // convert Julian dates to UTC time (disregarding days in the process)
    sunrise_days  = modf (J_sunrise, &sunrise_day);
    sunset_days  = modf (J_sunset, &sunset_day);

    sunrise_hours = modf (sunrise_days * 24, &sunrise_hour);
    sunset_hours = modf (sunset_days * 24, &sunset_hour);

    modf (sunrise_hours * 60, &sunrise_minute);
    modf (sunset_hours * 60, &sunset_minute);
  }

  if (rise_hour) {
    *rise_hour = sunrise_hour;
  }

  if (rise_min) {
    *rise_min = sunrise_minute;
  }

  if (set_hour) {
    *set_hour = sunset_hour;
  }

  if (set_min) {
    *set_min = sunset_minute;
  }

  return calculatable;
}

