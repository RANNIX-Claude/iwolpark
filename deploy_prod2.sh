#!/bin/bash
# Despliega la copia PARALELA de Producción (iwolpark-produccion2.netlify.app)
# — mismo código que Producción/QA, pero con las credenciales de un proyecto
# Supabase SEPARADO (syryisrelcjgdulxmgro), réplica exacta de la base real.
#
# NO reemplaza iwol.click ni el sitio de Producción original — es un
# ambiente aparte, en paralelo, mientras se decide el corte de dominio.
#
# No modifica ni commitea los archivos fuente. Requiere .env.prod2 (no
# versionado) con PROD2_SUPABASE_URL y PROD2_SUPABASE_KEY.
set -e
cd "$(dirname "$0")"

if [ ! -f .env.prod2 ]; then
  echo "Falta .env.prod2 con PROD2_SUPABASE_URL y PROD2_SUPABASE_KEY. No se desplegó nada."
  exit 1
fi
source .env.prod2
if [ -z "$PROD2_SUPABASE_URL" ] || [ -z "$PROD2_SUPABASE_KEY" ]; then
  echo ".env.prod2 existe pero falta PROD2_SUPABASE_URL o PROD2_SUPABASE_KEY."
  exit 1
fi

PROD2_SITE_ID="0143f712-153f-4afd-919b-7cde0a300ce9"   # iwolpark-produccion2
QA_URL="https://gbciwuprgrzllagtlqij.supabase.co"
QA_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiY2l3dXByZ3J6bGxhZ3RscWlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ0NDMzNzcsImV4cCI6MjEwMDAxOTM3N30.vmFhOv4eI3atO4TmBP5rEN-zz1mpXDLlKbxaaYPsm3o"

CURRENT=$(cat .prod2_version 2>/dev/null || echo 0)
NEXT=$((CURRENT + 1))
echo "$NEXT" > .prod2_version

BUILD_DIR=$(mktemp -d)
PAGES="IwolPark_Index.html IwolPark_TABLET.html IwolPark_Dashboard_Admin.html IwolPark_Dashboard_Corporativo.html IwolPark_Pensiones.html IwolPark_Demanda.html IwolPark_Dashboard_Cajeros.html IwolPark_Promo_Admin.html"
EXTRA="manifest_tablet.json manifest_admin.json manifest_corporativo.json sw.js"

for f in $PAGES $EXTRA; do
  [ -f "$f" ] && cp "$f" "$BUILD_DIR/"
done

for f in $PAGES; do
  target="$BUILD_DIR/$f"
  sed -i -E "s/(id=\"app-version\"[^>]*>)v[0-9]+</\1v${NEXT}</" "$target"
  sed -i "s#${QA_URL}#${PROD2_SUPABASE_URL}#g" "$target"
  sed -i "s#${QA_KEY}#${PROD2_SUPABASE_KEY}#g" "$target"
  # Aviso visual distinto (morado) para diferenciarlo tanto de QA como del
  # Producción original — es un tercer ambiente, no confundirlo con ninguno.
  BANNER='<div style="position:fixed;top:0;left:0;right:0;background:#5E3B9C;color:#fff;text-align:center;font-size:11px;font-weight:800;padding:3px;z-index:999999;letter-spacing:1px">PRODUCCIÓN (COPIA PARALELA · SERVIDOR PROPIO)</div>'
  sed -i "s|<body>|<body>${BANNER}|" "$target"
done

netlify deploy --prod --dir="$BUILD_DIR" --site="$PROD2_SITE_ID"

rm -rf "$BUILD_DIR"
echo "Producción paralela v${NEXT} desplegada a iwolpark-produccion2.netlify.app"
