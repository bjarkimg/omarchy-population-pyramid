#!/usr/bin/env python3
"""
Demographics & Population Decline Data Generator

Generates, per country:

1. 21-bracket age-sex pyramids on a 5-year grid (1950-2100, plus the 2026
   "now" anchor) -- the same year grid the trajectory line chart uses, so
   scrubbing the chart moves the pyramid one frame at a time.
2. Per-year gender and age-gap metrics (sex ratio, median age by sex, life
   expectancy by sex and the gap between them, old-age female surplus).
3. A continuous historical + future population curve:
   - TFR < 2.1: extrapolated down to a theoretical extinction horizon.
   - TFR >= 2.1: 100 years of tapering growth.

METHOD / HONESTY NOTE
---------------------
The per-country anchors in COUNTRY_PROFILES (TFR, 2026 population, growth
rate, peak year and population, median age) are hand-entered approximations of
published UN WPP headline figures.

Everything else -- every pyramid, every trajectory point, every life
expectancy -- is SYNTHESISED by the parametric models below. This is not UN
data and must not be read as a projection. The pyramids come from a
cohort-component projection (births from age-specific fertility, survival from
a Gompertz-Makeham hazard) that is calibrated so each country's modelled 2026
median age matches its stated anchor. It is built to look plausible and to
animate smoothly, not to be authoritative.

Explicit modelling assumptions:
  - TFR is held CONSTANT after 2026 (no assumed recovery), consistent with the
    plugin's decline premise. UN medium-variant assumes convergence toward
    ~1.8, which would produce less extreme pyramids than shown here.
  - Historical TFR level is fitted per country, not sourced.
  - Migration is ignored entirely.
"""

import json
import math
import os

AGE_GROUPS = [
    "0-4", "5-9", "10-14", "15-19", "20-24", "25-29", "30-34", "35-39",
    "40-44", "45-49", "50-54", "55-59", "60-64", "65-69", "70-74", "75-79",
    "80-84", "85-89", "90-94", "95-99", "100+"
]

N_AGE = len(AGE_GROUPS)
FERTILE = range(3, 10)          # brackets 15-19 .. 45-49
CURRENT_YEAR = 2026

# Two-speed grid: 5-year steps to 2100 (high fidelity), 10-year leaps to 2300 (extinction tail)
PYRAMID_YEARS = (
    list(range(1950, CURRENT_YEAR, 5))
    + [CURRENT_YEAR]
    + list(range(2030, 2101, 5))
    + list(range(2110, 2301, 10))
)

# Documented sex-ratio-at-birth distortions (son preference), peak year and level.
# Everywhere else uses the biological norm of 1.05.
SRB_DISTORTION = {
    "CHN": (2000, 1.15),
    "IND": (2005, 1.11),
    "KOR": (1992, 1.14),
    "TWN": (2000, 1.10),
    "VNM": (2012, 1.11),
}
SRB_BASE = 1.05

