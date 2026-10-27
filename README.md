# Shroom Shed

**PostGIS spatial analysis exploring mushroom observation patterns across land ownership and terrain in Tillamook County, Oregon**

_by [Kim Robinson](https://github.com/kimmykokonut)_

---

🍄 Explore where wild fungi are spotted across the Oregon Coast Range using raw spatial SQL.

🌲 Cross-reference observations against State Forest, National Forest, BLM, State Parks, and private timberland boundaries.

🗺️ Inspect point geometries, land ownership polygons, and terrain rasters directly in `psql` or pgAdmin's interactive map viewer.

## Jump around

- [Introduction](#introduction)
- [Features](#features)
- [Toolbelt](#toolbelt)
- [Known Bugs](#known-bugs)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Setup](#setup)
  - [Connecting to the Database](#connecting-to-the-database)
- [Example SQL & PostGIS Queries](#example-sql--postgis-queries)
  - [Spatial Reference Systems & Distance Basics](#1-spatial-reference-systems--distance-basics)
  - [Exploring Mushroom Observations](#2-exploring-mushroom-observations)
  - [Land Ownership Spatial Joins (PAD-US)](#3-land-ownership-spatial-joins-pad-us)
  - [Terrain Rasters: Elevation, Slope & Aspect (USGS 3DEP)](#4-terrain-rasters-elevation-slope--aspect-usgs-3dep)
- [Phases & Stretch Goals](#phases--stretch-goals)
- [Contact and Support](#contact-and-support)
- [License](#license)
- [Acknowledgements](#acknowledgements)

---

## Introduction

**Shroom Shed** is a hands-on geospatial data project built to explore **PostgreSQL + PostGIS** from the ground up—intentionally skipping ORM abstractions to write raw spatial SQL directly against real Pacific Northwest ecological datasets.

Focusing on **Tillamook County and the Tillamook State Forest, OR** (where personal-use mushroom foraging is permitted on state forest lands), the project ingests public Kingdom Fungi observations from the **iNaturalist API** and joins them spatially with **USGS Protected Areas Database (PAD-US)** land ownership polygons, **USGS 3DEP** elevation/slope/aspect rasters, and **NLCD** tree canopy data.

---

## Features

### 📍 iNaturalist Fungi Ingestion Pipeline
- Pulls verifiable Kingdom Fungi (`taxon_id=47170`) sightings for Tillamook County (`place_id=494`) via Python (`requests` + `psycopg`) and converts GeoJSON `[longitude, latitude]` coordinates into indexed PostGIS `GEOMETRY(Point, 4326)` rows on insert.
- **Geoprivacy & Obscured Coordinate Detection**: Flags observations where `obscured = true` (which randomizes coordinates within a ~20 km box, often landing in the Pacific Ocean along the coast) so obscured records can be retained for county-wide species counts while filtered out (`WHERE obscured = false`) for exact parcel and terrain queries.
- **Idempotent Upserts**: Uses `ON CONFLICT (inaturalist_id) DO UPDATE` so re-running the ingestion script safely updates existing records without duplicating rows.

### 🌲 Public vs. Private Land Ownership Spatial Joins (PAD-US 3.0)
- Automated shell scripts (`scripts/download_padus.sh` and `scripts/load_padus.sh`) query the USGS PAD-US 3.0 FeatureServer for the Tillamook County bounding box and load multi-parcel boundaries into PostGIS as `GEOMETRY(MultiPolygon, 4326)` using containerized `ogr2ogr`.
- Joins mushroom sightings against land management agencies (`ST_Intersects`) including **Oregon Board of Forestry / Tillamook State Forest (`SLB`)**, **Siuslaw National Forest (`USFS`)**, **Bureau of Land Management (`BLM`)**, **Oregon State Parks (`SPR`/`CITY`)**, **U.S. Fish & Wildlife Refuges (`FWS`)**, and unmapped private timberland.

### 🐳 Hybrid Containerized Architecture
- Runs **PostgreSQL 16 + PostGIS 3.4** (`postgis` and `postgis_raster` extensions) and **GDAL CLI tools** (`ogr2ogr`, `gdalwarp`) inside Docker containers while keeping Python scripts in a lightweight local `.venv` for fast execution and full IDE autocomplete.
- Exposes PostGIS on host port **`5433`** (`localhost:5433` $\rightarrow$ container `5432`) to run cleanly alongside any existing local macOS PostgreSQL server on port `5432`.

---

## Toolbelt

![Postgres](https://img.shields.io/badge/postgres-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Markdown](https://img.shields.io/badge/Markdown-000000?style=for-the-badge&logo=markdown&logoColor=white)
![Git](https://img.shields.io/badge/git-%23F05033.svg?style=for-the-badge&logo=git&logoColor=white)
![Visual Studio Code](https://img.shields.io/badge/Visual%20Studio%20Code-0078d7.svg?style=for-the-badge&logo=visual-studio-code&logoColor=white)

---

## Known Bugs

None at this time.
*(Note: Coastal observations with `obscured = true` have coordinates randomized by iNaturalist within a ~20 km bounding box and may plot over the Pacific Ocean; filter with `WHERE obscured = false` when viewing or querying exact locations).*

---

## Getting Started

### Prerequisites

1. **Code Editor**
   To view or edit the code, you will need a code editor or text editor. The open-source code editor I used is Visual Studio Code.
   - Download: [Visual Studio Code](https://code.visualstudio.com/)
   - Select the download most applicable to your OS and system.

2. **Docker Desktop**
   Required to run the PostgreSQL 16 + PostGIS 3.4 database and containerized GDAL CLI tools (`ogr2ogr`).
   - Download & install: [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - Ensure the Docker Desktop application is running before starting the setup steps below.

3. **Python 3 (& Homebrew)**
   ```bash
   python3 --version
   ```
   _If you don't have Python 3_, you can install it via Homebrew:
   ```bash
   brew install python
   ```
   _If you don't have Homebrew_, install instructions [here](https://brew.sh/).

4. **pgAdmin 4 (Optional)**
   Recommended for viewing tables like a spreadsheet and plotting PostGIS `geom` points and polygons on an interactive slippy map.
   - Download: [pgAdmin 4](https://www.pgadmin.org/download/)

---

### Setup

1. Navigate to the [repository](https://github.com/kimmykokonut/shroom-shed).

2. Select the `Fork` button and you will be taken to a new page where you can give your repository a new name and description. Choose "Create fork".

3. Select the `Code` button and copy the URL for HTTPS.

4. On your local computer, create a working directory of your choice.

5. Clone repo:
   ```bash
   git clone https://github.com/kimmykokonut/shroom-shed.git
   ```

6. Navigate into the project directory:
   ```bash
   cd shroom-shed
   ```

7. View/Edit in VS Code:
   ```bash
   code .
   ```

8. Create your `.env` file from the provided template:
   ```bash
   cp .env.example .env
   ```
   *(By default, `.env` maps the container to `DB_PORT=5433` on `localhost` so it will not collide with a local PostgreSQL server on `5432`).*

9. Start the PostGIS database container:
   ```bash
   docker compose up -d
   ```
   On first initialization, Docker automatically runs `sql/init/01_extensions.sql` (enabling `postgis` and `postgis_raster`) and `sql/init/02_schema.sql` (creating the `observations` table and `GIST` spatial index).

   *(Note: If you ever change `POSTGRES_PASSWORD` in `.env` after the volume is already created, reset the volume with `docker compose down -v && docker compose up -d`).*

10. Create a local Python virtual environment and install dependencies:
    ```bash
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r scripts/requirements.txt
    ```

11. Ingest Tillamook County fungi observations from the iNaturalist API:
    ```bash
    python scripts/ingest_inaturalist.py
    ```

12. Download and load USGS PAD-US 3.0 land ownership polygons for Tillamook County:
    ```bash
    ./scripts/download_padus.sh
    ./scripts/load_padus.sh
    ```

13. Download and load the USGS 3DEP Digital Elevation Model (DEM) raster (`EPSG:32610`), then derive slope and aspect raster tables:
    ```bash
    ./scripts/download_dem.sh
    ./scripts/load_dem.sh
    docker compose exec -T db psql -U shroom -d shroom_shed -f /sql/05_terrain_rasters.sql
    ```

---

### Connecting to the Database

#### Option A: Interactive Terminal SQL Shell (`psql`)
Open `psql` inside the running Docker container:
```bash
docker compose exec db psql -U shroom -d shroom_shed
```

**Helpful `psql` shortcuts once inside `shroom_shed=#`:**
| Command | Description |
| :--- | :--- |
| `\dt` | List all tables in the database |
| `\d observations` | Describe columns, data types, and indexes of a table |
| `\i /sql/04_ownership_analysis.sql` | Execute a `.sql` file mounted from the `sql/` folder |
| `\pset pager off` | Print full query results directly without pausing in `(END)` |
| `\r` | Clear/reset the current SQL input buffer |
| `q` | Exit the `(END)` pager view |
| `\q` | Exit `psql` and return to your Mac terminal |

#### Option B: Visual Table & Map Viewer (`pgAdmin 4`)
1. Open **pgAdmin 4** and click **Add New Server**:
   - **General tab $\rightarrow$ Name:** `Shroom Shed (PostGIS)`
   - **Connection tab:**
     - **Host name/address:** `localhost`
     - **Port:** `5433`
     - **Maintenance database:** `shroom_shed`
     - **Username:** `shroom` (or value in `.env`)
     - **Password:** `shroom_password` (or value in `.env`)
2. In the left sidebar, expand **Servers $\rightarrow$ Shroom Shed (PostGIS) $\rightarrow$ Databases $\rightarrow$ shroom_shed $\rightarrow$ Schemas $\rightarrow$ public $\rightarrow$ Tables**.
   - *(Tip: Right-click `Tables` $\rightarrow$ **Refresh...** whenever a new table is created from the terminal).*
3. Right-click `observations` or `land_ownership` $\rightarrow$ **View/Edit Data $\rightarrow$ All Rows**, then click the **Map / Eye icon** on the `geom` column header to view points and polygons on an interactive map.

---

## Example SQL & PostGIS Queries

Run any of the queries below inside **`psql` (`shroom_shed=#`)** or the **pgAdmin Query Tool**.

### 1. Spatial Reference Systems & Distance Basics

PostGIS stores GPS coordinates in **SRID `4326`** `(Longitude, Latitude)` measured in degrees on a sphere. To measure real-world distances in meters in Oregon, transform coordinates to **SRID `32610`** (UTM Zone 10N):

**Create a GPS point (`ST_MakePoint` + `ST_SetSRID`) and display as readable text (`ST_AsText`):**
```sql
SELECT ST_AsText(ST_SetSRID(ST_MakePoint(-123.5736, 45.5898), 4326)) AS tillamook_forest_center;
```

**Inspect coordinate system definitions (`4326` degrees vs. `32610` Oregon meters):**
```sql
SELECT srid, auth_name, srtext FROM spatial_ref_sys WHERE srid IN (4326, 32610);
```

**Calculate real-world distance in meters between two GPS coordinates (`ST_Transform` + `ST_Distance`):**
```sql
SELECT ST_Distance(
  ST_Transform(ST_SetSRID(ST_MakePoint(-122.765, 45.575), 4326), 32610),
  ST_Transform(ST_SetSRID(ST_MakePoint(-122.595, 45.512), 4326), 32610)
) AS distance_in_meters;
```

---

### 2. Exploring Mushroom Observations

**Count total observations and date range:**
```sql
SELECT COUNT(*) AS total_sightings, MIN(observed_date) AS earliest_date, MAX(observed_date) AS latest_date FROM observations;
```

**Preview 10 observations with human-readable GPS coordinates:**
```sql
SELECT inaturalist_id, species_name, common_name, observed_date, obscured, ST_AsText(geom) AS gps_point FROM observations LIMIT 10;
```

**Compare accurate (`f`) vs. obscured (`t`) coordinate counts:**
```sql
SELECT obscured, COUNT(*) AS sighting_count FROM observations GROUP BY obscured;
```

**See which mushroom species are most frequently obscured (`obscured = true`):**
```sql
SELECT species_name, common_name, COUNT(*) AS hidden_count FROM observations WHERE obscured = true GROUP BY species_name, common_name ORDER BY hidden_count DESC LIMIT 10;
```

**Top 15 most commonly spotted fungi in Tillamook County:**
```sql
SELECT species_name, common_name, COUNT(*) AS sightings FROM observations GROUP BY species_name, common_name ORDER BY sightings DESC LIMIT 15;
```

**Filter specifically for prized foraging mushrooms (`ILIKE` case-insensitive search):**
```sql
SELECT species_name, common_name, COUNT(*) AS sightings FROM observations WHERE common_name ILIKE '%chanterelle%' OR common_name ILIKE '%bolete%' OR common_name ILIKE '%oyster%' OR common_name ILIKE '%matsutake%' GROUP BY species_name, common_name ORDER BY sightings DESC;
```

**Radius search (`ST_DWithin`): Find non-obscured mushrooms within 5,000 meters (5 km) of the Tillamook Forest Center (`-123.5736, 45.5898`):**
```sql
SELECT species_name, common_name, observed_date, ROUND(ST_Distance(ST_Transform(geom, 32610), ST_Transform(ST_SetSRID(ST_MakePoint(-123.5736, 45.5898), 4326), 32610))::numeric, 0) AS distance_meters FROM observations WHERE obscured = false AND ST_DWithin(ST_Transform(geom, 32610), ST_Transform(ST_SetSRID(ST_MakePoint(-123.5736, 45.5898), 4326), 32610), 5000) ORDER BY distance_meters ASC LIMIT 15;
```

---

### 3. Land Ownership Spatial Joins (PAD-US)

Key PAD-US `mang_name` agency codes in Tillamook County:
- **`SLB`** — Oregon Board of Forestry / State Land Board (**Tillamook State Forest**)
- **`USFS`** — U.S. Forest Service (**Siuslaw National Forest**, Cascade Head, Hebo)
- **`BLM`** — Bureau of Land Management (NW Oregon Tillamook Field Office, Nehalem/Wilson/Trask rivers)
- **`SPR` / `CITY`** — Oregon State Parks & Recreation / State Natural Areas
- **`FWS`** — U.S. Fish & Wildlife Service (Cape Meares & Nestucca Bay National Wildlife Refuges)

**Count land ownership polygon parcels by Manager Type and Agency:**
```sql
SELECT mang_type, mang_name, COUNT(*) AS parcel_count FROM land_ownership GROUP BY mang_type, mang_name ORDER BY parcel_count DESC;
```

**Spatial Join (`LEFT JOIN` + `ST_Intersects`): Sightings by Public Agency vs. Private/Unmapped Land:**
```sql
SELECT COALESCE(l.mang_type, 'PRIVATE / UNPROTECTED') AS owner_type, COALESCE(l.mang_name, 'Private / Unmapped') AS agency_code, COUNT(DISTINCT o.inaturalist_id) AS mushroom_sightings FROM observations o LEFT JOIN land_ownership l ON ST_Intersects(o.geom, l.geom) WHERE o.obscured = false GROUP BY owner_type, agency_code ORDER BY mushroom_sightings DESC;
```

**Top 15 specific forests, parks, and reserves by mushroom sightings (`JOIN`):**
```sql
SELECT l.mang_name AS agency, l.unit_nm AS land_unit_name, l.pub_access AS access_code, COUNT(DISTINCT o.inaturalist_id) AS mushroom_sightings FROM observations o JOIN land_ownership l ON ST_Intersects(o.geom, l.geom) WHERE o.obscured = false GROUP BY l.mang_name, l.unit_nm, l.pub_access ORDER BY mushroom_sightings DESC LIMIT 15;
```

**Top 15 mushroom species found specifically inside Tillamook State Forest (`l.mang_name = 'SLB'`):**
```sql
SELECT o.species_name, o.common_name, COUNT(DISTINCT o.inaturalist_id) AS sightings FROM observations o JOIN land_ownership l ON ST_Intersects(o.geom, l.geom) WHERE o.obscured = false AND l.mang_name = 'SLB' GROUP BY o.species_name, o.common_name ORDER BY sightings DESC LIMIT 15;
```

---

### 4. Terrain Rasters: Elevation, Slope & Aspect (USGS 3DEP)

The USGS 3DEP Digital Elevation Model (`elevation_raster`) is stored in **`EPSG:32610`** (UTM Zone 10N, meters) as 560 indexed `100×100` pixel tiles (~30m resolution), alongside derived **`slope_raster`** (`0°–90°` steepness via `ST_Slope`) and **`aspect_raster`** (`0°–360°` compass direction via `ST_Aspect`).

**Inspect tile count, pixel dimensions, and meter resolution of `elevation_raster`:**
```sql
SELECT COUNT(*) AS total_tiles, ST_Width(rast) AS tile_width_px, ST_Height(rast) AS tile_height_px, ST_SRID(rast) AS srid, ROUND(ST_ScaleX(rast)::numeric, 2) AS pixel_width_meters, ROUND(ST_ScaleY(rast)::numeric, 2) AS pixel_height_meters FROM elevation_raster GROUP BY tile_width_px, tile_height_px, srid, pixel_width_meters, pixel_height_meters;
```

**Sample elevation (meters), slope (degrees), and aspect (compass degrees) at a GPS coordinate (`ST_Value`):**
```sql
SELECT e.rid AS tile_number, ROUND(ST_Value(e.rast, ST_Transform(ST_SetSRID(ST_MakePoint(-123.5736, 45.5898), 4326), 32610))::numeric, 1) AS elevation_meters, ROUND(ST_Value(s.rast, ST_Transform(ST_SetSRID(ST_MakePoint(-123.5736, 45.5898), 4326), 32610))::numeric, 1) AS slope_degrees, ROUND(ST_Value(a.rast, ST_Transform(ST_SetSRID(ST_MakePoint(-123.5736, 45.5898), 4326), 32610))::numeric, 1) AS aspect_degrees FROM elevation_raster e JOIN slope_raster s ON e.rid = s.rid JOIN aspect_raster a ON e.rid = a.rid WHERE ST_Intersects(e.rast, ST_Transform(ST_SetSRID(ST_MakePoint(-123.5736, 45.5898), 4326), 32610));
```

---

## Phases & Stretch Goals

### Phases
- [x] **Phase 1**: Containerized PostgreSQL 16 + PostGIS 3.4 (`postgis` & `postgis_raster`) and on-demand GDAL CLI setup
- [x] **Phase 2**: Spatial schema design (`observations` point geometries, `GIST` indexing, coordinate projections)
- [x] **Phase 3**: iNaturalist API ingestion script for Tillamook County Fungi with obscured geoprivacy tracking
- [x] **Phase 4**: USGS PAD-US 3.0 land ownership polygon ingestion (`ogr2ogr`) and public vs. private spatial joins (`ST_Intersects`)
- [x] **Phase 5**: USGS 3DEP Digital Elevation Model (DEM) raster ingestion (`ST_FromGDALRaster`, `ST_Tile`) and slope/aspect derivation (`ST_Slope`, `ST_Aspect`)
- [ ] **Phase 6**: Terrain sampling at observation points (`ST_Value`) and elevation/slope/aspect distribution analysis
- [ ] **Phase 7**: Habitat similarity query — locate under-explored Tillamook State Forest parcels matching target terrain profiles

### Stretch
- [ ] **NLCD Tree Canopy & Forest Type Raster**: Sample canopy cover percentage (`0–100%`) and forest classification (Evergreen vs. Deciduous vs. Mixed) at each mushroom sighting
- [ ] **NOAA GHCN-Daily Precipitation Join**: Correlate sighting frequency with cumulative 7–14 day rainfall from nearest weather stations
- [ ] **Interactive Map Frontend**: Lightweight FastAPI/Flask + Leaflet or Jupyter + GeoPandas visualization layer

---

## Contact and Support

If you have any feedback or concerns:

- [Report Bug](https://github.com/kimmykokonut/shroom-shed/issues)
- [Request Feature](https://github.com/kimmykokonut/shroom-shed/issues)

---

## License

[GNU GENERAL PUBLIC LICENSE](/LICENSE)

---

## Acknowledgements

Data providers:
- [iNaturalist API](https://api.inaturalist.org/v1/docs/)
- [USGS Protected Areas Database of the United States (PAD-US 3.0)](https://www.usgs.gov/programs/gap-analysis-project/science/pad-us-data-overview)
- [USGS 3D Elevation Program (3DEP)](https://www.usgs.gov/3d-elevation-program)
