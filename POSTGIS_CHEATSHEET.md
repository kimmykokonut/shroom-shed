# PostGIS & SQL Glossary

_Reference guide for geospatial concepts, indexing structures, PostGIS `ST_\*` functions, and SQL syntax used in **[Shroom Shed](README.md)**.\_

---

## Jump around

- [Core Geospatial Terms](#core-geospatial-terms)
- [Coordinate Reference Systems (SRIDs)](#coordinate-reference-systems-srids)
- [Spatial Indexing (`B-Tree` vs. `GIST` / `R-Tree`)](#spatial-indexing-b-tree-vs-gist--r-tree)
- [PostGIS `ST_*` Function Glossary](#postgis-st_-function-glossary)
  - [Geometry Constructors & Accessors](#geometry-constructors--accessors)
  - [Projections & Coordinate Systems](#projections--coordinate-systems)
  - [Spatial Relationships & Distance (Vector)](#spatial-relationships--distance-vector)
  - [Raster & Terrain Functions](#raster--terrain-functions)
- [SQL Clauses & Keywords](#sql-clauses--keywords)
- [Official Documentation & References](#official-documentation--references)

---

## Core Geospatial Terms

- **[Vector (`GEOMETRY`)](https://postgis.net/docs/manual-3.4/using_postgis_dbmanagement.html#PostGIS_Geometry)**: Discrete map features represented by coordinates (points, lines, polygons).
  - **`Point`**: A single `(X, Y)` coordinate pair (`(Longitude, Latitude)`), used in `observations.geom`.
  - **`Polygon` / `MultiPolygon`**: Closed coordinate rings representing boundary outlines. `MultiPolygon` groups multiple disconnected parcels into a single row (e.g., checkerboard forest tracts in `land_ownership.geom`).
  - **[`EWKB` (Extended Well-Known Binary)](https://postgis.net/docs/manual-3.4/using_postgis_dbmanagement.html#EWKB_EWKT)**: The hexadecimal binary format PostGIS uses to store geometries on disk (e.g., `0101000020E6100000...`).
  - **[`WKT` (Well-Known Text)](https://postgis.net/docs/manual-3.4/using_postgis_dbmanagement.html#OpenGISWKBWKT)**: Human-readable text representation of a geometry returned by `ST_AsText()` (e.g., `POINT(-123.5736 45.5898)`).

- **[Raster (`RASTER`)](https://postgis.net/docs/manual-3.4/using_raster_dataman.html)**: A continuous grid of pixels (cells) where each pixel covers a fixed ground area (~30m × 30m in our dataset) and stores a numeric measurement instead of an RGB color.
  - **`GeoTIFF` (`.tif`)**: A TIFF image file embedded with geographic bounding coordinates and projection metadata.
  - **[`DEM` (Digital Elevation Model)](https://www.usgs.gov/3d-elevation-program)**: A raster grid where each pixel stores bare-earth ground elevation in meters above sea level, derived from USGS airborne LiDAR and calibrated against surveyed USGS ground benchmarks (`elevation_raster`).
  - **`Slope`**: Hillside steepness in degrees from `0°` (flat) to `90°` (vertical cliff), calculated from the elevation change between neighboring DEM pixels (`slope_raster`).
  - **`Aspect`**: Downhill compass direction a slope faces from `0°` to `360°` (`0°/360°` = North, `90°` = East, `180°` = South, `270°` = West, `-1` = flat), calculated from the DEM (`aspect_raster`).
  - **`Tile` (`rid`)**: A small rectangular chunk (e.g., `100×100` pixels) of a larger raster stored as a single database row with an ID (`rid`) so queries only read the local area of interest rather than the entire county raster.

---

## Coordinate Reference Systems (SRIDs)

- **[`SRID` (Spatial Reference System Identifier)](https://postgis.net/docs/manual-3.4/using_postgis_dbmanagement.html#spatial_ref_sys)**: A standard ID number (maintained in the PostGIS `spatial_ref_sys` catalog table) that defines the map projection, coordinate axes, and measurement units of a geometry or raster.
  - **Note on Axis Order**: PostGIS always uses **`(X, Y)` = `(Longitude, Latitude)`** order.
- **[`EPSG:4326` (WGS 84)](https://epsg.io/4326)**: Standard global GPS coordinate system. Coordinates are measured in **angular degrees** (`-180°` to `+180°` longitude, `-90°` to `+90°` latitude) on a 3D spheroid. Used to store `observations.geom` and `land_ownership.geom`.
- **[`EPSG:32610` (WGS 84 / UTM Zone 10N)](https://epsg.io/32610)**: Projected 2D coordinate system for Oregon and Washington centered on the `-123° W` meridian. Coordinates are measured in **flat meters (`1m`)**. Used for distance calculations (`ST_Distance`, `ST_DWithin`) and terrain rasters (`elevation_raster`, `slope_raster`, `aspect_raster`).

---

## Spatial Indexing (`B-Tree` vs. `GIST` / `R-Tree`)

- **[`B-Tree` (Balanced Tree)](https://www.postgresql.org/docs/16/indexes-types.html#INDEXES-TYPES-BTREE)**: PostgreSQL's default index structure (used automatically on `PRIMARY KEY` columns like `inaturalist_id`). Sorts 1D values in order (`<`, `=`, `>`) for fast binary lookups, but cannot index 2D spatial shapes.
- **[`R-Tree` (Rectangle Tree)](https://postgis.net/workshops/postgis-intro/indexing.html)**: A 2D spatial tree data structure that wraps every complex polygon or raster tile in a simple 4-corner **Minimum Bounding Rectangle (Bounding Box)** and groups nearby rectangles hierarchically. During a spatial query, it eliminates non-overlapping bounding boxes immediately before running exact vertex math.
- **[`GIST` (Generalized Search Tree)](https://www.postgresql.org/docs/16/gist.html)**: PostgreSQL's extensible index framework that manages disk storage, concurrency, and crash recovery for custom tree structures. When applied to a PostGIS column, `GIST` builds a 2D **[`R-Tree` spatial index](https://postgis.net/docs/manual-3.4/using_postgis_dbmanagement.html#build-indexes)**:
  ```sql
  CREATE INDEX idx_observations_geom ON observations USING GIST (geom);
  ```

---

## PostGIS `ST_*` Function Glossary

`ST_` stands for **Spatial Type**. Click any function heading below to open its official **PostGIS 3.4 Manual** entry, or inspect its compiled signature inside `psql` with `\df function_name`.

### Geometry Constructors & Accessors

#### [`ST_MakePoint(x, y)`](https://postgis.net/docs/manual-3.4/ST_MakePoint.html)

Creates a 2D `Point` geometry from `x` (Longitude) and `y` (Latitude).

```sql
SELECT ST_MakePoint(-123.5736, 45.5898);
```

#### [`ST_AsText(geom)`](https://postgis.net/docs/manual-3.4/ST_AsText.html)

Converts a binary `geometry` column or expression into human-readable Well-Known Text (`WKT`).

```sql
SELECT species_name, ST_AsText(geom) FROM observations LIMIT 5;
```

#### [`ST_X(point)`](https://postgis.net/docs/manual-3.4/ST_X.html) / [`ST_Y(point)`](https://postgis.net/docs/manual-3.4/ST_Y.html)

Extracts the numeric `X` (Longitude / Easting) or `Y` (Latitude / Northing) coordinate from a `Point` geometry.

```sql
SELECT species_name, ST_X(geom) AS longitude, ST_Y(geom) AS latitude FROM observations LIMIT 5;
```

---

### Projections & Coordinate Systems

#### [`ST_SetSRID(geom, srid)`](https://postgis.net/docs/manual-3.4/ST_SetSRID.html)

Assigns an SRID label to a geometry **without** modifying its coordinate numbers. Used when constructing a geometry from raw GPS coordinates.

```sql
SELECT ST_SetSRID(ST_MakePoint(-123.5736, 45.5898), 4326);
```

#### [`ST_Transform(geom, target_srid)`](https://postgis.net/docs/manual-3.4/ST_Transform.html)

Reprojects a geometry from its existing SRID into `target_srid` by recalculating its coordinates (e.g., converting `4326` degrees into `32610` Oregon meters).

```sql
SELECT ST_AsText(ST_Transform(geom, 32610)) FROM observations LIMIT 1;
```

#### [`ST_SRID(geom)`](https://postgis.net/docs/manual-3.4/ST_SRID.html) / [`ST_SRID(rast)`](https://postgis.net/docs/manual-3.4/RT_ST_SRID.html)

Returns the integer SRID of a geometry or raster column.

```sql
SELECT ST_SRID(rast) FROM elevation_raster LIMIT 1;
```

---

### Spatial Relationships & Distance (Vector)

#### [`ST_Intersects(geomA, geomB)`](https://postgis.net/docs/manual-3.4/ST_Intersects.html)

Returns `true` if `geomA` and `geomB` share any portion of space (touch or overlap). Automatically uses the `GIST` spatial index. Argument order does not matter.

```sql
SELECT COUNT(*)
FROM observations o
JOIN land_ownership l ON ST_Intersects(o.geom, l.geom)
WHERE o.obscured = false AND l.mang_name = 'SLB';
```

#### [`ST_Within(geomA, geomB)`](https://postgis.net/docs/manual-3.4/ST_Within.html)

Returns `true` if `geomA` is **100% inside** `geomB`. Automatically uses the `GIST` index. Argument order matters: `ST_Within(inner_shape, outer_container)`.

```sql
SELECT COUNT(*)
FROM observations o
JOIN land_ownership l ON ST_Within(o.geom, l.geom)
WHERE o.obscured = false AND l.mang_name = 'SLB';
```

#### [`ST_Contains(geomA, geomB)`](https://postgis.net/docs/manual-3.4/ST_Contains.html)

Returns `true` if `geomA` **completely contains** `geomB`. Exact inverse argument order of `ST_Within`: `ST_Contains(outer_container, inner_shape)`.

```sql
SELECT COUNT(*)
FROM observations o
JOIN land_ownership l ON ST_Contains(l.geom, o.geom)
WHERE o.obscured = false AND l.mang_name = 'SLB';
```

#### [`ST_DWithin(geomA, geomB, distance)`](https://postgis.net/docs/manual-3.4/ST_DWithin.html)

Returns `true` if `geomA` and `geomB` are **within a specified distance** of each other (in the units of their SRID). Automatically uses the `GIST` index for fast radius searches.

```sql
SELECT species_name, observed_date
FROM observations
WHERE obscured = false
  AND ST_DWithin(
    ST_Transform(geom, 32610),
    ST_Transform(ST_SetSRID(ST_MakePoint(-123.5736, 45.5898), 4326), 32610),
    5000
  );
```

#### [`ST_Distance(geomA, geomB)`](https://postgis.net/docs/manual-3.4/ST_Distance.html)

Calculates the shortest distance between `geomA` and `geomB` (returns degrees if in `4326`, or meters if transformed to `32610`).

```sql
SELECT ST_Distance(
  ST_Transform(ST_SetSRID(ST_MakePoint(-122.765, 45.575), 4326), 32610),
  ST_Transform(ST_SetSRID(ST_MakePoint(-122.595, 45.512), 4326), 32610)
) AS distance_meters;
```

---

### Raster & Terrain Functions

#### [`ST_FromGDALRaster(bytea)`](https://postgis.net/docs/manual-3.4/RT_ST_FromGDALRaster.html)

Parses binary image bytes (such as a `.tif` GeoTIFF read via `pg_read_binary_file()`) into a PostGIS `raster` object. Requires [`SET postgis.gdal_enabled_drivers = 'ENABLE_ALL'`](https://postgis.net/docs/manual-3.4/postgis_gdal_enabled_drivers.html).

```sql
SELECT ST_FromGDALRaster(pg_read_binary_file('/data/dem_tillamook_32610.tif'));
```

#### [`ST_Tile(rast, width, height)`](https://postgis.net/docs/manual-3.4/RT_ST_Tile.html)

Splits a large raster into smaller `width × height` pixel tiles (returning one row per tile).

```sql
SELECT ST_Tile(rast, 100, 100) FROM raw_dem;
```

#### [`ST_ConvexHull(rast)`](https://postgis.net/docs/manual-3.4/RT_ST_ConvexHull.html)

Returns the bounding polygon outline of a raster tile. Used to build a `GIST` spatial index on raster tables:

```sql
CREATE INDEX idx_elevation_raster_convexhull ON elevation_raster USING GIST (ST_ConvexHull(rast));
```

#### [`ST_Width(rast)`](https://postgis.net/docs/manual-3.4/RT_ST_Width.html) / [`ST_Height(rast)`](https://postgis.net/docs/manual-3.4/RT_ST_Height.html)

Returns the width or height of a raster tile in pixels (`100` × `100`).

#### [`ST_ScaleX(rast)`](https://postgis.net/docs/manual-3.4/RT_ST_ScaleX.html) / [`ST_ScaleY(rast)`](https://postgis.net/docs/manual-3.4/RT_ST_ScaleY.html)

Returns the ground width (`X`) or height (`Y`) of a single pixel in SRID units (`29.93m` and `-29.93m` in `EPSG:32610`). `ScaleY` is negative because image rows count top-to-bottom (North-to-South).

#### [`ST_Slope(rast, band, pixel_type, units)`](https://postgis.net/docs/manual-3.4/RT_ST_Slope.html)

Computes a slope raster from an elevation raster (`band = 1`, `pixel_type = '32BF'` 32-bit float, `units = 'DEGREES'`), where each pixel is steepness from `0°` to `90°`.

```sql
SELECT rid, ST_Slope(rast, 1, '32BF', 'DEGREES') AS rast FROM elevation_raster;
```

#### [`ST_Aspect(rast, band, pixel_type, units)`](https://postgis.net/docs/manual-3.4/RT_ST_Aspect.html)

Computes an aspect raster from an elevation raster (`0°–360°` downhill compass orientation).

```sql
SELECT rid, ST_Aspect(rast, 1, '32BF', 'DEGREES') AS rast FROM elevation_raster;
```

#### [`ST_Value(rast, point)`](https://postgis.net/docs/manual-3.4/RT_ST_Value.html) / [`ST_Intersects(rast, geom)`](https://postgis.net/docs/manual-3.4/RT_ST_Intersects.html)

Extracts the numeric pixel value from a raster tile `rast` at the exact location of `point` (both `rast` and `point` must share the same SRID).

```sql
SELECT ST_Value(e.rast, ST_Transform(o.geom, 32610)) AS elevation_meters
FROM observations o
JOIN elevation_raster e ON ST_Intersects(e.rast, ST_Transform(o.geom, 32610))
LIMIT 5;
```

---

## SQL Clauses & Keywords

- **[`SELECT col AS alias`](https://www.postgresql.org/docs/16/sql-select.html)**: Specifies output columns or expressions and renames column headers with `AS`.
- **`FROM table alias`**: Specifies the source table and assigns a shorthand alias (e.g., `FROM observations o`).
- **`WHERE condition`**: Filters rows before grouping or aggregation.
- **[`ILIKE '%pattern%'`](https://www.postgresql.org/docs/16/functions-matching.html#FUNCTIONS-LIKE)**: Case-insensitive wildcard text search (`%` matches zero or more characters).
- **`GROUP BY col` + `COUNT(*)`**: Aggregates rows sharing the same column value and counts rows per group.
- **`COUNT(DISTINCT col)`**: Counts unique values only (prevents double-counting if a point intersects overlapping polygons).
- **[`JOIN` (Inner Join) vs. `LEFT JOIN`](https://www.postgresql.org/docs/16/tutorial-join.html)**:
  - `JOIN`: Combines rows from two tables where the `ON` condition is `true`, dropping unmatched rows.
  - `LEFT JOIN`: Keeps all rows from the left table; if no match exists in the right table, right-side columns return `NULL`.
- **[`COALESCE(col, 'default')`](https://www.postgresql.org/docs/16/functions-conditional.html#FUNCTIONS-COALESCE-NVL-IFNULL)**: Returns the first non-`NULL` value.
- **[`WITH cte_name AS (...)`](https://www.postgresql.org/docs/16/queries-with.html)**: Defines a temporary named result set (**Common Table Expression**) for use in the main query.
- **[`ALTER TABLE ... ADD COLUMN`](https://www.postgresql.org/docs/16/sql-altertable.html)**: Adds a new column to an existing table without dropping data.
- **[`UPDATE table SET col = val`](https://www.postgresql.org/docs/16/sql-update.html)**: Modifies column values across existing rows.
- **[`ON CONFLICT (key) DO UPDATE / DO NOTHING`](https://www.postgresql.org/docs/16/sql-insert.html#SQL-ON-CONFLICT)**: Handles duplicate primary keys during `INSERT` (an **Upsert**), either updating specified fields via `EXCLUDED.col` or skipping the duplicate row.

---

## Official Documentation & References

- **[PostGIS 3.4 Official Manual](https://postgis.net/docs/manual-3.4/)**
  - [PostGIS Geometry Function Reference (`ST_*`)](https://postgis.net/docs/manual-3.4/reference.html)
  - [PostGIS Raster Function Reference (`RT_ST_*`)](https://postgis.net/docs/manual-3.4/RT_reference.html)
  - [PostGIS Introduction Workshop — Chapter 15: Spatial Indexing (`GIST` / `R-Tree`)](https://postgis.net/workshops/postgis-intro/indexing.html)
- **[PostgreSQL 16 Official Documentation](https://www.postgresql.org/docs/16/index.html)**
  - [Chapter 11: Indexes (`B-Tree`, `GiST`)](https://www.postgresql.org/docs/16/indexes-types.html)
  - [Chapter 66: GiST Indexes (Generalized Search Tree)](https://www.postgresql.org/docs/16/gist.html)
- **[EPSG Geodetic Parameter Dataset](https://epsg.io/)**
  - [`EPSG:4326` — WGS 84 (GPS Degrees)](https://epsg.io/4326)
  - [`EPSG:32610` — WGS 84 / UTM Zone 10N (Oregon Meters)](https://epsg.io/32610)
