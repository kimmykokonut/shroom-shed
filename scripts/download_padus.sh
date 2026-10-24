#!/usr/bin/env bash
# scripts/download_padus.sh
# Downloads USGS PAD-US 3.0 Protected Areas / Public Land Ownership polygons
# for the Tillamook County, OR bounding box (-124.05, 45.05 to -123.30, 45.80)
# as EPSG:4326 GeoJSON into data/padus_tillamook.geojson.

set -euo pipefail

OUTPUT_FILE="data/padus_tillamook.geojson"
PADUS_QUERY_URL="https://services1.arcgis.com/CD5mKowwN6nIaqd8/arcgis/rest/services/PADUS3_0_PublicAccess/FeatureServer/0/query"

echo "Downloading PAD-US 3.0 polygons for Tillamook County to ${OUTPUT_FILE}..."

curl -sG "${PADUS_QUERY_URL}" \
  --data-urlencode "geometry=-124.05,45.05,-123.30,45.80" \
  --data-urlencode "geometryType=esriGeometryEnvelope" \
  --data-urlencode "inSR=4326" \
  --data-urlencode "outFields=Mang_Type,Mang_Name,Unit_Nm,Des_Tp,Pub_Access" \
  --data-urlencode "outSR=4326" \
  --data-urlencode "f=geojson" \
  -o "${OUTPUT_FILE}"

ls -lh "${OUTPUT_FILE}"
echo "Done!"
