CREATE TABLE IF NOT EXISTS observations (
    inaturalist_id BIGINT PRIMARY KEY,
    taxon_id INTEGER NOT NULL,
    species_name TEXT NOT NULL,
    common_name TEXT,
    observed_date DATE,
    quality_grade TEXT,
    positional_accuracy_m INTEGER,
    obscured BOOLEAN NOT NULL DEFAULT false,
    inaturalist_url TEXT,
    elevation_m NUMERIC(6,1),
    slope_deg NUMERIC(4,1),
    aspect_deg NUMERIC(5,1),
    aspect_cardinal TEXT,
    canopy_pct SMALLINT,
    landcover_code SMALLINT,
    landcover_type TEXT,
    fia_code SMALLINT,
    tree_group TEXT,
    geom GEOMETRY(Point, 4326) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_observations_geom
    ON observations
    USING GIST (geom);
