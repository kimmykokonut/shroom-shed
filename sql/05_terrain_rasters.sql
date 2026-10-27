-- sql/05_terrain_rasters.sql
-- Phase 5: Inspect the USGS 3DEP DEM raster (`elevation_raster`) and derive
-- `slope_raster` (degrees steepness) and `aspect_raster` (compass direction 0-360°).

-- 1. Inspect how raster2pgsql tiled the 2000x2800 DEM into 100x100 pixel rows
SELECT
    COUNT(*) AS total_tiles,
    ST_Width(rast) AS tile_width_px,
    ST_Height(rast) AS tile_height_px,
    ST_SRID(rast) AS srid,
    ROUND(ST_ScaleX(rast)::numeric, 2) AS pixel_width_meters,
    ROUND(ST_ScaleY(rast)::numeric, 2) AS pixel_height_meters
FROM elevation_raster
GROUP BY tile_width_px, tile_height_px, srid, pixel_width_meters, pixel_height_meters;

-- 2. Derive `slope_raster` (hillside steepness in degrees: 0° = flat, 90° = vertical cliff)
DROP TABLE IF EXISTS slope_raster;
CREATE TABLE slope_raster AS
SELECT
    rid,
    ST_Slope(rast, 1, '32BF', 'DEGREES') AS rast
FROM elevation_raster;

CREATE INDEX idx_slope_raster_convexhull
    ON slope_raster
    USING GIST (ST_ConvexHull(rast));

-- 3. Derive `aspect_raster` (compass direction hillside faces: 0°=N, 90°=E, 180°=S, 270°=W)
DROP TABLE IF EXISTS aspect_raster;
CREATE TABLE aspect_raster AS
SELECT
    rid,
    ST_Aspect(rast, 1, '32BF', 'DEGREES') AS rast
FROM elevation_raster;

CREATE INDEX idx_aspect_raster_convexhull
    ON aspect_raster
    USING GIST (ST_ConvexHull(rast));
