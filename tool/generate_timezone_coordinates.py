#!/usr/bin/env python3
"""Regenerates lib/services/timezone_coordinates.dart from the tzdb zone.tab.

Run with:  python3 tool/generate_timezone_coordinates.py
"""

import pathlib
import re

ZONE_TAB = pathlib.Path("/usr/share/zoneinfo/zone.tab")
OUT = pathlib.Path(__file__).resolve().parents[1] / "lib/services/timezone_coordinates.dart"

# ISO 6709: +DDMM+DDDMM or +DDMMSS+DDDMMSS
ISO6709 = re.compile(
    r"^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$"
)


def parse(coords: str):
    m = ISO6709.match(coords)
    if not m:
        raise ValueError(f"unparsable coordinates: {coords}")
    lat_sign, lat_d, lat_m, lat_s, lng_sign, lng_d, lng_m, lng_s = m.groups()
    lat = int(lat_d) + int(lat_m) / 60 + int(lat_s or 0) / 3600
    lng = int(lng_d) + int(lng_m) / 60 + int(lng_s or 0) / 3600
    if lat_sign == "-":
        lat = -lat
    if lng_sign == "-":
        lng = -lng
    return round(lat, 2), round(lng, 2)


def main():
    entries = {}
    for line in ZONE_TAB.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        _, coords, zone = parts[0], parts[1], parts[2]
        entries[zone] = parse(coords)

    lines = [
        "// GENERATED FILE — do not edit by hand.",
        "// Regenerate with: python3 tool/generate_timezone_coordinates.py",
        "//",
        "// Representative coordinates for every IANA timezone, taken from the tz",
        "// database's zone.tab. Used to seed sunrise/sunset calculation from the",
        "// device timezone so the feature works before (or without) any GPS fix.",
        "",
        "const Map<String, (double, double)> timezoneCoordinates = {",
    ]
    for zone in sorted(entries):
        lat, lng = entries[zone]
        lines.append(f"  '{zone}': ({lat}, {lng}),")
    lines.append("};")
    lines.append("")

    OUT.write_text("\n".join(lines))
    print(f"wrote {len(entries)} zones to {OUT}")


if __name__ == "__main__":
    main()
