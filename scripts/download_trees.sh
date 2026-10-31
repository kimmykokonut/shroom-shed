#!/usr/bin/env bash
# scripts/download_trees.sh
# Downloads three 30m forest/vegetation GeoTIFF rasters covering Tillamook County, OR
# (-124.05, 45.05 to -123.30, 45.80) in EPSG:32610 (2000 x 2800 pixels, matching our DEM grid):
#   1. data/canopy_tillamook_32610.tif      -> USFS / MRLC 2024 NLCD Tree Canopy Cover (0-100%)
#   2. data/landcover_tillamook_32610.tif   -> USFS / MRLC 2024 NLCD Land Cover Class (41=Deciduous, 42=Evergreen, 43=Mixed)
#   3. data/forest_type_tillamook_32610.tif -> USFS FIA Dominant Forest Type Group (e.g. 200=Douglas-fir, 300=Hemlock/Sitka Spruce, 900=Alder/Maple)
#
# Note: Both NLCD ImageServices are multi-year temporal mosaics (1985/1988 to 2024) that default
# to returning the oldest year first unless we pass a `mosaicRule` locking the 2024 raster slice
# (objectid 79 for Tree Canopy Cover, objectid 40 for Land Cover).
# We use `RSP_NearestNeighbor` interpolation so discrete category codes and integer canopy percentages
# are never blended into invalid intermediate numbers.

set -euo pipefail

BBOX="-124.05,45.05,-123.30,45.80"
SIZE="2000,2800"

CANOPY_FILE="data/canopy_tillamook_32610.tif"
LANDCOVER_FILE="data/landcover_tillamook_32610.tif"
FOREST_TYPE_FILE="data/forest_type_tillamook_32610.tif"

echo "1/3 Downloading 2024 NLCD Tree Canopy Cover (0-100%) to ${CANOPY_FILE}..."
curl -sG "https://imagery.geoplatform.gov/iipp/rest/services/Vegetation/USFS_EDW_NLCD_TCC_CONUS/ImageServer/exportImage" \
  --data-urlencode "bbox=${BBOX}" \
  --data-urlencode "bboxSR=4326" \
  --data-urlencode "imageSR=32610" \
  --data-urlencode "size=${SIZE}" \
  --data-urlencode 'mosaicRule={"mosaicMethod":"esriMosaicLockRaster","lockRasterIds":[79]}' \
  --data-urlencode "format=tiff" \
  --data-urlencode "pixelType=U8" \
  --data-urlencode "noData=255" \
  --data-urlencode "interpolation=RSP_NearestNeighbor" \
  --data-urlencode "f=image" \
  -o "${CANOPY_FILE}"
ls -lh "${CANOPY_FILE}"

echo "2/3 Downloading 2024 NLCD Land Cover Class to ${LANDCOVER_FILE}..."
curl -sG "https://imagery.geoplatform.gov/iipp/rest/services/Vegetation/USFS_EDW_NLCD_Landcover_CONUS/ImageServer/exportImage" \
  --data-urlencode "bbox=${BBOX}" \
  --data-urlencode "bboxSR=4326" \
  --data-urlencode "imageSR=32610" \
  --data-urlencode "size=${SIZE}" \
  --data-urlencode 'mosaicRule={"mosaicMethod":"esriMosaicLockRaster","lockRasterIds":[40]}' \
  --data-urlencode "format=tiff" \
  --data-urlencode "pixelType=U8" \
  --data-urlencode "noData=250" \
  --data-urlencode "interpolation=RSP_NearestNeighbor" \
  --data-urlencode "f=image" \
  -o "${LANDCOVER_FILE}"
ls -lh "${LANDCOVER_FILE}"

echo "3/3 Downloading USFS FIA Dominant Forest Type Group to ${FOREST_TYPE_FILE}..."
curl -sG "https://imagery.geoplatform.gov/iipp/rest/services/Vegetation/USFS_EDW_FIA_ForestAtlas_ForestTypeGroups_109_CONUS/ImageServer/exportImage" \
  --data-urlencode "bbox=${BBOX}" \
  --data-urlencode "bboxSR=4326" \
  --data-urlencode "imageSR=32610" \
  --data-urlencode "size=${SIZE}" \
  --data-urlencode "format=tiff" \
  --data-urlencode "pixelType=U16" \
  --data-urlencode "noData=0" \
  --data-urlencode "interpolation=RSP_NearestNeighbor" \
  --data-urlencode "f=image" \
  -o "${FOREST_TYPE_FILE}"
ls -lh "${FOREST_TYPE_FILE}"

echo "Done! All three forest/vegetation rasters downloaded."
