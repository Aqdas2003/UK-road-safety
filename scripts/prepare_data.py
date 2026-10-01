"""
Prepare STATS19 road safety data for loading into PostgreSQL.

What this script does:
  1. Downloads the last-5-years collision, vehicle and casualty CSVs from DfT
  2. Downloads the official data guide (Excel) and turns its code list into
     a clean lookup CSV, so codes like 1/2/3 can become Fatal/Serious/Slight
  3. Checks each CSV has the columns the SQL expects (catches schema changes)

Usage (from the project root):
    python scripts/prepare_data.py
Requires: pip install -r requirements.txt
"""
from pathlib import Path
import csv
import urllib.request

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
BASE = "https://data.dft.gov.uk/road-accidents-safety-data"
GUIDE_URL = ("https://assets.publishing.service.gov.uk/media/6ab2a71d997a4b2950cced58/"
             "dft-road-casualty-statistics-road-safety-open-dataset-data-guide-2025.xlsx")

FILES = {
    "collision.csv": f"{BASE}/dft-road-casualty-statistics-collision-last-5-years.csv",
    "vehicle.csv":   f"{BASE}/dft-road-casualty-statistics-vehicle-last-5-years.csv",
    "casualty.csv":  f"{BASE}/dft-road-casualty-statistics-casualty-last-5-years.csv",
    "guide.xlsx":    GUIDE_URL,
}

# Columns the SQL scripts rely on. If DfT renames any, we find out here,
# not halfway through a database load.
REQUIRED = {
    "collision.csv": ["collision_index", "collision_year", "longitude", "latitude",
                      "collision_severity", "number_of_vehicles", "number_of_casualties",
                      "date", "day_of_week", "time", "local_authority_ons_district",
                      "road_type", "speed_limit", "light_conditions", "weather_conditions",
                      "road_surface_conditions", "urban_or_rural_area",
                      "collision_adjusted_severity_serious", "collision_adjusted_severity_slight"],
    "vehicle.csv":   ["collision_index", "vehicle_reference", "vehicle_type",
                      "sex_of_driver", "age_band_of_driver"],
    "casualty.csv":  ["collision_index", "vehicle_reference", "casualty_reference",
                      "casualty_class", "sex_of_casualty", "age_of_casualty",
                      "age_band_of_casualty", "casualty_severity", "casualty_type",
                      "casualty_adjusted_severity_serious", "casualty_adjusted_severity_slight"],
}


def download(name: str, url: str) -> None:
    target = DATA / name
    if target.exists() and target.stat().st_size > 1000:
        print(f"[skip] {name} already downloaded")
        return
    print(f"[get ] {name} ...")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as r, open(target, "wb") as f:
        f.write(r.read())
    print(f"[done] {name} ({target.stat().st_size / 1_000_000:.0f} MB)")


def build_lookups() -> None:
    """Turn the data guide's code list into data/lookups.csv (field, code, label)."""
    guide = pd.read_excel(DATA / "guide.xlsx", sheet_name=0)
    guide.columns = ["table_name", "field", "code", "label", "note"]
    guide = guide.dropna(subset=["code", "label"])

    # Codes come in as a mix of numbers (1.0) and text (E06000001).
    # Normalise to clean text so they match the CSV values exactly.
    def clean_code(c):
        if isinstance(c, float) and c.is_integer():
            return str(int(c))
        return str(c).strip()

    guide["code"] = guide["code"].map(clean_code)
    guide["label"] = guide["label"].astype(str).str.strip()

    # The guide has a few duplicate codes (e.g. two labels for one code).
    # Keep the first so each (field, code) pair is unique.
    before = len(guide)
    guide = guide.drop_duplicates(subset=["field", "code"], keep="first")
    print(f"[info] lookups: {len(guide)} codes ({before - len(guide)} duplicates removed)")

    guide[["field", "code", "label"]].to_csv(DATA / "lookups.csv", index=False)
    print("[done] lookups.csv")


def validate() -> None:
    for name, cols in REQUIRED.items():
        with open(DATA / name, newline="", encoding="utf-8") as f:
            header = next(csv.reader(f))
        missing = [c for c in cols if c not in header]
        if missing:
            raise SystemExit(f"[FAIL] {name} is missing columns: {missing}. "
                             "DfT may have changed the file format.")
        print(f"[ok  ] {name}: {len(header)} columns, all required columns present")


if __name__ == "__main__":
    DATA.mkdir(exist_ok=True)
    (ROOT / "powerbi" / "data").mkdir(parents=True, exist_ok=True)   # export target (git-ignored)
    for name, url in FILES.items():
        download(name, url)
    build_lookups()
    validate()
    print("\nData ready. Next: psql -U postgres -d road_safety -f run_all.sql")
