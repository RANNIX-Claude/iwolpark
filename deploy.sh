#!/bin/bash
# Despliega el ambiente de QA (iwolpark-qa.netlify.app) — usa el proyecto
# Supabase de siempre (knaibgqehwvjuclsfdmo), con todos los datos históricos
# y de prueba. Para Producción (iwol.click, base de datos separada) usa
# deploy_prod.sh en vez de este. Bumps VERSION, stamps it into every page's
# nav badge, commits, pushes, and deploys. Run from the project root.
set -e
cd "$(dirname "$0")"

QA_SITE_ID="4aa186ce-8fe5-4a51-9ce3-2b90736d00c8"   # iwolpark-qa

CURRENT=$(cat VERSION 2>/dev/null || echo 0)
NEXT=$((CURRENT + 1))
echo "$NEXT" > VERSION

PAGES="IwolPark_Index.html IwolPark_TABLET.html IwolPark_Dashboard_Admin.html IwolPark_Dashboard_Corporativo.html IwolPark_Pensiones.html IwolPark_Demanda.html IwolPark_Dashboard_Cajeros.html"
for f in $PAGES; do
  sed -i -E "s/(id=\"app-version\"[^>]*>)v[0-9]+</\1v${NEXT}</" "$f"
done

git add -A
git commit -m "Deploy v${NEXT}"
git push

netlify deploy --prod --dir=. --site="$QA_SITE_ID"

echo "Deployed v${NEXT} a QA (iwolpark-qa.netlify.app)"
