#!/usr/bin/env python3
"""Generate Resources/cities.tsv from GeoNames dumps.

Input files (in data/): cities5000.txt, admin1CodesASCII.txt, countryInfo.txt
Output columns: name, region, country, timezone, population
Sorted by population descending so prefix search can rank by row order.
"""
import csv
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
data = root / "data"
out_path = root / "Resources" / "cities.tsv"

admin1 = {}
with open(data / "admin1CodesASCII.txt", encoding="utf-8") as f:
    for line in f:
        parts = line.rstrip("\n").split("\t")
        if len(parts) >= 2:
            admin1[parts[0]] = parts[1]

countries = {}
with open(data / "countryInfo.txt", encoding="utf-8") as f:
    for line in f:
        if line.startswith("#"):
            continue
        parts = line.rstrip("\n").split("\t")
        if len(parts) >= 5:
            countries[parts[0]] = parts[4]

rows = []
with open(data / "cities5000.txt", encoding="utf-8") as f:
    for line in f:
        p = line.rstrip("\n").split("\t")
        if len(p) < 18:
            continue
        name, cc, a1, pop, tz = p[1], p[8], p[10], p[14], p[17]
        if not tz or not name:
            continue
        region = admin1.get(f"{cc}.{a1}", "")
        country = countries.get(cc, cc)
        try:
            pop_i = int(pop)
        except ValueError:
            pop_i = 0
        rows.append((name, region, country, tz, pop_i))

rows.sort(key=lambda r: -r[4])

out_path.parent.mkdir(parents=True, exist_ok=True)
with open(out_path, "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f, delimiter="\t", lineterminator="\n", quoting=csv.QUOTE_NONE, quotechar=None)
    for r in rows:
        w.writerow(r)

print(f"{len(rows)} cities -> {out_path} ({out_path.stat().st_size / 1e6:.1f} MB)")
