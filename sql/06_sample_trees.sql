-- sql/06_sample_trees.sql
-- Sample 2024 NLCD Tree Canopy Cover (0-100%), 2024 NLCD Land Cover Class,
-- and USFS FIA Dominant Tree Species Group at each accurate observation point
-- using ST_Value(), and build a complete ecological profile for each mushroom species.

-- 1. Add forest & tree columns to `observations`
ALTER TABLE observations ADD COLUMN IF NOT EXISTS canopy_pct SMALLINT;
ALTER TABLE observations ADD COLUMN IF NOT EXISTS landcover_code SMALLINT;
ALTER TABLE observations ADD COLUMN IF NOT EXISTS landcover_type TEXT;
ALTER TABLE observations ADD COLUMN IF NOT EXISTS fia_code SMALLINT;
ALTER TABLE observations ADD COLUMN IF NOT EXISTS tree_group TEXT;

-- 2. Sample pixel values from canopy_raster, landcover_raster, and forest_type_raster
-- for all accurate (non-obscured) observations.
-- Note: In NLCD Tree Canopy Cover, values 0-100 are valid canopy percentages, while
-- 254 indicates non-processing coastal water pixels (which we map to 0%).
UPDATE observations o
SET
    canopy_pct = CASE
        WHEN ST_Value(c.rast, ST_Transform(o.geom, 32610)) <= 100
        THEN ST_Value(c.rast, ST_Transform(o.geom, 32610))::smallint
        ELSE 0
    END,
    landcover_code = ST_Value(l.rast, ST_Transform(o.geom, 32610))::smallint,
    fia_code       = ST_Value(f.rast, ST_Transform(o.geom, 32610))::smallint
FROM canopy_raster c
JOIN landcover_raster l ON c.rid = l.rid
JOIN forest_type_raster f ON c.rid = f.rid
WHERE o.obscured = false
  AND ST_Intersects(c.rast, ST_Transform(o.geom, 32610));

-- 3. Translate NLCD Land Cover codes and USFS FIA Forest Type Group codes into readable labels
UPDATE observations
SET
    landcover_type = CASE landcover_code
        WHEN 42 THEN 'Evergreen Forest'
        WHEN 43 THEN 'Mixed Conifer/Hardwood Forest'
        WHEN 41 THEN 'Deciduous Hardwood Forest'
        WHEN 52 THEN 'Shrub / Young Clearcut Regen'
        WHEN 90 THEN 'Woody Wetlands / Riparian'
        WHEN 95 THEN 'Herbaceous Wetlands / Marsh'
        WHEN 71 THEN 'Coastal Grassland / Meadow'
        WHEN 81 THEN 'Pasture / Hay'
        WHEN 82 THEN 'Cultivated Crops'
        WHEN 31 THEN 'Coastal Sand Dunes / Beach'
        WHEN 11 THEN 'Open Water / Estuary Edge'
        WHEN 21 THEN 'Developed Open Space (Parks/Roads)'
        WHEN 22 THEN 'Developed Low Intensity'
        WHEN 23 THEN 'Developed Medium Intensity'
        WHEN 24 THEN 'Developed High Intensity'
        ELSE 'Other'
    END,
    tree_group = CASE fia_code
        WHEN 200 THEN 'Douglas-fir'
        WHEN 300 THEN 'Western Hemlock / Sitka Spruce'
        WHEN 910 THEN 'Red Alder / Bigleaf Maple'
        WHEN 280 THEN 'Shore Pine / Lodgepole Pine'
        WHEN 260 THEN 'True Fir / Mountain Hemlock'
        WHEN 700 THEN 'Oregon Ash / Black Cottonwood'
        WHEN 940 THEN 'Tanoak / Laurel'
        WHEN 950 THEN 'Other Western Hardwoods'
        ELSE 'Non-Forested / Coastal Edge'
    END
WHERE obscured = false;

-- 4. Summary A: Sightings by USFS Dominant Tree Species Group
SELECT
    tree_group,
    fia_code,
    COUNT(*) AS sightings,
    ROUND(AVG(canopy_pct), 0) AS avg_canopy_pct,
    ROUND(AVG(elevation_m), 0) AS avg_elev_m,
    ROUND(AVG(slope_deg), 1) AS avg_slope_deg
FROM observations
WHERE obscured = false
GROUP BY tree_group, fia_code
ORDER BY sightings DESC;

-- 5. Summary B: Sightings by NLCD 2024 Land Cover Type
SELECT
    landcover_type,
    landcover_code,
    COUNT(*) AS sightings,
    ROUND(AVG(canopy_pct), 0) AS avg_canopy_pct,
    ROUND(AVG(elevation_m), 0) AS avg_elev_m
FROM observations
WHERE obscured = false
GROUP BY landcover_type, landcover_code
ORDER BY sightings DESC;

-- 6. Summary C: Complete Ecological Profile by Mushroom Species
-- Combines Elevation, Slope, Aspect, Canopy Cover %, Forest Cover, and Dominant Tree Host!
SELECT
    species_name,
    common_name,
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE obscured = false) AS accurate,
    ROUND(AVG(elevation_m), 0) AS elev_m,
    ROUND(AVG(slope_deg), 1) AS slope_deg,
    MODE() WITHIN GROUP (ORDER BY aspect_cardinal) AS aspect,
    ROUND(AVG(canopy_pct), 0) AS canopy_pct,
    MODE() WITHIN GROUP (ORDER BY landcover_type) AS dominant_landcover,
    MODE() WITHIN GROUP (ORDER BY tree_group) FILTER (WHERE fia_code IS NOT NULL) AS dominant_trees
FROM observations
GROUP BY species_name, common_name
ORDER BY total DESC
LIMIT 20;
