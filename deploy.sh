#!/bin/bash
# Despliega el ambiente de QA (iwolpark-qa.netlify.app) — usa el proyecto
# Supabase IWOL_QA (gbciwuprgrzllagtlqij), réplica exacta de Producción
# (esquema + datos reales, ver scratchpad de la sesión que lo generó).
# Para Producción (iwol.click, base de datos separada) usa
# deploy_prod.sh en vez de este. Bumps VERSION, stamps it into every page's
# nav badge, commits, pushes, and deploys. Run from the project root.
set -e
cd "$(dirname "$0")"

QA_SITE_ID="4aa186ce-8fe5-4a51-9ce3-2b90736d00c8"   # iwolpark-qa
QA_URL="https://gbciwuprgrzllagtlqij.supabase.co"
QA_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiY2l3dXByZ3J6bGxhZ3RscWlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ0NDMzNzcsImV4cCI6MjEwMDAxOTM3N30.vmFhOv4eI3atO4TmBP5rEN-zz1mpXDLlKbxaaYPsm3o"

CURRENT=$(cat VERSION 2>/dev/null || echo 0)
NEXT=$((CURRENT + 1))
echo "$NEXT" > VERSION

PAGES="IwolPark_Index.html IwolPark_TABLET.html IwolPark_Dashboard_Admin.html IwolPark_Dashboard_Corporativo.html IwolPark_Pensiones.html IwolPark_Demanda.html IwolPark_Dashboard_Cajeros.html IwolPark_Promo_Admin.html"
for f in $PAGES; do
  sed -i -E "s/(id=\"app-version\"[^>]*>)v[0-9]+</\1v${NEXT}</" "$f"
done

git add -A
git commit -m "Deploy v${NEXT}"
git push

netlify deploy --prod --dir=. --site="$QA_SITE_ID"

# Registra la nueva versión para que cada app la detecte al iniciar sesión
# y obligue a actualizar (ver verificarVersionServidor() en cada HTML).
for app in tablet admin corporativo; do
  curl -s -X POST "${QA_URL}/rest/v1/versiones_app?on_conflict=app" \
    -H "apikey: ${QA_KEY}" -H "Authorization: Bearer ${QA_KEY}" \
    -H "Content-Type: application/json" -H "Prefer: resolution=merge-duplicates" \
    -d "{\"app\":\"${app}\",\"version\":${NEXT}}" > /dev/null
done

echo "Deployed v${NEXT} a QA (iwolpark-qa.netlify.app)"
