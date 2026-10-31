# AGENTS.md — Shroom Shed (PostGIS Learning Project)

## Project Goal
Explore mushroom (Fungi) observation patterns across land ownership (PAD-US), elevation, slope, aspect (USGS 3DEP DEM), and tree canopy cover (NLCD) in **Tillamook County / Tillamook State Forest, OR** using raw SQL and PostGIS.

## Architecture & Local Dev Setup (Hybrid)
- **PostgreSQL 16 + PostGIS 3.4 (`db` service in Docker):**
  - Container: `shroom_postgis` (`postgis/postgis:16-3.4`, `platform: linux/amd64`)
  - Host port: **`5433`** (`localhost:5433` -> container `5432`, avoiding conflict with local macOS Postgres on `5432`)
  - Credentials & connection settings stored in `.env` (template in `.env.example`)
  - Extensions enabled in `sql/init/01_extensions.sql`: `postgis`, `postgis_raster`
- **GDAL CLI Tools (`gdal` service in Docker):**
  - Image: `ghcr.io/osgeo/gdal:alpine-small-latest` (`profiles: ["tools"]`, `network_mode: "service:db"`)
  - Used for `ogr2ogr` and `gdalwarp` without installing C++ GIS libraries on macOS.
- **Python (`.venv` on macOS host):**
  - Virtual environment at `.venv/` using `scripts/requirements.txt` (`requests`, `psycopg[binary]`, `python-dotenv`).
  - Connects to PostGIS at `localhost:5433` via `.env`.

## Workflow & Collaboration Rules for AI Agents
1. **Move slowly and explain everything:**
   - The user is refreshing **SQL** and learning **PostGIS** hands-on.
   - Explain SQL clauses (`SELECT`, `WHERE`, `GROUP BY`, `JOIN`, `ALTER TABLE`, `ON CONFLICT`) and PostGIS functions (`ST_MakePoint`, `ST_SetSRID`, `ST_Transform`, `ST_DWithin`, `ST_Intersects`, `ST_Value`, `ST_Slope`, `ST_Aspect`) clearly.
   - Always label commands clearly by where they should be run:
     - **In Mac Terminal (`%` prompt)** vs. **Inside `psql` (`shroom_shed=#` prompt)**.
   - **How to run `.sql` files in `sql/`:** Because `./sql` is mounted at `/sql:ro` inside the `db` container, always instruct the user to execute `.sql` scripts inside their interactive `psql` (`shroom_shed=#` prompt) using `\i /sql/<filename>.sql` (e.g., `\i /sql/06_sample_trees.sql`, `\i /sql/07_habitat_search.sql`), or inside **pgAdmin 4's Query Tool**. Do not instruct them to run `docker compose exec ... < sql/...` from Mac Terminal or manually paste full `.sql` script files.
   - Avoid `--` comments inside any ad-hoc multi-line `psql` copy-paste snippets so terminal line-wrapping never comments out SQL code.
2. **Never run ad-hoc `curl` commands without recording them in `scripts/`:**
   - Any `curl` request used to discover API endpoints, look up IDs, inspect schemas, or download spatial datasets **must** be saved in a script inside `scripts/` (e.g., `scripts/discover_apis.sh`, `scripts/download_padus.sh`) and executed from that file so the repository retains a complete, reproducible record for posterity.
3. **Commit in logical chunks:**
   - Pause at the end of each phase/chunk so the user can test, inspect in `psql` and `pgAdmin`, and commit cleanly.

## Key Data Sources & IDs Discovered
- **iNaturalist API (`https://api.inaturalist.org/v1/observations`):**
  - `taxon_id=47170`: Kingdom Fungi (broad lookup)
  - Target Foraging Genera `taxon_id`s (`835` all-time sightings in Tillamook County):
    - `47348` (*Cantharellus* — Golden/White/Rainbow Chanterelles)
    - `48611` (*Craterellus* — Winter/Yellowfoot Chanterelles)
    - `48703` (*Boletus* — King Boletes / Porcini)
    - `48496` (*Pleurotus* — Oyster Mushrooms)
    - `48422` (*Hydnum* — Hedgehog Mushrooms)
    - `62484` (*Tricholoma* — Matsutake & Knights)
    - `63020` (*Sparassis* — Cauliflower Mushrooms)
    - `49160` (*Hericium* — Lion's Mane & Bear's Head)
    - `48431` (*Laetiporus* — Chicken of the Woods)
    - `56830` (*Morchella* — True Morels)
  - `place_id=494`: Tillamook County, OR, US (primary study area)
  - `place_id=984`: Multnomah County, OR, US (initial lookup reference)
  - Note on `obscured`: Some foraging observations have `obscured=true` (e.g., 100% of *Tricholoma murrillianum* Western Matsutake are auto-obscured by iNaturalist), which randomizes coordinates within a ~20 km box. We keep obscured rows in `observations` (with `elevation_m = NULL`) so `COUNT(*)` includes them in county-wide species and seasonality counts while `AVG(elevation_m)` and spatial joins (`WHERE obscured = false`) only use accurate coordinates.
- **USGS PAD-US 3.0 Public Access FeatureServer:**
  - Endpoint: `https://services1.arcgis.com/CD5mKowwN6nIaqd8/arcgis/rest/services/PADUS3_0_PublicAccess/FeatureServer/0/query`
  - Tillamook County bounding box: `-124.05,45.05,-123.30,45.80` (`EPSG:4326`)
  - Key attributes: `Mang_Type` (`STAT`, `FED`, `LOC`, `NGO`, `PVT`), `Mang_Name` (`SLB` = Oregon Board of Forestry / Tillamook State Forest, `USFS` = Siuslaw National Forest, `BLM`, `SPR` = State Parks, `FWS`), `Unit_Nm`, `Des_Tp`, `Pub_Access`.
- **USFS GeoPlatform Vegetation ImageServices (`EPSG:32610`, `2000x2800` grid):**
  - **2024 NLCD Tree Canopy Cover (`0–100%`, `canopy_raster`):** `https://imagery.geoplatform.gov/iipp/rest/services/Vegetation/USFS_EDW_NLCD_TCC_CONUS/ImageServer/exportImage` (requires `mosaicRule={"mosaicMethod":"esriMosaicLockRaster","lockRasterIds":[79]}` for 2024 slice).
  - **2024 NLCD Land Cover Class (`landcover_raster`):** `https://imagery.geoplatform.gov/iipp/rest/services/Vegetation/USFS_EDW_NLCD_Landcover_CONUS/ImageServer/exportImage` (requires `mosaicRule={"mosaicMethod":"esriMosaicLockRaster","lockRasterIds":[40]}` for 2024 slice; `41` = Deciduous, `42` = Evergreen, `43` = Mixed, `52` = Shrub/Young Clearcut, `90` = Woody Wetlands).
  - **USFS FIA Dominant Forest Type Group (`forest_type_raster`):** `https://imagery.geoplatform.gov/iipp/rest/services/Vegetation/USFS_EDW_FIA_ForestAtlas_ForestTypeGroups_109_CONUS/ImageServer/exportImage` (`200` = Douglas-fir, `300` = Western Hemlock / Sitka Spruce, `910` = Red Alder / Bigleaf Maple, `280` = Shore Pine / Lodgepole Pine, `260` = True Fir / Mountain Hemlock).
