-- sql/03_ownership_analysis.sql
-- Explore PAD-US land ownership polygons and join with non-obscured mushroom observations.

-- 1. Count land ownership polygon features by Manager Type and Agency Name
SELECT
    mang_type,
    mang_name,
    COUNT(*) AS parcel_count
FROM land_ownership
GROUP BY mang_type, mang_name
ORDER BY parcel_count DESC;

-- 2. Spatial Join: Mushroom sightings (non-obscured) by Land Manager Type & Agency
SELECT
    COALESCE(l.mang_type, 'PRIVATE / UNPROTECTED') AS owner_type,
    COALESCE(l.mang_name, 'Private / Unmapped') AS agency_code,
    COUNT(DISTINCT o.inaturalist_id) AS mushroom_sightings
FROM observations o
LEFT JOIN land_ownership l
    ON ST_Intersects(o.geom, l.geom)
WHERE o.obscured = false
GROUP BY owner_type, agency_code
ORDER BY mushroom_sightings DESC;

-- 3. Top named public land units (parks, state forest tracts, national forest) for mushroom sightings
SELECT
    l.mang_name AS agency,
    l.unit_nm AS land_unit_name,
    l.pub_access AS access_code,
    COUNT(DISTINCT o.inaturalist_id) AS mushroom_sightings
FROM observations o
JOIN land_ownership l
    ON ST_Intersects(o.geom, l.geom)
WHERE o.obscured = false
GROUP BY l.mang_name, l.unit_nm, l.pub_access
ORDER BY mushroom_sightings DESC
LIMIT 15;
