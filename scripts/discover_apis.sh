#!/usr/bin/env bash
# scripts/discover_apis.sh
# Record of API discovery curl requests used to look up iNaturalist place IDs
# and inspect the USGS PAD-US 3.0 FeatureServer schema for Tillamook County, OR.

set -euo pipefail

echo ""
echo "=== 1. Lookup iNaturalist place_id for Tillamook, OR ==="
curl -s "https://api.inaturalist.org/v1/places/autocomplete?q=Tillamook" \
  | python3 -c "import sys, json; data = json.load(sys.stdin); print('\n'.join(f'{p[\"id\"]}: {p[\"display_name\"]}' for p in data['results'][:5]))"

echo ""
echo "=== 2. Check total verifiable Fungi (taxon_id=47170) observations in Tillamook County (place_id=494) ==="
curl -s "https://api.inaturalist.org/v1/observations?taxon_id=47170&place_id=494&verifiable=true&per_page=1" \
  | python3 -c "import sys, json; d = json.load(sys.stdin); print('Tillamook County fungi count:', d['total_results'])"

echo ""
echo "=== 3. Search ArcGIS Online for public PAD-US Feature Services ==="
curl -s "https://www.arcgis.com/sharing/rest/search?q=PADUS+type:%22Feature+Service%22&f=json" \
  | python3 -c "import sys, json; d = json.load(sys.stdin); print('\n'.join(f'{r[\"title\"]} -> {r.get(\"url\")}' for r in d.get('results', [])[:10]))"

echo ""
echo "=== 4. List distinct PAD-US 3.0 land managers and units in Tillamook County bounding box (-124.05,45.05,-123.30,45.80) ==="
curl -s "https://services1.arcgis.com/CD5mKowwN6nIaqd8/arcgis/rest/services/PADUS3_0_PublicAccess/FeatureServer/0/query?geometry=-124.05,45.05,-123.30,45.80&geometryType=esriGeometryEnvelope&inSR=4326&outFields=Mang_Type,Mang_Name,Unit_Nm,Des_Tp,Pub_Access&returnGeometry=false&f=json" \
  | python3 -c "import sys, json; d = json.load(sys.stdin); feats = d.get('features', []); print(f'Total features: {len(feats)}'); print('\n'.join(sorted(set(f\"{f['attributes']['Mang_Type']} | {f['attributes']['Mang_Name']} | {f['attributes']['Unit_Nm']}\" for f in feats))))"

echo ""
echo "=== 5. Lookup iNaturalist taxon_id and Tillamook County (place_id=494) counts for Target Foraging Genera ==="
for GENUS in Cantharellus Craterellus Boletus Pleurotus Hydnum Tricholoma Sparassis Hericium Laetiporus Morchella; do
  TAXON_INFO=$(curl -s "https://api.inaturalist.org/v1/taxa?q=${GENUS}&rank=genus&per_page=1" \
    | python3 -c "import sys, json; r = json.load(sys.stdin)['results'][0]; print(f\"{r['id']}|{r['name']}|{r.get('preferred_common_name', '')}\")")
  TAXON_ID=$(echo "${TAXON_INFO}" | cut -d'|' -f1)
  COUNT=$(curl -s "https://api.inaturalist.org/v1/observations?taxon_id=${TAXON_ID}&place_id=494&verifiable=true&per_page=1" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['total_results'])")
  echo "  ${TAXON_INFO} -> ${COUNT} sightings in Tillamook County"
done

echo ""
echo "=== 6. Search ArcGIS / USFS / USGS ImageServers for NLCD Tree Canopy & Land Cover ==="
curl -sG "https://www.arcgis.com/sharing/rest/search" \
  --data-urlencode 'q=(NLCD OR "Tree Canopy" OR "Land Cover" OR "Forest Type") AND type:"Image Service"' \
  --data-urlencode "num=10" \
  --data-urlencode "f=json" \
  | python3 -c "import sys, json; d = json.load(sys.stdin); print('\n'.join(f'{r[\"title\"]} ({r.get(\"owner\")}) -> {r.get(\"url\")}' for r in d.get('results', [])))"

echo ""
echo "=== 7. Check latest year OBJECTID in USFS GeoPlatform Canopy & Landcover ImageServices ==="
for SVC in USFS_EDW_NLCD_TCC_CONUS USFS_EDW_NLCD_Landcover_CONUS; do
  echo "--- ${SVC} catalog items ---"
  curl -sG "https://imagery.geoplatform.gov/iipp/rest/services/Vegetation/${SVC}/ImageServer/query" \
    --data-urlencode "where=1=1" \
    --data-urlencode "outFields=*" \
    --data-urlencode "returnGeometry=false" \
    --data-urlencode "f=json" \
    | python3 -c "import sys, json; d = json.load(sys.stdin); feats = d.get('features', []); print('Total slices:', len(feats)); print('First:', feats[0]['attributes'] if feats else None); print('Last:', feats[-1]['attributes'] if feats else None)"
done