COUNTRY_PROFILES = [
    ("WLD", "World", "🌍", 2.21, 8180.0, 0.84, 2084, 10290.0, 31.0, "Global"),
    ("KOR", "South Korea", "🇰🇷", 0.72, 51.6, -0.65, 2020, 51.8, 45.2, "Rapid Decline"),
    ("TWN", "Taiwan", "🇹🇼", 0.85, 23.3, -0.42, 2019, 23.6, 44.5, "Rapid Decline"),
    ("HKG", "Hong Kong", "🇭🇰", 0.77, 7.5, -0.38, 2019, 7.52, 46.8, "Rapid Decline"),
    ("SGP", "Singapore", "🇸🇬", 0.97, 5.9, 0.20, 2035, 6.2, 43.1, "Rapid Decline"),
    ("JPN", "Japan", "🇯🇵", 1.20, 123.8, -0.55, 2010, 128.1, 49.5, "Rapid Decline"),
    ("ITA", "Italy", "🇮🇹", 1.24, 58.7, -0.36, 2014, 60.8, 48.4, "Rapid Decline"),
    ("ESP", "Spain", "🇪🇸", 1.16, 47.9, -0.15, 2024, 48.0, 45.8, "Rapid Decline"),
    ("UKR", "Ukraine", "🇺🇦", 0.95, 36.5, -1.20, 1993, 52.2, 44.8, "Rapid Decline"),
    ("POL", "Poland", "🇵🇱", 1.16, 37.6, -0.45, 1998, 38.7, 43.0, "Rapid Decline"),
    ("GRC", "Greece", "🇬🇷", 1.30, 10.3, -0.48, 2011, 11.1, 46.1, "Rapid Decline"),
    ("PRT", "Portugal", "🇵🇹", 1.35, 10.2, -0.22, 2010, 10.6, 46.9, "Rapid Decline"),
    ("CHN", "China", "🇨🇳", 1.00, 1409.0, -0.32, 2021, 1426.0, 39.8, "Rapid Decline"),
    ("DEU", "Germany", "🇩🇪", 1.36, 84.4, -0.12, 2023, 84.6, 46.5, "Aging / Sub-replacement"),
    ("GBR", "United Kingdom", "🇬🇧", 1.49, 68.2, 0.34, 2050, 72.0, 40.8, "Aging / Sub-replacement"),
    ("FRA", "France", "🇫🇷", 1.68, 66.5, 0.20, 2045, 68.2, 42.0, "Aging / Sub-replacement"),
    ("USA", "United States", "🇺🇸", 1.62, 342.0, 0.45, 2080, 375.0, 38.9, "Aging / Sub-replacement"),
    ("CAN", "Canada", "🇨🇦", 1.33, 40.5, 1.10, 2065, 48.0, 41.2, "Aging / Sub-replacement"),
    ("AUS", "Australia", "🇦🇺", 1.58, 26.8, 1.20, 2068, 33.5, 38.0, "Aging / Sub-replacement"),
    ("ISL", "Iceland", "🇮🇸", 1.59, 0.39, 1.05, 2075, 0.52, 37.5, "Aging / Sub-replacement"),
    ("NOR", "Norway", "🇳🇴", 1.41, 5.55, 0.65, 2065, 6.4, 40.2, "Aging / Sub-replacement"),
    ("SWE", "Sweden", "🇸🇪", 1.45, 10.6, 0.50, 2065, 12.1, 41.0, "Aging / Sub-replacement"),
    ("FIN", "Finland", "🇫🇮", 1.26, 5.58, 0.10, 2038, 5.65, 43.5, "Aging / Sub-replacement"),
    ("DNK", "Denmark", "🇩🇰", 1.50, 5.95, 0.45, 2060, 6.5, 42.1, "Aging / Sub-replacement"),
    ("RUS", "Russia", "🇷🇺", 1.42, 143.5, -0.38, 1993, 148.7, 40.5, "Rapid Decline"),
    ("BRA", "Brazil", "🇧🇷", 1.58, 217.0, 0.35, 2042, 230.0, 34.5, "Aging / Sub-replacement"),
    ("MEX", "Mexico", "🇲🇽", 1.75, 129.5, 0.62, 2052, 145.0, 30.5, "Aging / Sub-replacement"),
    ("THA", "Thailand", "🇹🇭", 1.16, 71.7, -0.25, 2028, 72.0, 41.0, "Rapid Decline"),
    ("VNM", "Vietnam", "🇻🇳", 1.90, 100.3, 0.68, 2055, 110.0, 33.0, "Transitioning"),
    ("IND", "India", "🇮🇳", 1.98, 1445.0, 0.72, 2064, 1700.0, 28.7, "Transitioning"),
    ("IDN", "Indonesia", "🇮🇩", 2.12, 280.5, 0.75, 2060, 330.0, 31.0, "Transitioning"),
    ("PHL", "Philippines", "🇵🇭", 2.45, 118.0, 1.25, 2075, 160.0, 26.0, "Growing"),
    ("TUR", "Turkey", "🇹🇷", 1.51, 86.0, 0.55, 2055, 95.0, 33.5, "Transitioning"),
    ("EGY", "Egypt", "🇪🇬", 2.76, 114.5, 1.55, 2085, 175.0, 25.0, "Growing"),
    ("PAK", "Pakistan", "🇵🇰", 3.40, 245.0, 1.90, 2090, 380.0, 21.0, "Rapid Growth"),
    ("NGA", "Nigeria", "🇳🇬", 4.55, 227.0, 2.38, 2100, 545.0, 18.2, "Rapid Growth"),
    ("ZAF", "South Africa", "🇿🇦", 2.25, 61.0, 0.85, 2070, 75.0, 28.0, "Transitioning"),
    ("ETH", "Ethiopia", "🇪🇹", 3.90, 128.0, 2.45, 2095, 275.0, 19.5, "Rapid Growth"),
    ("KEN", "Kenya", "🇰🇪", 3.20, 56.0, 1.85, 2088, 98.0, 20.5, "Rapid Growth"),
    ("ARG", "Argentina", "🇦🇷", 1.82, 46.5, 0.70, 2060, 53.0, 32.5, "Transitioning"),
    ("CHL", "Chile", "🇨🇱", 1.45, 19.8, 0.35, 2045, 21.0, 36.5, "Aging / Sub-replacement"),
    ("COL", "Colombia", "🇨🇴", 1.65, 52.5, 0.60, 2050, 58.0, 32.0, "Aging / Sub-replacement"),
]


