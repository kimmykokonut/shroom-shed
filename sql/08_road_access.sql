-- sql/08_road_access.sql
-- Explore `forest_roads` (USFS MVUM + Public State Highways, County Roads, & ODF/BLM Mainlines/Collectors)
-- and `trailheads` (Official ODF State Forest Trailheads, Day-Use Parking, & Campgrounds),
-- and use PostGIS Nearest-Neighbor (`<->`) + `ST_ClosestPoint()` to find drivable road
-- and trailhead entry points for our unexplored mushroom habitat zones.

-- 1. Summary A: Public Road Network by Agency, Road Class, and Total Miles (`ST_Length`)
SELECT
    source,
    agency,
    road_class,
    COUNT(*) AS road_segments,
    ROUND((SUM(ST_Length(ST_Transform(geom, 32610))) / 1609.34)::numeric, 1) AS total_miles
FROM forest_roads
GROUP BY source, agency, road_class
ORDER BY total_miles DESC;

-- 2. Summary B: Official State Forest Trailheads, Day-Use Parking & Campgrounds (`trailheads`)
SELECT
    site_type,
    status,
    COUNT(*) AS site_count,
    MIN(site_name) AS sample_site_1,
    MAX(site_name) AS sample_site_2
FROM trailheads
GROUP BY site_type, status
ORDER BY site_count DESC;

-- 3. Summary C: How far do iNaturalist foragers actually hike from a public road?
-- Uses `CROSS JOIN LATERAL` + the GIST index nearest-neighbor operator (`<->`)
-- to find the closest public road to each accurate mushroom observation!
WITH obs_nearest_road AS (
    SELECT
        o.inaturalist_id,
        o.species_name,
        r.road_class,
        ROUND(
            ST_Distance(
                ST_Transform(o.geom, 32610),
                ST_Transform(r.geom, 32610)
            )::numeric,
            0
        ) AS dist_to_road_m
    FROM observations o
    CROSS JOIN LATERAL (
        SELECT road_class, geom
        FROM forest_roads fr
        ORDER BY fr.geom <-> o.geom
        LIMIT 1
    ) r
    WHERE o.obscured = false
)
SELECT
    CASE
        WHEN dist_to_road_m <= 100  THEN '1. Roadside (< 100m)'
        WHEN dist_to_road_m <= 500  THEN '2. Short Walk (100m - 500m)'
        WHEN dist_to_road_m <= 1500 THEN '3. Moderate Hike (500m - 1.5km)'
        ELSE                             '4. Deep Backcountry (> 1.5km)'
    END AS road_proximity_band,
    COUNT(*) AS sightings,
    ROUND(AVG(dist_to_road_m), 0) AS avg_dist_m
FROM obs_nearest_road
GROUP BY road_proximity_band
ORDER BY road_proximity_band;