echo ""
echo "=== 8. Inspect Legend (Category Codes) for Forest Type Groups & Land Cover ==="
for SVC in USFS_EDW_FIA_ForestAtlas_ForestTypeGroups_109_CONUS USFS_EDW_NLCD_Landcover_CONUS; do
  echo "--- ${SVC} Legend ---"
  curl -sG "https://imagery.geoplatform.gov/iipp/rest/services/Vegetation/${SVC}/ImageServer/legend" \
    --data-urlencode "f=json" \
    | python3 -c "import sys, json; d = json.load(sys.stdin); layers = d.get('layers', []); print('\n'.join(f\"{item.get('values', item.get('label'))}: {item.get('label')}\" for l in layers for item in l.get('legend', [])))"
done

echo ""
echo "=== 9. Inspect USFS MVUM Roads (EDW_MVUM_01/MapServer/1) & Oregon Forestry Roads in Tillamook County ==="
curl -sG "https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_MVUM_01/MapServer/1/query" \
  --data-urlencode "geometry=-124.05,45.05,-123.30,45.80" \
  --data-urlencode "geometryType=esriGeometryEnvelope" \
  --data-urlencode "inSR=4326" \
  --data-urlencode "outFields=*" \
  --data-urlencode "returnGeometry=false" \
  --data-urlencode "f=json" \
  | python3 -c "import sys, json; d = json.load(sys.stdin); feats = d.get('features', []); print('USFS MVUM Roads in Tillamook bbox:', len(feats)); print('Sample attributes:', feats[0]['attributes'] if feats else None)"

echo "--- ODF Mainline_TMA_Roads_view & Open Surfaced North_Coast_Roads ---"
curl -sG "https://services.arcgis.com/uUvqNMGPm7axC2dD/arcgis/rest/services/Mainline_TMA_Roads_view/FeatureServer/0/query" \
  --data-urlencode "geometry=-124.05,45.05,-123.30,45.80" \
  --data-urlencode "geometryType=esriGeometryEnvelope" \
  --data-urlencode "inSR=4326" \
  --data-urlencode "outFields=*" \
  --data-urlencode "returnGeometry=false" \
  --data-urlencode "f=json" \
  | python3 -c "import sys, json; d = json.load(sys.stdin); feats = d.get('features', []); print('Mainline_TMA_Roads_view count:', len(feats)); print('Sample:', feats[0]['attributes'] if feats else d)"

echo "--- Check Public Highways, County Roads, Mainlines & Collectors in ODF North_Coast_Roads ---"
curl -sG "https://services.arcgis.com/uUvqNMGPm7axC2dD/arcgis/rest/services/North_Coast_Roads/FeatureServer/0/query" \
  --data-urlencode "geometry=-124.05,45.05,-123.30,45.80" \
  --data-urlencode "geometryType=esriGeometryEnvelope" \
  --data-urlencode "inSR=4326" \
  --data-urlencode "where=Status='O' AND Surface='Surfaced' AND Ownership IN ('ODF','USFS','BLM','CNTY','STATE','FED') AND Class IN ('A','P','M','C')" \
  --data-urlencode "outFields=Ownership,Class,Official_N" \
  --data-urlencode "returnGeometry=false" \
  --data-urlencode "f=json" \
  | python3 -c "import sys, json; from collections import Counter; d = json.load(sys.stdin); feats = d.get('features', []); print('Public Arterials/Paved/Mainlines/Collectors:', len(feats)); print(Counter((f['attributes']['Ownership'], f['attributes']['Class']) for f in feats)); print('Sample Highway/County/Forest names:', sorted({f['attributes']['Official_N'].strip() for f in feats if f['attributes']['Official_N'].strip()})[:30])"

echo "--- Check USFS Recreation Sites / Trailheads (EDW_InfraRecreationSites_01/MapServer/0) ---"
curl -sG "https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_InfraRecreationSites_01/MapServer/0/query" \
  --data-urlencode "geometry=-124.05,45.05,-123.30,45.80" \
  --data-urlencode "geometryType=esriGeometryEnvelope" \
  --data-urlencode "inSR=4326" \
  --data-urlencode "outFields=*" \
  --data-urlencode "returnGeometry=false" \
  --data-urlencode "f=json" \
  | python3 -c "import sys, json; d = json.load(sys.stdin); feats = d.get('features', []); print('USFS Rec/Trailhead sites:', len(feats)); print('\n'.join(str(f['attributes']) for f in feats[:5]))"

echo "--- Check ODF Trailheads & Recreation Points ---"
curl -sG "https://services.arcgis.com/uUvqNMGPm7axC2dD/arcgis/rest/services/StateForests_RecreationPtsOregonGOV_PublicView/FeatureServer/0/query" \
  --data-urlencode "geometry=-124.05,45.05,-123.30,45.80" \
  --data-urlencode "geometryType=esriGeometryEnvelope" \
  --data-urlencode "inSR=4326" \
  --data-urlencode "outFields=*" \
  --data-urlencode "returnGeometry=false" \
  --data-urlencode "f=json" \
  | python3 -c "import sys, json; d = json.load(sys.stdin); feats = d.get('features', []); print('ODF Recreation/Trailhead points in Tillamook:', len(feats)); print('\n'.join(str(f['attributes']) for f in feats[:10]))"
