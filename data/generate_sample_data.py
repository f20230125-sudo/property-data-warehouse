"""Generate deterministic, synthetic source extracts for the property data warehouse.

Writes three CSVs to data/raw/ that mimic what an operational listings system would export:

    locations.csv      master list of locations (one row per sub-community)
    agent_history.csv  change log of agents (one row each time agency / verification changes)
    listings.csv       one row per listing, as of AS_OF (lifecycle columns filled in)

Everything here is synthetic: names, agencies and prices are invented and are NOT real
market data. The seed is fixed, so re-running produces byte-identical files.

A handful of rows are deliberately dirty (unknown location ids, zero sizes) so the load
scripts have real data-quality cases to handle.

Usage:  python data/generate_sample_data.py
"""
from __future__ import annotations

import csv
import math
import random
from datetime import date, timedelta
from pathlib import Path
from typing import NamedTuple

SEED = 20260831
N_LISTINGS = 6000
N_AGENTS = 120
DATA_START = date(2025, 1, 1)
AS_OF = date(2026, 8, 31)  # snapshot date of the extract
OUT_DIR = Path(__file__).parent / "raw"

N_UNKNOWN_LOCATION = 5  # listings whose location_id is not in the master list
N_ZERO_SIZE = 3  # listings with a non-positive size (rejected by staging)


class Loc(NamedTuple):
    location_id: str
    emirate: str
    city: str
    community: str
    sub_community: str
    market_tier: str
    base_ppsf: int  # baseline sale price, AED per sqft
    weight: int  # relative share of listings
    type_mix: dict[str, float]


APT = {"Apartment": 0.88, "Penthouse": 0.12}
LANDED = {"Villa": 0.65, "Townhouse": 0.35}

