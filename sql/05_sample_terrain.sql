-- sql/05_sample_terrain.sql
-- Sample elevation, slope, and aspect at each non-obscured observation point
-- using ST_Value(), and analyze terrain distributions where sightings cluster.

-- 1. Add terrain columns to `observations`
ALTER TABLE observations ADD COLUMN IF NOT EXISTS elevation_m NUMERIC(6,1);
ALTER TABLE observations ADD COLUMN IF NOT EXISTS slope_deg NUMERIC(4,1);
ALTER TABLE observations ADD COLUMN IF NOT EXISTS aspect_deg NUMERIC(5,1);
ALTER TABLE observations ADD COLUMN IF NOT EXISTS aspect_cardinal TEXT;

-- 2. Populate elevation_m, slope_deg, and aspect_deg from our 3 raster tables
-- for all accurate (non-obscured) observations
UPDATE observations o
SET
    elevation_m = ROUND(ST_Value(e.rast, ST_Transform(o.geom, 32610))::numeric, 1),
    slope_deg   = ROUND(ST_Value(s.rast, ST_Transform(o.geom, 32610))::numeric, 1),
    aspect_deg  = ROUND(ST_Value(a.rast, ST_Transform(o.geom, 32610))::numeric, 1)
FROM elevation_raster e
JOIN slope_raster s ON e.rid = s.rid
JOIN aspect_raster a ON e.rid = a.rid
WHERE o.obscured = false
  AND ST_Intersects(e.rast, ST_Transform(o.geom, 32610));

-- 3. Convert aspect_deg (0-360 degrees) into 8 compass directions (N, NE, E, SE, S, SW, W, NW)
UPDATE observations
SET aspect_cardinal = CASE
    WHEN aspect_deg IS NULL THEN NULL
    WHEN aspect_deg < 0 OR slope_deg = 0 THEN 'FLAT'
    WHEN aspect_deg >= 337.5 OR aspect_deg < 22.5  THEN 'N'
    WHEN aspect_deg >= 22.5  AND aspect_deg < 67.5  THEN 'NE'
    WHEN aspect_deg >= 67.5  AND aspect_deg < 112.5 THEN 'E'
    WHEN aspect_deg >= 112.5 AND aspect_deg < 157.5 THEN 'SE'
    WHEN aspect_deg >= 157.5 AND aspect_deg < 202.5 THEN 'S'
    WHEN aspect_deg >= 202.5 AND aspect_deg < 247.5 THEN 'SW'
    WHEN aspect_deg >= 247.5 AND aspect_deg < 292.5 THEN 'W'
    WHEN aspect_deg >= 292.5 AND aspect_deg < 337.5 THEN 'NW'
END
WHERE obscured = false;

-- 4. Summary A: Sightings by Compass Aspect Direction (Which way does the hillside face?)
SELECT
    aspect_cardinal,
    COUNT(*) AS sightings,
    ROUND(AVG(elevation_m), 1) AS avg_elevation_m,
    ROUND(AVG(slope_deg), 1) AS avg_slope_deg
FROM observations
WHERE obscured = false AND aspect_cardinal IS NOT NULL
GROUP BY aspect_cardinal
ORDER BY sightings DESC;

-- 5. Summary B: Sightings by Elevation Band (Meters above sea level)
SELECT
    CASE
        WHEN elevation_m < 50  THEN '1. Coastal / Lowland (0 - 50m)'
        WHEN elevation_m < 200 THEN '2. Lower Foothills / River Valleys (50 - 200m)'
        WHEN elevation_m < 500 THEN '3. Mid-Elevation Forest (200 - 500m)'
        ELSE                        '4. High Ridges & Peaks (500m+)'
    END AS elevation_band,
    COUNT(*) AS sightings,
    ROUND(AVG(slope_deg), 1) AS avg_slope_deg
FROM observations
WHERE obscured = false AND elevation_m IS NOT NULL
GROUP BY elevation_band
ORDER BY elevation_band;

-- 6. Summary C: All-Time Species Counts (Including Obscured) + Terrain Profile (From Accurate GPS Only)
-- Note: Because `elevation_m` is NULL on obscured rows, AVG/MIN/MAX automatically
-- use ONLY accurate coordinates, while COUNT(*) includes obscured sightings!
SELECT
    species_name,
    common_name,
    COUNT(*) AS total_sightings,
    COUNT(*) FILTER (WHERE obscured = true) AS obscured_count,
    COUNT(*) FILTER (WHERE obscured = false) AS accurate_count,
    ROUND(AVG(elevation_m), 0) AS avg_elev_m,
    ROUND(AVG(slope_deg), 1) AS avg_slope_deg,
    MODE() WITHIN GROUP (ORDER BY aspect_cardinal) AS most_common_aspect
FROM observations
GROUP BY species_name, common_name
ORDER BY total_sightings DESC
LIMIT 20;

-- 7. Summary D: Active Fruiting Window (Last 10 Days)
SELECT
    species_name,
    common_name,
    COUNT(*) AS total_last_10d,
    COUNT(*) FILTER (WHERE obscured = false) AS accurate_last_10d,
    ROUND(AVG(elevation_m), 0) AS active_avg_elev_m,
    ROUND(AVG(slope_deg), 1) AS active_avg_slope_deg,
    MODE() WITHIN GROUP (ORDER BY aspect_cardinal) AS active_aspect
FROM observations
WHERE observed_date >= CURRENT_DATE - INTERVAL '10 days'
GROUP BY species_name, common_name
ORDER BY total_last_10d DESC;
