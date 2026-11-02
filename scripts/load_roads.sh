#!/usr/bin/env bash
# scripts/load_roads.sh
# Uses containerized GDAL (`ogr2ogr`) to load:
#   1. `forest_roads` (MultiLineString, EPSG:4326): Public State Highways, County Roads,
#      ODF/BLM Mainlines & Collectors, and USFS MVUM Roads (excluding private timber roads)
#   2. `trailheads` (Point, EPSG:4326): Official State Forest Trailheads, Day-Use Parking, & Campgrounds

set -euo pipefail

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

echo "1/4 Loading data/mvum_tillamook.geojson via ogr2ogr..."
docker compose run --rm gdal ogr2ogr \
  -f "PostgreSQL" "PG:host=localhost port=5432 dbname=${POSTGRES_DB} user=${POSTGRES_USER} password=${POSTGRES_PASSWORD}" \
  /data/mvum_tillamook.geojson \
  -nln mvum_roads_raw \
  -nlt PROMOTE_TO_MULTI \
  -lco GEOMETRY_NAME=geom \
  -overwrite

echo "2/4 Loading data/odf_roads_tillamook.geojson via ogr2ogr..."
docker compose run --rm gdal ogr2ogr \
  -f "PostgreSQL" "PG:host=localhost port=5432 dbname=${POSTGRES_DB} user=${POSTGRES_USER} password=${POSTGRES_PASSWORD}" \
  /data/odf_roads_tillamook.geojson \
  -nln odf_roads_raw \
  -nlt PROMOTE_TO_MULTI \
  -lco GEOMETRY_NAME=geom \
  -overwrite

echo "3/4 Loading data/trailheads_tillamook.geojson via ogr2ogr..."
docker compose run --rm gdal ogr2ogr \
  -f "PostgreSQL" "PG:host=localhost port=5432 dbname=${POSTGRES_DB} user=${POSTGRES_USER} password=${POSTGRES_PASSWORD}" \
  /data/trailheads_tillamook.geojson \
  -nln trailheads_raw \
  -lco GEOMETRY_NAME=geom \
  -overwrite

echo "4/4 Building unified 'forest_roads' and 'trailheads' tables with GIST indexes..."
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" <<'SQL'
DROP TABLE IF EXISTS forest_roads;

CREATE TABLE forest_roads (
    id SERIAL PRIMARY KEY,
    source TEXT NOT NULL,
    agency TEXT,
    road_class TEXT,
    road_num TEXT,
    road_name TEXT,
    surface TEXT,
    vehicle_access TEXT,
    seasonal TEXT,
    geom GEOMETRY(MultiLineString, 4326) NOT NULL
);

INSERT INTO forest_roads (source, agency, road_class, road_num, road_name, surface, vehicle_access, seasonal, geom)
SELECT
    'USFS MVUM' AS source,
    'USFS' AS agency,
    'USFS MVUM Road' AS road_class,
    NULLIF(TRIM(id), '') AS road_num,
    COALESCE(NULLIF(TRIM(name), ''), 'FS Road ' || id) AS road_name,
    surfacetype AS surface,
    mvum_symbol_name AS vehicle_access,
    seasonal,
    ST_Multi(geom) AS geom
FROM mvum_roads_raw
WHERE geom IS NOT NULL;

INSERT INTO forest_roads (source, agency, road_class, road_num, road_name, surface, vehicle_access, seasonal, geom)
SELECT
    'ODF North Coast' AS source,
    COALESCE(NULLIF(TRIM(ownership), ''), 'ODF') AS agency,
    CASE TRIM(class)
        WHEN 'A' THEN 'Arterial / State Highway'
        WHEN 'P' THEN 'Paved County / Park Road'
        WHEN 'M' THEN 'Mainline Forest Road'
        WHEN 'C' THEN 'Collector Forest Road'
        ELSE 'Public Forest Road'
    END AS road_class,
    NULLIF(TRIM(road_num), '') AS road_num,
    COALESCE(
        NULLIF(TRIM(official_n), ''),
        NULLIF(TRIM(alt_name), ''),
        NULLIF(TRIM(road_num), ''),
        CASE TRIM(ownership)
            WHEN 'CNTY'  THEN 'County Road'
            WHEN 'STATE' THEN 'State Highway'
            ELSE 'State Forest Road'
        END
    ) AS road_name,
    surface,
    'Open Surfaced Public Road' AS vehicle_access,
    'yearlong' AS seasonal,
    ST_Multi(geom) AS geom
FROM odf_roads_raw
WHERE geom IS NOT NULL;

DROP TABLE mvum_roads_raw;
DROP TABLE odf_roads_raw;

CREATE INDEX idx_forest_roads_geom
    ON forest_roads
    USING GIST (geom);

DROP TABLE IF EXISTS trailheads;

CREATE TABLE trailheads AS
SELECT
    ogc_fid AS id,
    TRIM(title) AS site_name,
    TRIM(state_forest) AS forest_name,
    TRIM(layer_name) AS site_type,
    TRIM(activities) AS activities,
    TRIM(amenities) AS amenities,
    TRIM(season) AS season,
    TRIM(recreationsitesstatus) AS status,
    geom::geometry(Point, 4326) AS geom
FROM trailheads_raw
WHERE geom IS NOT NULL;

ALTER TABLE trailheads ADD PRIMARY KEY (id);

CREATE INDEX idx_trailheads_geom
    ON trailheads
    USING GIST (geom);

DROP TABLE trailheads_raw;
SQL

echo "Done! Tables 'forest_roads' and 'trailheads' are ready."
