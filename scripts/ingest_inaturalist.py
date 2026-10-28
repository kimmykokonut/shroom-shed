"""
Fetch Fungi observations for Tillamook County, OR from the iNaturalist API
and insert them into our PostGIS `observations` table using raw SQL.
"""

import os
import time
import requests
import psycopg
from dotenv import load_dotenv

load_dotenv()

# ---------------------------------------------------------------------------
# 1. Configuration
# ---------------------------------------------------------------------------
INAT_API_URL = "https://api.inaturalist.org/v1/observations"

# iNaturalist filter parameters:
# - place_id = 494 -> Tillamook County, OR, US
# - Target Foraging Genera taxon_ids:
#     47348 = Cantharellus (Golden, White & Rainbow Chanterelles)
#     48611 = Craterellus  (Winter / Yellowfoot Chanterelles)
#     48703 = Boletus      (King Boletes / Porcini)
#     48496 = Pleurotus    (Oyster Mushrooms)
#     48422 = Hydnum       (Hedgehog Mushrooms)
#     62484 = Tricholoma   (Matsutake & Knights)
#     63020 = Sparassis    (Cauliflower Mushrooms)
#     49160 = Hericium     (Lion's Mane & Bear's Head)
#     48431 = Laetiporus   (Chicken of the Woods)
#     56830 = Morchella    (True Morels)
TARGET_TAXON_IDS = "47348,48611,48703,48496,48422,62484,63020,49160,48431,56830"
PLACE_ID_TILLAMOOK = 494

# How many pages to fetch (200 observations per page).
# 10 pages = up to 2,000 most recent observations (fast & polite to iNat's rate limit).
MAX_PAGES = 10
PER_PAGE = 200

# Raw SQL statement:
# Notice how the last value uses PostGIS functions right inside the INSERT:
# ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
# And ON CONFLICT ... DO UPDATE (an "UPSERT") updates `obscured` and `inaturalist_url`
# if the row already exists!
INSERT_SQL = """
INSERT INTO observations (
    inaturalist_id,
    taxon_id,
    species_name,
    common_name,
    observed_date,
    quality_grade,
    positional_accuracy_m,
    obscured,
    inaturalist_url,
    geom
)
VALUES (
    %s, %s, %s, %s, %s, %s, %s, %s, %s,
    ST_SetSRID(ST_MakePoint(%s, %s), 4326)
)
ON CONFLICT (inaturalist_id) DO UPDATE SET
    obscured = EXCLUDED.obscured,
    inaturalist_url = EXCLUDED.inaturalist_url;
"""


def get_db_connection():
    """Connect to the PostGIS container using environment variables from .env"""
    return psycopg.connect(
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
    )


def fetch_page(page: int) -> dict:
    """Fetch a single page of up to 200 observations from iNaturalist."""
    params = {
        "taxon_id": TARGET_TAXON_IDS,
        "place_id": PLACE_ID_TILLAMOOK,
        "verifiable": "true",
        "geo": "true",
        "per_page": PER_PAGE,
        "page": page,
        "order_by": "observed_on",
        "order": "desc",
    }
    response = requests.get(
        INAT_API_URL,
        params=params,
        headers={"User-Agent": "shroom-shed-postgis-learning-project/1.0"},
        timeout=30,
    )
    response.raise_for_status()
    return response.json()


def parse_observation(item: dict):
    """
    Extract the fields we want from a single iNaturalist JSON object.
    Returns a tuple matching the %s placeholders in INSERT_SQL, or None if invalid.
    """
    geojson = item.get("geojson")
    taxon = item.get("taxon")
    observed_date = item.get("observed_on")

    # Skip if missing coordinates, taxon info, or a valid YYYY-MM-DD date
    if not geojson or not taxon or not observed_date:
        return None

    coords = geojson.get("coordinates")
    if not coords or len(coords) < 2:
        return None

    # GeoJSON coordinates are ALWAYS [longitude, latitude] -> [X, Y]
    lon, lat = float(coords[0]), float(coords[1])
    obs_id = int(item["id"])
    is_obscured = bool(
        item.get("obscured")
        or item.get("geoprivacy") == "obscured"
        or item.get("taxon_geoprivacy") == "obscured"
    )
    url = item.get("uri") or f"https://www.inaturalist.org/observations/{obs_id}"

    return (
        obs_id,
        int(taxon["id"]),
        taxon.get("name", "Unknown Fungi"),
        taxon.get("preferred_common_name"),
        observed_date,
        item.get("quality_grade"),
        item.get("positional_accuracy"),
        is_obscured,
        url,
        lon,
        lat,
    )


def main():
    print(f"Connecting to PostGIS database...")
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            total_inserted = 0

            for page in range(1, MAX_PAGES + 1):
                print(
                    f"Fetching page {page}/{MAX_PAGES} from iNaturalist (Tillamook County Fungi)..."
                )
                data = fetch_page(page)
                results = data.get("results", [])

                if not results:
                    print("No more results returned from API.")
                    break

                rows_to_insert = []
                for item in results:
                    parsed = parse_observation(item)
                    if parsed is not None:
                        rows_to_insert.append(parsed)

                # Execute the raw SQL INSERT for each observation in this batch
                cur.executemany(INSERT_SQL, rows_to_insert)
                conn.commit()

                total_inserted += len(rows_to_insert)
                print(
                    f"  -> Processed {len(rows_to_insert)} observations (Running total: {total_inserted})"
                )

                # Stop once we reach the final page of results
                if len(results) < PER_PAGE:
                    print("Reached final page of results.")
                    break

                # Be polite to iNaturalist's public API (~1 request per second)
                if page < MAX_PAGES:
                    time.sleep(1.0)

            # Query total row count in the table after ingestion
            cur.execute("SELECT COUNT(*) FROM observations;")
            db_count = cur.fetchone()[0]
            print(f"\nDone! Total rows currently in `observations` table: {db_count}")


if __name__ == "__main__":
    main()
