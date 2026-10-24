#!/usr/bin/env bash
# scripts/load_padus.sh
# Uses containerized GDAL (`ogr2ogr`) to load data/padus_tillamook.geojson
# into the PostGIS `land_ownership` table as MultiPolygons (EPSG:4326).

set -euo pipefail

# Load database credentials from .env
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

echo "Loading data/padus_tillamook.geojson into PostGIS table 'land_ownership'..."

# Note: Inside the `gdal` container (which shares network_mode: "service:db"),
# PostgreSQL is always on localhost:5432.
docker compose run --rm gdal ogr2ogr \
  -f "PostgreSQL" "PG:host=localhost port=5432 dbname=${POSTGRES_DB} user=${POSTGRES_USER} password=${POSTGRES_PASSWORD}" \
  /data/padus_tillamook.geojson \
  -nln land_ownership \
  -nlt PROMOTE_TO_MULTI \
  -lco GEOMETRY_NAME=geom \
  -lco FID=id \
  -overwrite

echo "Done! Table 'land_ownership' is ready."
