-- sql/07_habitat_search.sql
-- Multi-Layer Habitat Discovery Query ("SearchAI" style):
-- Screen all 560 tiles across Tillamook County by combining 4 spatial layers:
--   1. Terrain Rasters (`elevation_raster`, `slope_raster`, `aspect_raster`)
--   2. Forest & Canopy Rasters (`canopy_raster`, `forest_type_raster`)
--   3. Legal Public Foraging Lands (`land_ownership`: SLB State Forest, USFS, BLM with Open Access 'OA')
--   4. Existing iNaturalist Sightings (`observations`: find unexplored zones >= 2 km from any known sighting)

WITH tile_habitat AS MATERIALIZED (
    -- Step 1: Compute average elevation, slope, and tree canopy cover %
    -- for each 100x100 raster tile, plus the center-pixel aspect and USFS dominant tree group.
    -- Note: We use ST_Value(a.rast, 50, 50) for aspect rather than ST_SummaryStats(a.rast).mean
    -- because averaging circular 0-360° compass angles across both sides of a ridge averages to ~180°!
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
    -- Step 2: Filter for tiles in the Chanterelle / Forest Bolete ecological sweet spot:
    --   - Elevation:    150m to 450m above sea level
    --   - Slope:        8° to 22° moderate, well-drained hillsides
    --   - Aspect:       Avoid hot/dry due-South slopes (150° to 210°)
    --   - Canopy Cover: >= 70% closed-canopy mature forest (excludes recent clearcuts!)
    --   - Host Trees:   Douglas-fir or Western Hemlock / Sitka Spruce ectomycorrhizal hosts
    --   - Unexplored:   ZERO existing iNaturalist observations within 2,000 meters (2 km)
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
matched_public_lands AS (
    -- Step 3: Keep only tiles whose center falls inside Open Access ('OA') public forests
    -- where personal mushroom foraging is permitted (SLB = Tillamook State Forest, USFS, BLM)
    SELECT DISTINCT ON (t.tile_id)
        t.tile_id,
        l.mang_name AS agency,
        l.unit_nm AS forest_unit,
        t.dominant_trees,
        t.avg_canopy_pct,
        t.avg_elev_m,
        t.avg_slope_deg,
        t.center_aspect_deg,
        ROUND(ST_Y(ST_Centroid(t.tile_geom_4326))::numeric, 4) AS center_lat,
        ROUND(ST_X(ST_Centroid(t.tile_geom_4326))::numeric, 4) AS center_lon,
        t.tile_geom_4326 AS search_zone_geom
    FROM unexplored_habitat_tiles t
    JOIN land_ownership l
        ON ST_Intersects(ST_Centroid(t.tile_geom_4326), l.geom)
    WHERE l.mang_name IN ('SLB', 'USFS', 'BLM')
      AND l.pub_access = 'OA'
    ORDER BY t.tile_id, ST_Area(l.geom) DESC
)
SELECT *
FROM matched_public_lands
ORDER BY avg_canopy_pct DESC, avg_elev_m DESC
LIMIT 20;
