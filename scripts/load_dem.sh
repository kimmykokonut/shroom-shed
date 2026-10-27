#!/usr/bin/env bash
# scripts/load_dem.sh
# Loads data/dem_tillamook_32610.tif into PostGIS table `elevation_raster`
# using PostGIS's built-in SQL functions:
#   1. SET postgis.gdal_enabled_drivers = 'ENABLE_ALL'     -> enables GeoTIFF reading in PostGIS
#   2. pg_read_binary_file('/data/dem_tillamook_32610.tif') -> reads the GeoTIFF file
#   3. ST_FromGDALRaster(...)                               -> parses it into a PostGIS raster
#   4. ST_Tile(rast, 100, 100)                              -> chops the 2000x2800 grid into
#                                                              560 small 100x100 pixel tiles

set -euo pipefail

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

echo "Loading and tiling data/dem_tillamook_32610.tif into PostGIS table 'elevation_raster'..."

docker compose exec -T db psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" <<'SQL'
SET postgis.gdal_enabled_drivers = 'ENABLE_ALL';

DROP TABLE IF EXISTS elevation_raster;

CREATE TABLE elevation_raster AS
WITH tiled_dem AS (
    SELECT ST_Tile(
        ST_SetSRID(
            ST_FromGDALRaster(pg_read_binary_file('/data/dem_tillamook_32610.tif')),
            32610
        ),
        100,
        100
    ) AS rast
)
SELECT
    ROW_NUMBER() OVER ()::integer AS rid,
    rast
FROM tiled_dem;

ALTER TABLE elevation_raster ADD PRIMARY KEY (rid);

CREATE INDEX idx_elevation_raster_convexhull
    ON elevation_raster
    USING GIST (ST_ConvexHull(rast));
SQL

echo "Done! Table 'elevation_raster' is ready."
