"""Reproduce the fixed Sydney summer clock from NOAA solar equations.

This is a seasonal game baseline, not a weather feed or daily almanac service.
"""
import datetime as dt
import json
import math
from pathlib import Path
from statistics import mean

def solar_day(day, latitude=-33.8568, longitude=151.2153, utc_hours=11):
    count = 366 if (day.year % 4 == 0 and (day.year % 100 != 0 or day.year % 400 == 0)) else 365
    gamma = math.tau * (day.timetuple().tm_yday - 1) / count
    eq = 229.18 * (.000075 + .001868*math.cos(gamma) - .032077*math.sin(gamma)
                  - .014615*math.cos(2*gamma) - .040849*math.sin(2*gamma))
    dec = (.006918 - .399912*math.cos(gamma) + .070257*math.sin(gamma)
           - .006758*math.cos(2*gamma) + .000907*math.sin(2*gamma)
           - .002697*math.cos(3*gamma) + .00148*math.sin(3*gamma))
    lat = math.radians(latitude)
    ha = math.acos(math.cos(math.radians(90.833))/(math.cos(lat)*math.cos(dec)) - math.tan(lat)*math.tan(dec))
    noon = (720 - 4*longitude - eq + 60*utc_hours)/60
    return dict(date=day.isoformat(), sunrise_hour=noon-math.degrees(ha)/15,
                sunset_hour=noon+math.degrees(ha)/15, declination_radians=dec)

def baseline():
    first, last = dt.date(2026,12,1), dt.date(2027,2,28)
    rows = [solar_day(first+dt.timedelta(days=i)) for i in range((last-first).days+1)]
    sunrise = mean(row['sunrise_hour'] for row in rows)
    sunset = mean(row['sunset_hour'] for row in rows)
    # Fit one seasonal declination to exactly the mean horizon crossing interval.
    latitude = math.radians(-33.8568)
    ha = math.radians((sunset-sunrise)*7.5)
    lower, upper = math.radians(-24), math.radians(-10)
    for _ in range(60):
        dec = (lower+upper)/2
        height = math.sin(latitude)*math.sin(dec)+math.cos(latitude)*math.cos(dec)*math.cos(ha)
        if height > math.sin(math.radians(-.833)): lower = dec
        else: upper = dec
    return dict(version=1, label='Sydney fixed average summer', latitude=-33.8568,
                longitude=151.2153, timezone='Australia/Sydney', fixed_utc_offset=11,
                sample_start=str(first), sample_end=str(last), samples=len(rows),
                sunrise_hour=sunrise, sunset_hour=sunset, solar_noon_hour=(sunrise+sunset)/2,
                daylight_hours=sunset-sunrise, declination_radians=(lower+upper)/2,
                time_scale=12, real_seconds_per_day=7200,
                sources=['https://gml.noaa.gov/grad/solcalc/solareqns.PDF',
                         'https://www.bom.gov.au/news-and-media/solstices-equinoxes-and-the-seasons',
                         'https://www.judcom.nsw.gov.au/publications/benchbks/local/perpetual_calendar.html'],
                scope='Arithmetic average of 90 computed summer days at a fixed AEDT offset. Flat astronomical horizon; no terrain, weather or live wall-clock synchronization.',
                daily_samples=rows)

if __name__ == '__main__':
    target=Path(__file__).resolve().parents[1]/'game/assets/sydney_summer.json'
    target.write_text(json.dumps(baseline(),ensure_ascii=False,indent=2)+'\n')
    print(target)