LOCATIONS = [
    Loc("LOC-001", "Dubai", "Dubai", "Dubai Marina", "Marina Promenade", "Prime", 2000, 6, APT),
    Loc("LOC-002", "Dubai", "Dubai", "Dubai Marina", "Marina Gate", "Prime", 2300, 4, APT),
    Loc("LOC-003", "Dubai", "Dubai", "Downtown Dubai", "Old Town", "Prime", 2900, 4, APT),
    Loc("LOC-004", "Dubai", "Dubai", "Downtown Dubai", "Burj Views", "Prime", 2700, 3, APT),
    Loc("LOC-005", "Dubai", "Dubai", "Palm Jumeirah", "Shoreline Apartments", "Prime", 3300, 3, APT),
    Loc("LOC-006", "Dubai", "Dubai", "Palm Jumeirah", "Signature Villas", "Prime", 4800, 2, {"Villa": 1.0}),
    Loc("LOC-007", "Dubai", "Dubai", "Business Bay", "Executive Towers", "Mid-market", 1900, 4, APT),
    Loc("LOC-008", "Dubai", "Dubai", "Business Bay", "Bay Square", "Mid-market", 1750, 3, APT),
    Loc("LOC-009", "Dubai", "Dubai", "Jumeirah Village Circle", "JVC District 10", "Affordable", 1150, 6, {"Apartment": 0.8, "Townhouse": 0.2}),
    Loc("LOC-010", "Dubai", "Dubai", "Jumeirah Village Circle", "JVC District 12", "Affordable", 1100, 4, {"Apartment": 0.8, "Townhouse": 0.2}),
    Loc("LOC-011", "Dubai", "Dubai", "Jumeirah Lake Towers", "Cluster D", "Mid-market", 1450, 4, {"Apartment": 1.0}),
    Loc("LOC-012", "Dubai", "Dubai", "Jumeirah Lake Towers", "Cluster T", "Mid-market", 1400, 3, {"Apartment": 1.0}),
    Loc("LOC-013", "Dubai", "Dubai", "Dubai Hills Estate", "Sidra", "Mid-market", 2000, 3, {"Villa": 0.6, "Townhouse": 0.4}),
    Loc("LOC-014", "Dubai", "Dubai", "Dubai Hills Estate", "Park Heights", "Mid-market", 2100, 4, APT),
    Loc("LOC-015", "Dubai", "Dubai", "Arabian Ranches", "Alvorada", "Mid-market", 1500, 2, {"Villa": 0.8, "Townhouse": 0.2}),
    Loc("LOC-016", "Dubai", "Dubai", "Arabian Ranches", "Palmera", "Mid-market", 1450, 2, {"Villa": 0.9, "Townhouse": 0.1}),
    Loc("LOC-017", "Dubai", "Dubai", "Mirdif", "N/A", "Affordable", 1150, 3, {"Villa": 0.5, "Townhouse": 0.2, "Apartment": 0.3}),
    Loc("LOC-018", "Dubai", "Dubai", "Dubai Silicon Oasis", "N/A", "Affordable", 950, 4, {"Apartment": 1.0}),
    Loc("LOC-019", "Dubai", "Dubai", "Dubai Sports City", "N/A", "Affordable", 900, 3, {"Apartment": 1.0}),
    Loc("LOC-020", "Dubai", "Dubai", "Al Barsha South", "N/A", "Affordable", 1250, 3, {"Apartment": 0.8, "Townhouse": 0.2}),
    Loc("LOC-021", "Dubai", "Dubai", "Deira", "N/A", "Affordable", 1000, 2, {"Apartment": 1.0}),
    Loc("LOC-022", "Dubai", "Dubai", "Damac Hills", "N/A", "Mid-market", 1300, 3, {"Villa": 0.5, "Townhouse": 0.2, "Apartment": 0.3}),
    Loc("LOC-023", "Abu Dhabi", "Abu Dhabi", "Al Reem Island", "Shams Abu Dhabi", "Mid-market", 1350, 4, {"Apartment": 1.0}),
    Loc("LOC-024", "Abu Dhabi", "Abu Dhabi", "Al Reem Island", "Marina Square", "Mid-market", 1300, 3, {"Apartment": 1.0}),
    Loc("LOC-025", "Abu Dhabi", "Abu Dhabi", "Yas Island", "Yas Acres", "Mid-market", 1350, 3, {"Villa": 0.3, "Townhouse": 0.5, "Apartment": 0.2}),
    Loc("LOC-026", "Abu Dhabi", "Abu Dhabi", "Yas Island", "Ansam", "Mid-market", 1600, 2, {"Apartment": 1.0}),
    Loc("LOC-027", "Abu Dhabi", "Abu Dhabi", "Saadiyat Island", "Saadiyat Beach", "Prime", 2800, 2, {"Villa": 0.5, "Apartment": 0.5}),
    Loc("LOC-028", "Abu Dhabi", "Abu Dhabi", "Al Reef", "N/A", "Affordable", 1000, 3, LANDED),
    Loc("LOC-029", "Abu Dhabi", "Al Ain", "Al Jimi", "N/A", "Affordable", 600, 2, {"Apartment": 0.6, "Villa": 0.4}),
    Loc("LOC-030", "Abu Dhabi", "Al Ain", "Hili", "N/A", "Affordable", 550, 1, {"Apartment": 0.6, "Villa": 0.4}),
    Loc("LOC-031", "Sharjah", "Sharjah", "Al Khan", "N/A", "Affordable", 900, 3, {"Apartment": 1.0}),
    Loc("LOC-032", "Sharjah", "Sharjah", "Al Majaz", "N/A", "Affordable", 850, 2, {"Apartment": 1.0}),
    Loc("LOC-033", "Sharjah", "Sharjah", "Aljada", "N/A", "Mid-market", 1150, 2, {"Apartment": 1.0}),
]