# ---------------------------------------------------------------- interpolation

def clamp(v, lo, hi):
    return lo if v < lo else (hi if v > hi else v)


def smoothstep(t):
    """C1-continuous 0->1 ramp with zero slope at both ends."""
    t = clamp(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def ramp(y, y0, v0, y1, v1):
    """Smooth transition of v0 -> v1 across years y0 -> y1."""
    if y <= y0:
        return v0
    if y >= y1:
        return v1
    return v0 + (v1 - v0) * smoothstep((y - y0) / float(y1 - y0))


def through(y, anchors):
    """Smoothly interpolate through a list of (year, value) anchors."""
    if y <= anchors[0][0]:
        return anchors[0][1]
    for (y0, v0), (y1, v1) in zip(anchors, anchors[1:]):
        if y <= y1:
            return ramp(y, y0, v0, y1, v1)
    return anchors[-1][1]


# ------------------------------------------------------------- mortality model

def hazard(age, k, infant_k):
    """Annual mortality hazard: child mortality + background + Gompertz senescence."""
    child = 0.055 * math.exp(-age / 1.6)
    background = 0.00022
    senescent = 0.000021 * math.exp(0.0935 * age)
    return k * (background + senescent) + infant_k * child


def life_table(k, infant_k):
    """Abridged life table over the 5-year brackets.

    Bracket-to-bracket survival must be the ratio of PERSON-YEARS lived
    (L[i+1]/L[i]), not exact-age survival l(5i+5)/l(5i): the people counted in
    a bracket are spread across its five years, so charging them the whole
    bracket's mortality double-counts it. That distinction is worth ~10 years
    of median age in high-child-mortality countries.

    Returns (bracket_survival, birth->bracket-0 factor, e0).
    """
    step = 0.25
    L = [0.0] * N_AGE
    l = 1.0
    a = 0.0
    e0 = 0.0
    while a < 130.0:
        h = hazard(a + step / 2.0, k, infant_k)
        nxt = l * math.exp(-h * step)
        person_years = (l + nxt) / 2.0 * step
        idx = int(a // 5)
        L[min(idx, N_AGE - 1)] += person_years   # everything past 100 lands in 100+
        e0 += person_years
        l = nxt
        a += step
        if l < 1e-9:
            break

    surv = []
    for i in range(N_AGE - 1):
        surv.append(L[i + 1] / L[i] if L[i] > 0 else 0.0)
    # open-ended 100+ bracket: persistence over one more 5-year step
    surv.append(math.exp(-5.0 * hazard(102.5, k, infant_k)))

    birth_surv = L[0] / 5.0      # mean survivorship over ages 0-5, since l(0) = 1
    return surv, birth_surv, e0


# ------------------------------------------------------------- fertility model

def fertility_weights(mac, spread):
    """Age-specific fertility distributed over the fertile brackets, sums to 1.

    High-fertility populations childbear earlier and across a wider age range,
    which shortens generation length and so raises the growth rate for a given
    TFR -- the difference between a median age of 22 and one of 18.
    """
    w = []
    for i in FERTILE:
        mid = i * 5 + 2.5
        w.append(math.exp(-((mid - mac) ** 2) / (2.0 * spread ** 2)))
    tot = sum(w)
    return [v / tot for v in w]


def srb_for(code, year):
    if code not in SRB_DISTORTION:
        return SRB_BASE
    peak_year, peak = SRB_DISTORTION[code]
    bump = (peak - SRB_BASE) * math.exp(-((year - peak_year) ** 2) / (2.0 * 17.0 ** 2))
    return SRB_BASE + bump


# --------------------------------------------------------- cohort projection

class Country:
    """Smooth per-year vital rates for one country."""

    def __init__(self, code, tfr_now, med_age, tfr_1950):
        self.code = code
        self.tfr_now = tfr_now
        self.tfr_1950 = tfr_1950
        dev = clamp((med_age - 18.0) / 32.0, 0.0, 1.0)
        self.k = [(1950, 2.2 + 2.6 * (1.0 - dev)),
                  (CURRENT_YEAR, 0.72 + 0.85 * (1.0 - dev))]
        self.k.append((2100, self.k[1][1] * 0.70))
        # child-mortality multiplier, tuned so modelled under-5 mortality lands
        # near published levels (2026: ~12% Nigeria, ~0.6% South Korea)
        self.ik = [(1950, 0.6 + 5.5 * (1.0 - dev) ** 1.5),
                   (CURRENT_YEAR, 0.05 + 1.5 * (1.0 - dev) ** 2.2)]
        self.ik.append((2100, self.ik[1][1] * 0.45))
        self.mac_anchors = [(1950, 25.5 + 1.5 * dev),
                            (CURRENT_YEAR, 26.5 + 5.5 * dev),
                            (2100, 29.5 + 4.0 * dev)]
        # wider childbearing spread where fertility is high
        self.spread = 5.1 + 1.5 * clamp((tfr_now - 1.4) / 3.2, 0.0, 1.0)

    def tfr(self, year):
        # decline 1950 -> 2026, then held constant (documented assumption)
        if year >= CURRENT_YEAR:
            return self.tfr_now
        return self.tfr_1950 + (self.tfr_now - self.tfr_1950) * smoothstep(
            (year - 1950) / float(CURRENT_YEAR - 1950))

    def mortality(self, year):
        """(k_male, ik_male, k_female, ik_female) -- males carry excess mortality."""
        k = through(year, self.k)
        ik = through(year, self.ik)
        gap = through(year, [(1950, 0.22), (1985, 0.46), (2100, 0.34)])
        return (k * (1.0 + gap), ik * 1.15,
                k * (1.0 - 0.30 * gap), ik * 0.95)

    def mac(self, year):
        return through(year, self.mac_anchors)


def project(country, years):
    """Cohort-component projection. Returns {year: (male_counts, female_counts)}."""
    m = [1.0] * N_AGE
    f = [1.0] * N_AGE

    def step(year):
        nonlocal m, f
        km, ikm, kf, ikf = country.mortality(year)
        sm, bm, _ = life_table(km, ikm)
        sf, bf, _ = life_table(kf, ikf)
        w = fertility_weights(country.mac(year), country.spread)
        tfr = country.tfr(year)

        births = sum(f[i] * tfr * w[j] for j, i in enumerate(FERTILE))
        srb = srb_for(country.code, year)

        nm = [0.0] * N_AGE
        nf = [0.0] * N_AGE
        for i in range(N_AGE - 1, 0, -1):
            nm[i] = m[i - 1] * sm[i - 1]
            nf[i] = f[i - 1] * sf[i - 1]
        # 100+ is open-ended: survivors of 95-99 join survivors already in it
        nm[N_AGE - 1] += m[N_AGE - 1] * sm[N_AGE - 1]
        nf[N_AGE - 1] += f[N_AGE - 1] * sf[N_AGE - 1]
        nm[0] = births * (srb / (1.0 + srb)) * bm
        nf[0] = births * (1.0 / (1.0 + srb)) * bf
        m, f = nm, nf

    # burn-in at 1950 rates so the 1950 frame is a settled age structure
    for _ in range(45):
        step(1950)

    grid = list(range(1950, 2301, 5))
    out = {1950: (list(m), list(f))}
    for y in grid[1:]:
        step(y - 5)
        out[y] = (list(m), list(f))

    # 2026 sits 1 year past the 2025 frame -- blend the neighbours it lies between
    if CURRENT_YEAR not in out:
        lo = max(y for y in grid if y < CURRENT_YEAR)
        hi = min(y for y in grid if y > CURRENT_YEAR)
        t = (CURRENT_YEAR - lo) / float(hi - lo)
        mlo, flo = out[lo]
        mhi, fhi = out[hi]
        out[CURRENT_YEAR] = (
            [mlo[i] + (mhi[i] - mlo[i]) * t for i in range(N_AGE)],
            [flo[i] + (fhi[i] - flo[i]) * t for i in range(N_AGE)],
        )
    return {y: out[y] for y in years}


# ------------------------------------------------------------------- metrics

def median_age(counts):
    total = sum(counts)
    if total <= 0:
        return 0.0
    half = total / 2.0
    run = 0.0
    for i, v in enumerate(counts):
        if run + v >= half:
            within = (half - run) / v if v > 0 else 0.0
            return i * 5.0 + within * 5.0
        run += v
    return N_AGE * 5.0


def calibrate_tfr_1950(code, tfr_now, med_age, years):
    """Fit the 1950 TFR level so the modelled 2026 median age hits its anchor."""
    lo, hi = 0.05, 6.5

    def modelled(delta):
        c = Country(code, tfr_now, med_age, tfr_now + delta)
        frames = project(c, [CURRENT_YEAR])
        m, f = frames[CURRENT_YEAR]
        return median_age([m[i] + f[i] for i in range(N_AGE)])

    # median age falls as historical fertility rises -> monotone decreasing in delta
    for _ in range(34):
        mid = (lo + hi) / 2.0
        if modelled(mid) > med_age:
            lo = mid
        else:
            hi = mid
    delta = (lo + hi) / 2.0
    return tfr_now + delta, modelled(delta)


# ---------------------------------------------------------------- dataset

def calculate_demographics():
    dataset = {
        "metadata": {
            "version": "3.0.0",
            "source": "SYNTHETIC parametric model. Country anchors (TFR, 2026 population, "
                      "growth rate, peak, median age) approximate published UN WPP headline "
                      "figures; all pyramids, trajectories and life expectancies are modelled "
                      "by scripts/build_data.py and are NOT UN data or projections.",
            "method": "Cohort-component projection: births from age-specific fertility, "
                      "survival from a Gompertz-Makeham hazard with sex-specific mortality. "
                      "Historical TFR level fitted per country to its stated 2026 median age. "
                      "TFR held constant after 2026; migration ignored.",
            "ageGroups": AGE_GROUPS,
            "pyramidYears": PYRAMID_YEARS,
            "pyramidYearStep": 5,
            "currentYear": CURRENT_YEAR,
            "replacementTFR": 2.10,
            "generatedAt": "2026-09-02",
            "calibration": None
        },
        "countries": {}
    }

    diagnostics = []

    for code, name, flag, tfr, pop2026, growth_rate, peak_yr, peak_pop, med_age, category in COUNTRY_PROFILES:
        is_sub_replacement = tfr < 2.10

        tfr_1950, achieved_median = calibrate_tfr_1950(code, tfr, med_age, PYRAMID_YEARS)
        diagnostics.append((code, med_age, achieved_median, tfr_1950))

        country = Country(code, tfr, med_age, tfr_1950)
        frames = project(country, PYRAMID_YEARS)

        pyramids = {}
        for yr in PYRAMID_YEARS:
            mc, fc = frames[yr]
            total = sum(mc) + sum(fc)
            m_pct = [round(v / total * 100.0, 3) for v in mc]
            f_pct = [round(v / total * 100.0, 3) for v in fc]

            km, ikm, kf, ikf = country.mortality(yr)
            _, _, e0m = life_table(km, ikm)
            _, _, e0f = life_table(kf, ikf)

            m_tot, f_tot = sum(mc), sum(fc)
            old = list(range(13, N_AGE))          # 65+
            young = list(range(0, 3))             # 0-14
            working = list(range(3, 13))          # 15-64
            old_m = sum(mc[i] for i in old)
            old_f = sum(fc[i] for i in old)
            young_tot = sum(mc[i] + fc[i] for i in young)
            working_tot = sum(mc[i] + fc[i] for i in working)
            med_m = median_age(mc)
            med_f = median_age(fc)

            pyramids[str(yr)] = {
                "m": m_pct,
                "f": f_pct,
                "tfr": round(country.tfr(yr), 2),
                "srb": round(srb_for(code, yr), 3),
                "sexRatio": round(m_tot / f_tot * 100.0, 1),
                "medianAgeM": round(med_m, 1),
                "medianAgeF": round(med_f, 1),
                "medianAgeGap": round(med_f - med_m, 1),
                "lifeExpM": round(e0m, 1),
                "lifeExpF": round(e0f, 1),
                "lifeExpGap": round(e0f - e0m, 1),
                "share65": round((old_m + old_f) / total * 100.0, 1),
                "female65Share": round(old_f / (old_m + old_f) * 100.0, 1) if (old_m + old_f) > 0 else 0.0,
                "share014": round(young_tot / total * 100.0, 1),
                "dependencyRatio": round((young_tot + old_m + old_f) / working_tot * 100.0, 1) if working_tot > 0 else 0.0,
            }

        # ---- population trajectory (level), unchanged model + the 2026 anchor point
        if tfr < 0.85:
            decline_annual = -1.35
        elif tfr < 1.15:
            decline_annual = -0.95
        elif tfr < 1.40:
            decline_annual = -0.65
        elif tfr < 1.70:
            decline_annual = -0.40
        elif is_sub_replacement:
            decline_annual = -0.25
        else:
            decline_annual = 0.0

        if is_sub_replacement:
            pop_1950 = pop2026 * 0.40 if code != "WLD" else 2500.0
        else:
            pop_1950 = pop2026 * 0.22

        if peak_yr <= CURRENT_YEAR:
            base_yr, base_pop = CURRENT_YEAR, pop2026
        else:
            base_yr, base_pop = peak_yr, peak_pop

        if is_sub_replacement:
            halving_year = int(base_yr + abs(math.log(0.5) / (decline_annual / 100.0)))
            extinction_year = int(base_yr + abs(math.log(0.008) / (decline_annual / 100.0)))
            end_projection_year = 2300
        else:
            halving_year = None
            extinction_year = None
            end_projection_year = 2300

        trajectory = []
        for y in list(range(1950, CURRENT_YEAR, 5)) + [CURRENT_YEAR]:
            if y == CURRENT_YEAR:
                p = pop2026
            else:
                t = (y - 1950) / float(CURRENT_YEAR - 1950)
                p = pop_1950 + (pop2026 - pop_1950) * (math.sin(t * math.pi / 2.0) ** 1.3)
            trajectory.append({"year": y, "pop": round(p, 2), "historical": True})

        future_years = list(range(2030, 2101, 5)) + list(range(2110, 2301, 10))
        for y in future_years:
            if is_sub_replacement:
                if y <= peak_yr:
                    t = (y - CURRENT_YEAR) / max(1, peak_yr - CURRENT_YEAR)
                    p = pop2026 + (peak_pop - pop2026) * math.sin(t * math.pi / 2.0)
                else:
                    years_past_peak = y - peak_yr
                    accel = (decline_annual / 100.0) * (1.0 + (years_past_peak / 100.0) * 0.35)
                    p = peak_pop * math.exp(accel * years_past_peak)
                    if p < 0.05:
                        p = 0.0
            else:
                growth_t = (y - CURRENT_YEAR) / 100.0
                factor = (growth_rate / 100.0) * max(0.2, 1.0 - growth_t * 0.6)
                p = pop2026 * math.exp(factor * (y - CURRENT_YEAR))
            trajectory.append({"year": y, "pop": round(max(0.0, p), 2), "historical": False})

        p2050 = next((pt["pop"] for pt in trajectory if pt["year"] == 2050), pop2026)
        p2100 = next((pt["pop"] for pt in trajectory if pt["year"] == 2100), pop2026)

        now = pyramids[str(CURRENT_YEAR)]
        dataset["countries"][code] = {
            "code": code,
            "name": name,
            "flag": flag,
            "category": category,
            "tfr": tfr,
            "isSubReplacement": is_sub_replacement,
            "population2026": pop2026,
            "growthRate2026": growth_rate,
            "peakYear": peak_yr,
            "peakPopulation": peak_pop,
            "medianAge": med_age,
            "medianAgeM": now["medianAgeM"],
            "medianAgeF": now["medianAgeF"],
            "medianAgeGap": now["medianAgeGap"],
            "lifeExpM": now["lifeExpM"],
            "lifeExpF": now["lifeExpF"],
            "lifeExpGap": now["lifeExpGap"],
            "sexRatio": now["sexRatio"],
            "tfr1950Modelled": round(tfr_1950, 2),
            "pop2050": p2050,
            "pop2100": p2100,
            "halvingYear": halving_year,
            "extinctionYear": extinction_year,
            "trajectoryEndYear": end_projection_year,
            "trajectory": trajectory,
            "pyramids": pyramids
        }

    devs = [abs(t - m) for _, t, m, _ in diagnostics]
    off = [(c, round(t, 1), round(m, 1)) for c, t, m, _ in diagnostics if abs(t - m) > 1.0]
    dataset["metadata"]["calibration"] = {
        "target": "modelled 2026 median age vs the stated medianAge anchor",
        "withinOneYear": sum(1 for d in devs if d <= 1.0),
        "countries": len(devs),
        "meanAbsDeviationYears": round(sum(devs) / len(devs), 2),
        "maxAbsDeviationYears": round(max(devs), 2),
        "note": "High-fertility countries run a few years older than their anchor: the "
                "model cannot reach a median age near 18 at the stated TFR. Pyramid shape "
                "for those countries is indicative only.",
        "offAnchor": off,
    }
    return dataset, diagnostics


def main():
    dest_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
    os.makedirs(dest_dir, exist_ok=True)
    out_file = os.path.join(dest_dir, "demographics.json")

    data, diagnostics = calculate_demographics()
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

    worst = max(diagnostics, key=lambda d: abs(d[1] - d[2]))
    print(f"Demographics & trajectory dataset created: {out_file}")
    print(f"Countries: {len(data['countries'])}  pyramid frames each: {len(PYRAMID_YEARS)}"
          f"  ({PYRAMID_YEARS[0]}-{PYRAMID_YEARS[-1]}, 5-year step + {CURRENT_YEAR} anchor)")
    print(f"Median-age calibration worst case: {worst[0]} target {worst[1]:.1f} "
          f"modelled {worst[2]:.1f} (fitted 1950 TFR {worst[3]:.2f})")
    print(f"Size: {os.path.getsize(out_file) / 1024:.0f} KB")


if __name__ == "__main__":
    main()
