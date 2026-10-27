#!/usr/bin/env bash
# scripts/download_dem.sh
# Downloads a USGS 3DEP Digital Elevation Model (DEM) GeoTIFF covering
# Tillamook County, OR (-124.05, 45.05 to -123.30, 45.80).
#
# We request the image directly in EPSG:32610 (WGS 84 / UTM Zone 10N, meters)
# at ~30m resolution (2000 x 2800 pixels) with 32-bit float elevation values (meters).
# Having both horizontal (X/Y) and vertical (Z) units in meters makes PostGIS
# ST_Slope() and ST_Aspect() calculations accurate without unit conversion hacks.

set -euo pipefail

OUTPUT_FILE="data/dem_tillamook_32610.tif"
USGS_3DEP_URL="https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/exportImage"

echo "Downloading USGS 3DEP DEM GeoTIFF for Tillamook County to ${OUTPUT_FILE}..."

curl -sG "${USGS_3DEP_URL}" \
  --data-urlencode "bbox=-124.05,45.05,-123.30,45.80" \
  --data-urlencode "bboxSR=4326" \
  --data-urlencode "imageSR=32610" \
  --data-urlencode "size=2000,2800" \
  --data-urlencode "format=tiff" \
  --data-urlencode "pixelType=F32" \
  --data-urlencode "noData=-9999" \
  --data-urlencode "interpolation=RSP_BilinearInterpolation" \
  --data-urlencode "f=image" \
  -o "${OUTPUT_FILE}"

ls -lh "${OUTPUT_FILE}"
echo "Done!"