# bedrooms -> (share, min sqft, max sqft)
BEDROOMS: dict[str, dict[int, tuple[float, int, int]]] = {
    "Apartment": {0: (0.14, 330, 520), 1: (0.34, 600, 950), 2: (0.34, 950, 1500), 3: (0.14, 1500, 2200), 4: (0.04, 2200, 3200)},
    "Penthouse": {2: (0.20, 1800, 2800), 3: (0.40, 2800, 4200), 4: (0.30, 4200, 6000), 5: (0.10, 6000, 9000)},
    "Townhouse": {2: (0.15, 1400, 1900), 3: (0.50, 1900, 2700), 4: (0.30, 2700, 3500), 5: (0.05, 3500, 4200)},
    "Villa": {3: (0.20, 2500, 3500), 4: (0.35, 3500, 5000), 5: (0.30, 5000, 7000), 6: (0.10, 7000, 9500), 7: (0.05, 9000, 13000)},
}
TYPE_PPSF = {"Apartment": 1.0, "Penthouse": 1.3, "Townhouse": 0.95, "Villa": 1.0}
APT_BED_ADJ = {0: 1.12, 1: 1.05, 2: 1.0, 3: 0.95, 4: 0.90}
TIER_YIELD = {"Prime": 0.055, "Mid-market": 0.068, "Affordable": 0.078}
TIER_TRAFFIC = {"Prime": 1.4, "Mid-market": 1.0, "Affordable": 0.8}

FIRST_NAMES = [
    "Omar", "Layla", "Ahmed", "Sara", "Rohan", "Priya", "Daniel", "Elena", "Hassan", "Mariam",
    "Yusuf", "Nadia", "Karim", "Aisha", "Vikram", "Sofia", "Tariq", "Hana", "Arjun", "Leila",
    "Ivan", "Noor", "Ravi", "Amira", "Faisal", "Dina", "Sameer", "Rania", "Jamal", "Zainab",
    "Marco", "Ines", "Khalid", "Fatima", "Adil", "Meera", "Samir", "Yara", "Bilal", "Lina",
]
LAST_NAMES = [
    "Al Mansoori", "Khan", "Sharma", "Haddad", "Petrov", "Nasser", "Rahman", "Mitchell", "Farouk", "Iyer",
    "Costa", "Al Suwaidi", "Malik", "Verma", "Hussein", "Novak", "Qureshi", "Saleh", "Fernandes", "Rashid",
    "Bhatt", "Kowalski", "Aziz", "Menon", "Darwish", "Ortiz", "Siddiqui", "Barakat", "Thomas", "Joseph",
    "Ali", "Ansari", "Kapoor", "Yilmaz", "Youssef", "Reddy", "Zaman", "Lopez", "Sultan", "Fischer",
]
AGENCIES = [
    "Northgate Realty", "Blue Harbour Estates", "Crescent Property Advisors", "Sandstone Properties",
    "Meridian Homes", "Gulf Horizon Realty", "Oasis Key Realty", "Falcon Ridge Properties",
    "Coral Bay Real Estate", "Zenith Property Group", "Palmview Realty", "Desert Rose Estates",
    "Skybridge Properties", "Harbour & Co Realty", "Amber Coast Properties", "Pearl Anchor Realty",
    "Cedar Lane Homes", "Ironwood Property Partners", "Silverline Realty", "Summit Gate Properties",
    "Tidewater Estates", "Golden Dune Realty", "Lotus Grove Properties", "Redstone Real Estate",
]


class Agent:
    def __init__(self, agent_id: str, name: str, join: date, weight: float, focus: set[str]):
        self.agent_id = agent_id
        self.name = name
        self.join = join
        self.weight = weight
        self.focus = focus
        # (effective_from, agency_name, is_verified), oldest first
        self.versions: list[tuple[date, str, bool]] = []


def rand_date(rng: random.Random, lo: date, hi: date) -> date:
    return lo + timedelta(days=rng.randint(0, (hi - lo).days))


