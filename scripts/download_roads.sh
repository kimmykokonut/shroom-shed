#!/usr/bin/env bash
# scripts/download_roads.sh
# Downloads public drivable roads and official trailhead/recreation entry points
# across Tillamook County, OR (-124.05, 45.05 to -123.30, 45.80) in EPSG:4326 GeoJSON:
#   1. data/mvum_tillamook.geojson       -> USFS Motor Vehicle Use Map (MVUM) Roads (Siuslaw National Forest)
#   2. data/odf_roads_tillamook.geojson  -> ODF North Coast Public Open Surfaced Roads:
#                                           Includes State Highways (STATE/FED Class A/P, e.g. Hwy 6, Hwy 101, Hwy 53),
#                                           Paved County Roads (CNTY), and ODF/BLM/USFS Mainlines & Collectors (Class M/C),
#                                           while excluding Private Industrial (PI/PNI) gated timber roads!
#   3. data/trailheads_tillamook.geojson -> Official ODF State Forest Trailheads, Day-Use Parking, & Campgrounds

set -euo pipefail

BBOX="-124.05,45.05,-123.30,45.80"
MVUM_FILE="data/mvum_tillamook.geojson"
ODF_FILE="data/odf_roads_tillamook.geojson"
TRAILHEADS_FILE="data/trailheads_tillamook.geojson"

echo "1/3 Downloading USFS Motor Vehicle Use Map (MVUM) Roads to ${MVUM_FILE}..."
curl -sG "https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_MVUM_01/MapServer/1/query" \
  --data-urlencode "geometry=${BBOX}" \
  --data-urlencode "geometryType=esriGeometryEnvelope" \
  --data-urlencode "inSR=4326" \
  --data-urlencode "outFields=id,name,jurisdiction,surfacetype,mvum_symbol_name,operationalmaintlevel,seasonal,forestname,districtname" \
  --data-urlencode "outSR=4326" \
  --data-urlencode "f=geojson" \
  -o "${MVUM_FILE}"
ls -lh "${MVUM_FILE}"

echo "2/3 Downloading Public Highways, County Roads, & ODF/BLM Forest Mainlines/Collectors to ${ODF_FILE}..."
curl -sG "https://services.arcgis.com/uUvqNMGPm7axC2dD/arcgis/rest/services/North_Coast_Roads/FeatureServer/0/query" \
  --data-urlencode "geometry=${BBOX}" \
  --data-urlencode "geometryType=esriGeometryEnvelope" \
  --data-urlencode "inSR=4326" \
  --data-urlencode "where=Status='O' AND Surface='Surfaced' AND Ownership IN ('ODF','USFS','BLM','CNTY','STATE','FED') AND Class IN ('A','P','M','C')" \
  --data-urlencode "outFields=Official_N,Alt_Name,Road_Num,Ownership,Surface,Status,Class,District" \
  --data-urlencode "outSR=4326" \
  --data-urlencode "f=geojson" \
  -o "${ODF_FILE}"
ls -lh "${ODF_FILE}"

echo "3/3 Downloading Official ODF State Forest Trailheads, Day-Use & Campgrounds to ${TRAILHEADS_FILE}..."
curl -sG "https://services.arcgis.com/uUvqNMGPm7axC2dD/arcgis/rest/services/StateForests_RecreationPtsOregonGOV_PublicView/FeatureServer/0/query" \
  --data-urlencode "geometry=${BBOX}" \
  --data-urlencode "geometryType=esriGeometryEnvelope" \
  --data-urlencode "inSR=4326" \
  --data-urlencode "outFields=Title,State_forest,Layer_name,Activities,Amenities,Season,RecreationSitesStatus,Latitude,Longitude" \
  --data-urlencode "outSR=4326" \
  --data-urlencode "f=geojson" \
  -o "${TRAILHEADS_FILE}"
ls -lh "${TRAILHEADS_FILE}"

echo "Done! All road and trailhead GeoJSON files downloaded."
