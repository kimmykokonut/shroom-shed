-- 01_extensions.sql
-- Runs automatically when the container initializes the database for the first time.

-- 1. Core PostGIS extension: adds `geometry` and `geography` types,
-- spatial indexes (GIST), and vector functions (ST_Intersects, ST_Within, ST_Buffer, etc.)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. PostGIS Raster extension: separated from core PostGIS starting in v3.0+.
-- Adds the `raster` type and functions like ST_Value, ST_Slope, ST_Aspect, and ST_Clip.
CREATE EXTENSION IF NOT EXISTS postgis_raster;