def build_agents(rng: random.Random) -> list[Agent]:
    communities = sorted({loc.community for loc in LOCATIONS})
    used_names: set[str] = set()
    agents = []
    for i in range(1, N_AGENTS + 1):
        while True:
            name = f"{rng.choice(FIRST_NAMES)} {rng.choice(LAST_NAMES)}"
            if name not in used_names:
                used_names.add(name)
                break
        if rng.random() < 0.70:
            join = rand_date(rng, date(2022, 1, 1), date(2024, 12, 31))
        else:
            join = rand_date(rng, DATA_START, date(2026, 6, 30))
        agent = Agent(
            f"AGT-{i:03d}", name, join,
            weight=rng.lognormvariate(0, 0.7),
            focus=set(rng.sample(communities, rng.randint(1, 3))),
        )
        agency = rng.choice(AGENCIES)
        verified = rng.random() < 0.65

        events: list[tuple[date, str]] = []
        if rng.random() < 0.17 and join + timedelta(days=90) <= date(2026, 6, 30):
            events.append((rand_date(rng, max(join + timedelta(days=90), date(2025, 4, 1)), date(2026, 6, 30)), "move"))
        if not verified and rng.random() < 0.6 and join + timedelta(days=30) <= date(2026, 7, 31):
            events.append((rand_date(rng, join + timedelta(days=30), date(2026, 7, 31)), "verify"))
        events = [e for e in events if e[0] > join]
        events.sort()

        agent.versions.append((join, agency, verified))
        for when, kind in events:
            if kind == "move":
                agency = rng.choice([a for a in AGENCIES if a != agency])
            else:
                verified = True
            if agent.versions[-1][0] == when:  # two changes on the same day -> one version
                agent.versions[-1] = (when, agency, verified)
            else:
                agent.versions.append((when, agency, verified))
        agents.append(agent)
    return agents


def day_weight(d: date) -> float:
    growth = 1 + 0.6 * (d - DATA_START).days / (AS_OF - DATA_START).days
    season = 0.85 if d.month in (6, 7, 8) else 1.0
    weekend = 0.6 if d.weekday() >= 5 else 1.0  # UAE weekend is Sat-Sun
    return growth * season * weekend


def round_to(value: float, step: int) -> int:
    return int(round(value / step) * step)


