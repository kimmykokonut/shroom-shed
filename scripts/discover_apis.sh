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
