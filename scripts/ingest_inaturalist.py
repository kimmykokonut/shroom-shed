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
# - taxon_id = 47170  -> Kingdom Fungi (all mushrooms)
# - place_id = 494    -> Tillamook County, OR, US
# - verifiable = true -> Must have coordinates, date, and not be captive/cultivated
TAXON_ID_FUNGI = 47170
PLACE_ID_TILLAMOOK = 494

# How many pages to fetch (200 observations per page).
# 10 pages = up to 2,000 most recent observations (fast & polite to iNat's rate limit).
MAX_PAGES = 10
PER_PAGE = 200

# Raw SQL statement:
# Notice how the 8th value uses PostGIS functions right inside the INSERT:
# ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
# And ON CONFLICT (inaturalist_id) DO NOTHING safely skips duplicates if re-run!
INSERT_SQL = """
INSERT INTO observations (
    inaturalist_id,
    taxon_id,
    species_name,
    common_name,
    observed_date,
    quality_grade,
    positional_accuracy_m,
    geom
)
VALUES (
    %s, %s, %s, %s, %s, %s, %s,
    ST_SetSRID(ST_MakePoint(%s, %s), 4326)
)
ON CONFLICT (inaturalist_id) DO NOTHING;
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
        "taxon_id": TAXON_ID_FUNGI,
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

    return (
        int(item["id"]),
        int(taxon["id"]),
        taxon.get("name", "Unknown Fungi"),
        taxon.get("preferred_common_name"),
        observed_date,
        item.get("quality_grade"),
        item.get("positional_accuracy"),
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

                # Be polite to iNaturalist's public API (~1 request per second)
                if page < MAX_PAGES:
                    time.sleep(1.0)

            # Query total row count in the table after ingestion
            cur.execute("SELECT COUNT(*) FROM observations;")
            db_count = cur.fetchone()[0]
            print(f"\nDone! Total rows currently in `observations` table: {db_count}")


if __name__ == "__main__":
    main()
