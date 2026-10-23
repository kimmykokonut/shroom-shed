# learning PostGIS

WIP

## project:

- explore mushroom observation patterns across land ownership, elevation, aspect, slope, canopy cover & tree species in Portland tri-county area

## tech stack

- postgreSQL and postGIS via Docker
- python
- GDAL CLI tools in docker
- raw SQL
- Flask/FlashAPI/Leaflet or Jupyter/geopandas/matplotlib for vis

## data sources

- iNaturalist API (api.inaturalist.org/v1/observations) — filter by fungi taxon (47170), place_id for specific region, date range
- PAD-US (USGS Protected Areas Database) — land ownership polygons, clipped to county extent
- USGS 3DEP — DEM (elevation raster) for the same extent
- USGS NLCD (National Land Cover Database) — 30m resolution GeoTIFFs:
  • Tree Canopy Cover (0–100%): Every 30m×30m pixel stores the percentage of tree canopy overhead.
  • Land Cover Class: Categorizes every 30m pixel into classes:
  • 41 = Deciduous Forest (alder, maple, cottonwood, oak)
  • 42 = Evergreen Forest (Douglas-fir, hemlock, cedar)
  • 43 = Mixed Forest 2. OSU / USFS LEMMA GNN (Gradient Nearest Neighbor):
  • maps specific dominant tree species (e.g., Pseudotsuga menziesii Douglas-fir vs.
  Tsuga heterophylla Western hemlock) and stand age at 30m resolution.

Stretch: NOAA GHCN-Daily precipitation data from nearest weather station, joined by cumulative rainfall in the 7–14 days prior to each observation date

## setup notes

1. open docker desktop

2. spin up docker

```bash
docker compose up -d
```

3. connect to container's interactive shell `psql`

```bash
docker compose exec db psql -U shroom -d shroom_shed
```

4. once inside psql, inspect database if desired

```bash
\d observations
```

### Proposed Chunk-by-Chunk Roadmap (One Commit per Chunk)

• Chunk 1: Repo Setup, Docker + PostGIS & Raster Extensions
• Initialize Git, create .gitignore, docker-compose.yml, and sql/01_init_extensions.sql.
• Note on PostGIS 3+: Raster support was split into a separate extension (postgis_raster), so we'll enable both postgis and
postgis_raster and test them with a quick spatial query.
• Chunk 2: Schema Design & Spatial Reference Systems (SRIDs)
• Create sql/02_schema.sql with our initial observations and land_ownership tables, GIST spatial indexes, and talk through
SRID choices (EPSG:4326 WGS84 GPS coordinates vs. EPSG:2992 / EPSG:32610 projected meters/feet for Oregon so distance,
buffer, and slope calculations are accurate).
• Chunk 3: Ingest iNaturalist Fungi Observations (Multnomah County)
• Write a clean Python script using requests + psycopg (raw SQL INSERT ... ON CONFLICT) to pull Multnomah County
(place_id=1867) fungi (taxon_id=47170) observations and inspect them via psql.
• Chunk 4: Load PAD-US Land Ownership Polygons & Spatial Joins
• Clip and load PAD-US for Multnomah County, then write our first analysis queries (ST_Intersects / ST_Within) comparing
sightings across public vs. private land and by agency/manager.
• Chunk 5: USGS 3DEP DEM Raster + Slope & Aspect Derivation
• Load the Multnomah County DEM using raster2pgsql, derive slope (ST_Slope) and aspect (ST_Aspect), and sample terrain
values at each mushroom observation (ST_Value).
• Chunk 6: The "Prophetic" Payoff Query (Habitat Similarity Search)
• Find the sweet-spot elevation/slope/aspect profile for target species (e.g., chanterelles or morels) and query for under-
explored public land polygons with matching terrain.
• Chunk 7 (Stretch): NOAA GHCN-Daily Precipitation Window Joins
