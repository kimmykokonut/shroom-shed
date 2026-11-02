-- sql/09_tileserv_layers.sql
-- Prepare clean, indexed PostGIS Views and Materialized Views for `pg_tileserv` (http://localhost:7800):
--   1. `accurate_observations` (VIEW): Non-obscured mushroom sightings with full terrain & tree attributes
--   2. `recommended_search_areas` (MATERIALIZED VIEW): Formulated 3km x 3km unexplored public forest rectangles to search (Polygon, 4326)
--   3. `search_area_parking_pins` (MATERIALIZED VIEW): Exact roadside pull-off pins for each recommended search area (Point, 4326)
--   4. `COMMENT ON` metadata: Automatically displayed as layer descriptions inside the pg_tileserv Web UI!

-- Clean up any previous view names
DROP MATERIALIZED VIEW IF EXISTS road_entry_points;
DROP MATERIALIZED VIEW IF EXISTS habitat_zones;
DROP MATERIALIZED VIEW IF EXISTS recommended_spot_parking;
DROP MATERIALIZED VIEW IF EXISTS recommended_search_spots;
DROP MATERIALIZED VIEW IF EXISTS search_area_parking_pins;
DROP MATERIALIZED VIEW IF EXISTS recommended_search_areas;
DROP VIEW IF EXISTS accurate_observations;

-- 1. View of accurate (non-obscured) mushroom sightings for clean map display
CREATE VIEW accurate_observations AS
SELECT
    inaturalist_id,
    species_name,
    common_name,
    observed_date,
    elevation_m,
    slope_deg,
    aspect_cardinal,
    canopy_pct,
    landcover_type,
    tree_group,
    inaturalist_url,
    geom::geometry(Point, 4326) AS geom
FROM observations
WHERE obscured = false;

-- 2. Materialized View of Formulated Search Areas (`recommended_search_areas`)
-- Cached on disk with a GIST index so pg_tileserv serves vector tiles in <2ms as you pan and zoom!
CREATE MATERIALIZED VIEW recommended_search_areas AS
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
        t.center_aspect_deg,
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
    p.forest_unit,
    p.dominant_trees,
    p.avg_canopy_pct AS canopy_pct,
    p.avg_elev_m AS elev_m,
    p.avg_slope_deg AS slope_deg,
    p.center_aspect_deg AS aspect_deg,
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
    p.tile_geom_4326::geometry(Polygon, 4326) AS geom
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
WHERE ST_Distance(p.tile_center_32610, ST_Transform(nr.geom, 32610)) <= 1500;

CREATE UNIQUE INDEX idx_recommended_search_areas_tile_id ON recommended_search_areas (tile_id);
CREATE INDEX idx_recommended_search_areas_geom ON recommended_search_areas USING GIST (geom);

-- 3. Materialized View of Roadside Parking Pull-Off Pins (`search_area_parking_pins`)
CREATE MATERIALIZED VIEW search_area_parking_pins AS
SELECT
    tile_id,
    agency,
    dominant_trees,
    canopy_pct,
    elev_m,
    nearest_road,
    road_class,
    hike_from_road_m,
    nearest_trailhead,
    ST_SetSRID(ST_MakePoint(road_entry_lon, road_entry_lat), 4326)::geometry(Point, 4326) AS geom
FROM recommended_search_areas;

CREATE UNIQUE INDEX idx_search_area_parking_pins_tile_id ON search_area_parking_pins (tile_id);
CREATE INDEX idx_search_area_parking_pins_geom ON search_area_parking_pins USING GIST (geom);

-- 4. Dynamically stamp live row counts into table/view descriptions
-- (pg_tileserv automatically displays these COMMENT ON strings in its UI at http://localhost:7800!)
DO $$
BEGIN
    EXECUTE format(
        'COMMENT ON TABLE observations IS %L',
        format('All %s iNaturalist mushroom observations in Tillamook County (including obscured coordinates)', (SELECT COUNT(*) FROM observations))
    );
    EXECUTE format(
        'COMMENT ON VIEW accurate_observations IS %L',
        format('%s non-obscured mushroom sightings with elevation, slope, aspect, canopy %%, and dominant tree host', (SELECT COUNT(*) FROM accurate_observations))
    );
    EXECUTE format(
        'COMMENT ON TABLE land_ownership IS %L',
        format('%s USGS PAD-US 3.0 public land ownership polygons (Tillamook State Forest, Siuslaw National Forest, BLM, State Parks)', (SELECT COUNT(*) FROM land_ownership))
    );
    EXECUTE format(
        'COMMENT ON TABLE forest_roads IS %L',
        format('%s public drivable road segments (USFS MVUM, ODF State Forest, BLM, County Roads, and State Highways)', (SELECT COUNT(*) FROM forest_roads))
    );
    EXECUTE format(
        'COMMENT ON TABLE trailheads IS %L',
        format('%s official ODF State Forest trailheads, day-use parking areas, and campgrounds', (SELECT COUNT(*) FROM trailheads))
    );
    EXECUTE format(
        'COMMENT ON MATERIALIZED VIEW recommended_search_areas IS %L',
        format('%s formulated unexplored public forest rectangles (3km x 3km areas) to search based on existing mushroom sighting terrain, canopy (>=70%%), and host trees', (SELECT COUNT(*) FROM recommended_search_areas))
    );
    EXECUTE format(
        'COMMENT ON MATERIALIZED VIEW search_area_parking_pins IS %L',
        format('%s roadside parking/pull-off GPS point pins (ST_ClosestPoint) for each recommended search area', (SELECT COUNT(*) FROM search_area_parking_pins))
    );
END $$;