-- 4. Summary D: Unexplored Mushroom Habitat Zones WITH Public Road & Trailhead Entry Points!
-- Combines our 4 habitat layers with `forest_roads` and `trailheads` using `<->` and `ST_ClosestPoint()`
-- to drop a pin on the exact roadside pull-off AND nearest trailhead/campground!
WITH tile_habitat AS MATERIALIZED (
    SELECT
        e.rid AS tile_id,
        ROUND((ST_SummaryStats(e.rast)).mean::numeric, 0) AS avg_elev_m,
        ROUND((ST_SummaryStats(s.rast)).mean::numeric, 1) AS avg_slope_deg,
        ROUND(ST_Value(a.rast, 50, 50)::numeric, 0) AS center_aspect_deg,
        ROUND((ST_SummaryStats(c.rast)).mean::numeric, 0) AS avg_canopy_pct,
        CASE ST_Value(f.rast, 50, 50)
            WHEN 200 THEN 'Douglas-fir'
            WHEN 300 THEN 'Western Hemlock / Sitka Spruce'
            WHEN 910 THEN 'Red Alder / Bigleaf Maple'
            WHEN 280 THEN 'Shore Pine / Lodgepole Pine'
            WHEN 260 THEN 'True Fir / Mountain Hemlock'
            ELSE 'Mixed / Other Forest'
        END AS dominant_trees,
        ST_Transform(ST_ConvexHull(e.rast), 4326) AS tile_geom_4326,
        ST_Centroid(ST_ConvexHull(e.rast)) AS tile_center_32610
    FROM elevation_raster e
    JOIN slope_raster s ON e.rid = s.rid
    JOIN aspect_raster a ON e.rid = a.rid
    JOIN canopy_raster c ON e.rid = c.rid
    JOIN forest_type_raster f ON e.rid = f.rid
),
unexplored_habitat_tiles AS MATERIALIZED (
    SELECT *
    FROM tile_habitat t
    WHERE avg_elev_m BETWEEN 150 AND 450
      AND avg_slope_deg BETWEEN 8.0 AND 22.0
      AND center_aspect_deg NOT BETWEEN 150 AND 210
      AND avg_canopy_pct >= 70
      AND dominant_trees IN ('Douglas-fir', 'Western Hemlock / Sitka Spruce')
      AND NOT EXISTS (
          SELECT 1
          FROM observations o
          WHERE o.obscured = false
            AND ST_DWithin(
                ST_Transform(o.geom, 32610),
                t.tile_center_32610,
                2000
            )
      )
),
matched_public_lands AS MATERIALIZED (
    SELECT DISTINCT ON (t.tile_id)
        t.tile_id,
        l.mang_name AS agency,
        l.unit_nm AS forest_unit,
        t.dominant_trees,
        t.avg_canopy_pct,
        t.avg_elev_m,
        t.avg_slope_deg,
        t.tile_geom_4326,
        ST_Centroid(t.tile_geom_4326) AS zone_center_4326,
        t.tile_center_32610
    FROM unexplored_habitat_tiles t
    JOIN land_ownership l
        ON ST_Intersects(ST_Centroid(t.tile_geom_4326), l.geom)
    WHERE l.mang_name IN ('SLB', 'USFS', 'BLM')
      AND l.pub_access = 'OA'
    ORDER BY t.tile_id, ST_Area(l.geom) DESC
)
SELECT
    p.tile_id,
    p.agency,
    p.dominant_trees,
    p.avg_canopy_pct AS canopy_pct,
    p.avg_elev_m AS elev_m,
    p.avg_slope_deg AS slope_deg,
    nr.road_name AS nearest_road,
    nr.road_class,
    ROUND(
        ST_Distance(
            p.tile_center_32610,
            ST_Transform(nr.geom, 32610)
        )::numeric,
        0
    ) AS hike_from_road_m,
    ROUND(ST_Y(ST_ClosestPoint(nr.geom, p.zone_center_4326))::numeric, 4) AS road_entry_lat,
    ROUND(ST_X(ST_ClosestPoint(nr.geom, p.zone_center_4326))::numeric, 4) AS road_entry_lon,
    nt.site_name AS nearest_trailhead,
    ROUND(
        (ST_Distance(p.tile_center_32610, ST_Transform(nt.geom, 32610)) / 1000.0)::numeric,
        1
    ) AS trailhead_dist_km,
    p.tile_geom_4326 AS search_zone_geom
FROM matched_public_lands p
CROSS JOIN LATERAL (
    SELECT road_name, road_class, geom
    FROM forest_roads r
    ORDER BY r.geom <-> p.zone_center_4326
    LIMIT 1
) nr
CROSS JOIN LATERAL (
    SELECT site_name, geom
    FROM trailheads th
    WHERE th.status = 'Open'
    ORDER BY th.geom <-> p.zone_center_4326
    LIMIT 1
) nt
WHERE ST_Distance(p.tile_center_32610, ST_Transform(nr.geom, 32610)) <= 1500
ORDER BY hike_from_road_m ASC, p.avg_canopy_pct DESC
LIMIT 15;
