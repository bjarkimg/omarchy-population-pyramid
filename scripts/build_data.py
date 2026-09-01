#!/usr/bin/env python3
"""
Demographics & Population Decline Data Generator
Generates:
1. 21-bracket vertical population pyramid distributions (1950-2100).
2. Continuous historical + future extrapolation curve:
   - For TFR < 2.1: Extrapolates downward until population hits 0 (extinction horizon).
   - For TFR >= 2.1: Projects growth for the next 100 years (up to 2126).
"""

import json
import math
import os
import sys

AGE_GROUPS = [
    "0-4", "5-9", "10-14", "15-19", "20-24", "25-29", "30-34", "35-39",
    "40-44", "45-49", "50-54", "55-59", "60-64", "65-69", "70-74", "75-79",
    "80-84", "85-89", "90-94", "95-99", "100+"
]

PYRAMID_YEARS = [1950, 1970, 1990, 2000, 2010, 2020, 2026, 2030, 2040, 2050, 2060, 2070, 2080, 2090, 2100]

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

def calculate_demographics():
    dataset = {
        "metadata": {
            "version": "2.0.0",
            "source": "UN World Population Prospects & Cohort Decline Models",
            "ageGroups": AGE_GROUPS,
            "pyramidYears": PYRAMID_YEARS,
            "replacementTFR": 2.10,
            "generatedAt": "2026-09-01"
        },
        "countries": {}
    }

    for code, name, flag, tfr, pop2026, growth_rate, peak_yr, peak_pop, med_age, category in COUNTRY_PROFILES:
        is_sub_replacement = tfr < 2.10

        # Decline rate modeling:
        # Lower TFR leads to compounding generational contraction
        if tfr < 0.85:      # S.Korea, HK, Taiwan
            decline_annual = -1.35
        elif tfr < 1.15:    # China, Spain, Thailand
            decline_annual = -0.95
        elif tfr < 1.40:    # Japan, Italy, Germany
            decline_annual = -0.65
        elif tfr < 1.70:    # USA, UK, France, Iceland
            decline_annual = -0.40
        elif is_sub_replacement:
            decline_annual = -0.25
        else:
            decline_annual = 0.0

        # 1. Historical population modeling (1950 - 2026)
        # 1950 baseline was typically 35-50% of 2026 pop in developed/Asian nations, ~20% in rapid-growth nations
        if is_sub_replacement:
            pop_1950 = pop2026 * 0.40 if code != "WLD" else 2500.0
            pop_1980 = pop2026 * 0.75 if code != "WLD" else 4450.0
        else:
            pop_1950 = pop2026 * 0.22
            pop_1980 = pop2026 * 0.45

        # 2. Key projection milestones
        if peak_yr <= 2026:
            base_yr = 2026
            base_pop = pop2026
        else:
            base_yr = peak_yr
            base_pop = peak_pop

        if is_sub_replacement:
            # Halving year (50% of peak)
            halving_offset = abs(math.log(0.5) / (decline_annual / 100.0))
            halving_year = int(base_yr + halving_offset)
            
            # Theoretical zero / extinction horizon (<1% of peak population)
            extinction_offset = abs(math.log(0.008) / (decline_annual / 100.0))
            extinction_year = int(base_yr + extinction_offset)
            end_projection_year = min(2250, max(2126, extinction_year + 5))
        else:
            halving_year = None
            extinction_year = None
            end_projection_year = 2026 + 100 # Next 100 years (2126)

        # 3. Build continuous trajectory line data points (every 5 years from 1950 to end_projection_year)
        trajectory = []
        
        # Historical step (1950 -> 2026)
        for y in range(1950, 2027, 5):
            t = (y - 1950) / 76.0 # 0 at 1950, 1 at 2026
            # S-curve historical growth
            p = pop_1950 + (pop2026 - pop_1950) * (math.sin(t * math.pi / 2.0) ** 1.3)
            if y == 2026:
                p = pop2026
            trajectory.append({"year": y, "pop": round(p, 2), "historical": True})

        # Future projection step (2027 -> end_projection_year)
        for y in range(2030, end_projection_year + 1, 5):
            if is_sub_replacement:
                if y <= peak_yr:
                    # Approaching peak
                    t = (y - 2026) / max(1, peak_yr - 2026)
                    p = pop2026 + (peak_pop - pop2026) * math.sin(t * math.pi / 2.0)
                else:
                    # In post-peak decline phase towards zero
                    years_past_peak = y - peak_yr
                    # Compounding acceleration as childbearing cohorts shrink
                    accel_decline = (decline_annual / 100.0) * (1.0 + (years_past_peak / 100.0) * 0.35)
                    p = peak_pop * math.exp(accel_decline * years_past_peak)
                    if p < 0.05:
                        p = 0.0
            else:
                # Growing country: project 100 years of demographic expansion tapering towards plateau
                growth_t = (y - 2026) / 100.0
                growth_factor = (growth_rate / 100.0) * max(0.2, 1.0 - growth_t * 0.6)
                p = pop2026 * math.exp(growth_factor * (y - 2026))

            trajectory.append({"year": y, "pop": round(max(0.0, p), 2), "historical": False})

        # 4. Generate age pyramids (1950 to 2100)
        pyramids = {}
        for yr in PYRAMID_YEARS:
            m_bars = []
            f_bars = []
            for i, age_lbl in enumerate(AGE_GROUPS):
                age_val = i * 5 + 2.5
                if yr <= 1970:
                    weight = math.exp(-0.038 * age_val)
                elif yr <= 2026:
                    if tfr < 1.3:
                        base_mean = 48.0 - (2026 - yr) * 0.3
                        weight = math.exp(-((age_val - base_mean)**2) / 800.0) + 0.15 * math.exp(-0.02 * age_val)
                        if age_val < 30:
                            weight *= (0.3 + 0.7 * (tfr / 2.1) + 0.015 * age_val)
                    else:
                        base_mean = 35.0
                        weight = math.exp(-((age_val - base_mean)**2) / 950.0) + 0.3 * math.exp(-0.025 * age_val)
                else:
                    future_factor = (yr - 2026) / 74.0
                    if tfr < 1.5:
                        base_mean = 65.0 + 10.0 * future_factor
                        weight = math.exp(-((age_val - base_mean)**2) / 600.0) + 0.1
                        if age_val < 40:
                            shrinkage = max(0.12, (tfr / 2.1) ** (1.0 + future_factor * 1.5))
                            weight *= shrinkage
                    else:
                        base_mean = 45.0 + 12.0 * future_factor
                        weight = math.exp(-((age_val - base_mean)**2) / 850.0) + 0.2

                if age_val > 75:
                    weight *= math.exp(-0.08 * (age_val - 75))

                male_ratio = 1.05 - 0.0035 * age_val
                if age_val > 70:
                    male_ratio = max(0.45, 1.0 - 0.012 * (age_val - 70))
                female_ratio = 2.0 - male_ratio

                m_bars.append(round(max(0.05, weight * male_ratio * 10.0), 2))
                f_bars.append(round(max(0.05, weight * female_ratio * 10.0), 2))

            total_sum = sum(m_bars) + sum(f_bars)
            pyramids[str(yr)] = {
                "m": [round((v / total_sum) * 100.0, 2) for v in m_bars],
                "f": [round((v / total_sum) * 100.0, 2) for v in f_bars]
            }

        # 2050 and 2100 population lookup from trajectory
        p2050 = next((pt["pop"] for pt in trajectory if pt["year"] == 2050), pop2026)
        p2100 = next((pt["pop"] for pt in trajectory if pt["year"] == 2100), pop2026)

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
            "pop2050": p2050,
            "pop2100": p2100,
            "halvingYear": halving_year,
            "extinctionYear": extinction_year,
            "trajectoryEndYear": end_projection_year,
            "trajectory": trajectory,
            "pyramids": pyramids
        }

    return dataset

def main():
    dest_dir = os.path.expanduser("~/.config/omarchy/plugins/bmg.population-pyramid/data")
    os.makedirs(dest_dir, exist_ok=True)
    out_file = os.path.join(dest_dir, "demographics.json")

    data = calculate_demographics()
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"Demographics & trajectory dataset created: {out_file}")
    print(f"Total countries indexed: {len(data['countries'])}")

if __name__ == "__main__":
    main()
