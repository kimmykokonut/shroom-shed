CREATE TABLE IF NOT EXISTS observations (
    inaturalist_id BIGINT PRIMARY KEY,
    taxon_id INTEGER NOT NULL,
    species_name TEXT NOT NULL,
    common_name TEXT,
    observed_date DATE,
    quality_grade TEXT,
    positional_accuracy_m INTEGER,
    geom GEOMETRY(Point, 4326) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_observations_geom
    ON observations
    USING GIST (geom);
