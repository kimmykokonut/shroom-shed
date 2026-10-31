#!/usr/bin/env bash
# scripts/load_trees.sh
# Loads and tiles all three 30m forest/vegetation GeoTIFFs into PostGIS raster tables:
#   1. data/canopy_tillamook_32610.tif      -> `canopy_raster` (0-100% tree canopy cover)
#   2. data/landcover_tillamook_32610.tif   -> `landcover_raster` (NLCD land cover class)
#   3. data/forest_type_tillamook_32610.tif -> `forest_type_raster` (USFS FIA dominant tree group)
#
# Each 2000x2800 GeoTIFF is chopped into 560 small 100x100 pixel tiles in EPSG:32610
# and indexed with a GIST spatial index on ST_ConvexHull(rast).

set -euo pipefail

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

echo "Loading and tiling canopy, landcover, and forest_type rasters into PostGIS..."

docker compose exec -T db psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" <<'SQL'
SET postgis.gdal_enabled_drivers = 'ENABLE_ALL';

DROP TABLE IF EXISTS canopy_raster;
CREATE TABLE canopy_raster AS
WITH tiled AS (
    SELECT ST_Tile(
        ST_SetSRID(
            ST_FromGDALRaster(pg_read_binary_file('/data/canopy_tillamook_32610.tif')),
            32610
        ),
        100,
        100
    ) AS rast
)
SELECT ROW_NUMBER() OVER ()::integer AS rid, rast FROM tiled;
ALTER TABLE canopy_raster ADD PRIMARY KEY (rid);
CREATE INDEX idx_canopy_raster_convexhull ON canopy_raster USING GIST (ST_ConvexHull(rast));

DROP TABLE IF EXISTS landcover_raster;
CREATE TABLE landcover_raster AS
WITH tiled AS (
    SELECT ST_Tile(
        ST_SetSRID(
            ST_FromGDALRaster(pg_read_binary_file('/data/landcover_tillamook_32610.tif')),
            32610
        ),
        100,
        100
    ) AS rast
)
SELECT ROW_NUMBER() OVER ()::integer AS rid, rast FROM tiled;
ALTER TABLE landcover_raster ADD PRIMARY KEY (rid);
CREATE INDEX idx_landcover_raster_convexhull ON landcover_raster USING GIST (ST_ConvexHull(rast));

DROP TABLE IF EXISTS forest_type_raster;
CREATE TABLE forest_type_raster AS
WITH tiled AS (
    SELECT ST_Tile(
        ST_SetSRID(
            ST_FromGDALRaster(pg_read_binary_file('/data/forest_type_tillamook_32610.tif')),
            32610
        ),
        100,
        100
    ) AS rast
)
SELECT ROW_NUMBER() OVER ()::integer AS rid, rast FROM tiled;
ALTER TABLE forest_type_raster ADD PRIMARY KEY (rid);
CREATE INDEX idx_forest_type_raster_convexhull ON forest_type_raster USING GIST (ST_ConvexHull(rast));
SQL

echo "Done! Tables 'canopy_raster', 'landcover_raster', and 'forest_type_raster' are ready."