def generate_listings(rng: random.Random, agents: list[Agent]) -> list[dict]:
    days = [DATA_START + timedelta(days=n) for n in range((AS_OF - DATA_START).days + 1)]
    listed_dates = sorted(rng.choices(days, [day_weight(d) for d in days], k=N_LISTINGS))
    loc_yield = {loc.location_id: TIER_YIELD[loc.market_tier] * rng.uniform(0.92, 1.08) for loc in LOCATIONS}
    span_months = (AS_OF - DATA_START).days / 30.4

    rows = []
    for n, listed in enumerate(listed_dates, start=1):
        loc = rng.choices(LOCATIONS, [l.weight for l in LOCATIONS])[0]
        ptype = rng.choices(list(loc.type_mix), list(loc.type_mix.values()))[0]
        beds_table = BEDROOMS[ptype]
        beds = rng.choices(list(beds_table), [v[0] for v in beds_table.values()])[0]
        _, lo, hi = beds_table[beds]
        size = round_to(rng.uniform(lo, hi), 5)
        purpose = "SALE" if rng.random() < 0.55 else "RENT"

        # z > 0 means priced above the market for this segment
        z = rng.gauss(0, 1)
        bed_adj = APT_BED_ADJ[beds] if ptype == "Apartment" else 1 - 0.03 * (beds - 4)
        trend = 1 + 0.004 * ((listed - DATA_START).days / 30.4)
        market_value = loc.base_ppsf * TYPE_PPSF[ptype] * bed_adj * trend * size
        if purpose == "SALE":
            step = 5000
            initial = round_to(market_value * math.exp(0.10 * z), step)
        else:
            step = 1000
            landed_adj = 0.85 if ptype in ("Villa", "Townhouse") else 1.0
            initial = round_to(market_value * loc_yield[loc.location_id] * landed_adj * math.exp(0.10 * z + 0.05 * rng.gauss(0, 1)), step)

        # lifecycle: overpriced listings stay up longer
        median_days = 28 if purpose == "RENT" else 70
        lifetime = max(1, min(365, round(rng.lognormvariate(math.log(median_days), 0.85) * math.exp(0.35 * z))))
        removal = listed + timedelta(days=lifetime)
        if removal > AS_OF:
            status, removed, end = "ACTIVE", None, AS_OF
        else:
            status = "EXPIRED" if rng.random() < 0.25 else "REMOVED"
            removed, end = removal, removal
        observed_days = (end - listed).days

        # price cuts happen while the listing is up
        current, cuts = initial, 0
        max_cuts = min(3, observed_days // 21)
        p_cut = min(0.7, max(0.05, 0.25 + 0.25 * z))
        while cuts < max_cuts and rng.random() < (p_cut if cuts == 0 else 0.4):
            cut_price = round_to(current * (1 - rng.uniform(0.02, 0.08)), step)
            if cut_price >= current:
                break
            current, cuts = cut_price, cuts + 1

        first_possible = min(listed + timedelta(days=cuts), end)
        last_updated = first_possible + timedelta(days=rng.randint(0, (end - first_possible).days))

        traffic = 9.0 * TIER_TRAFFIC[loc.market_tier] * (1.25 if purpose == "RENT" else 1.0)
        views = max(0, round(traffic * math.exp(-0.30 * z + rng.gauss(0, 0.3)) * (observed_days + 1) ** 0.9))
        conversion = min(0.06, max(0.004, 0.022 * math.exp(-0.25 * z) * rng.uniform(0.7, 1.3)))
        leads = round(views * conversion)

        eligible = [a for a in agents if a.join <= listed]
        agent = rng.choices(eligible, [a.weight * (6 if loc.community in a.focus else 1) for a in eligible])[0]

        rows.append({
            "listing_id": f"LST-{n:06d}",
            "agent_id": agent.agent_id,
            "location_id": loc.location_id,
            "property_type": ptype,
            "bedrooms": beds,
            "purpose": purpose,
            "size_sqft": size,
            "initial_price_aed": initial,
            "current_price_aed": current,
            "price_change_count": cuts,
            "listed_date": listed.isoformat(),
            "last_updated_date": last_updated.isoformat(),
            "removed_date": removed.isoformat() if removed else "",
            "listing_status": status,
            "view_count": views,
            "lead_count": leads,
        })

    # inject the known-dirty rows
    dirty = rng.sample(range(len(rows)), N_UNKNOWN_LOCATION + N_ZERO_SIZE)
    for idx in dirty[:N_UNKNOWN_LOCATION]:
        rows[idx]["location_id"] = "LOC-999"
    for idx in dirty[N_UNKNOWN_LOCATION:]:
        rows[idx]["size_sqft"] = 0
    return rows


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {path.relative_to(Path(__file__).parent.parent)} ({len(rows)} rows)")


def main() -> None:
    rng = random.Random(SEED)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    agents = build_agents(rng)
    listings = generate_listings(rng, agents)

    location_columns = ["location_id", "emirate", "city", "community", "sub_community", "market_tier"]
    write_csv(
        OUT_DIR / "locations.csv",
        location_columns,
        [{col: getattr(loc, col) for col in location_columns} for loc in LOCATIONS],
    )
    history = [
        {
            "agent_id": a.agent_id,
            "agent_name": a.name,
            "agency_name": agency,
            "is_verified": str(verified).lower(),
            "effective_from": eff.isoformat(),
        }
        for a in agents
        for eff, agency, verified in a.versions
    ]
    write_csv(
        OUT_DIR / "agent_history.csv",
        ["agent_id", "agent_name", "agency_name", "is_verified", "effective_from"],
        history,
    )
    write_csv(OUT_DIR / "listings.csv", list(listings[0]), listings)


if __name__ == "__main__":
    main()
