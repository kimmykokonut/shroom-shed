# learning PostGIS

WIP

## project:

- explore mushroom observation patterns across land ownership, elevation, aspect, slope, canopy cover & tree species in Portland tri-county area

## tech stack

- docker desktop
- postgis
- python
- postsql
- GDAL tools
- raw SQL
- Flask/FlashAPI/Leaflet or Jupyter/geopandas/matplotlib for vis

## data sources

- iNaturalist API (api.inaturalist.org/v1/observations) — filter by fungi taxon (47170), place_id for Multnomah County / Oregon, date range
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
