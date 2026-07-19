#!/bin/bash
# Despliega el ambiente de PRODUCCIÓN (iwol.click) — misma app/código que QA,
# pero con las credenciales de un proyecto Supabase SEPARADO (base de datos
# propia, limpia de tickets/cortes/bitácora de prueba).
#
# No modifica ni commitea los archivos fuente (que se quedan con las
# credenciales de QA) — genera una copia efímera en una carpeta temporal,
# le sustituye ahí las credenciales y un aviso visual de "PRODUCCIÓN", y
# despliega solo esa copia. Requiere un archivo .env.prod (no versionado)
# con PROD_SUPABASE_URL y PROD_SUPABASE_KEY.
set -e
cd "$(dirname "$0")"

if [ ! -f .env.prod ]; then
  echo "Falta .env.prod con PROD_SUPABASE_URL y PROD_SUPABASE_KEY. No se desplegó nada."
  exit 1
fi
source .env.prod
if [ -z "$PROD_SUPABASE_URL" ] || [ -z "$PROD_SUPABASE_KEY" ]; then
  echo ".env.prod existe pero falta PROD_SUPABASE_URL o PROD_SUPABASE_KEY."
  exit 1
fi

PROD_SITE_ID="57993770-172d-45f4-8fdd-8fe43338e736"   # keen-chebakia-9df9bf / iwol.click
QA_URL="https://gbciwuprgrzllagtlqij.supabase.co"
QA_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiY2l3dXByZ3J6bGxhZ3RscWlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ0NDMzNzcsImV4cCI6MjEwMDAxOTM3N30.vmFhOv4eI3atO4TmBP5rEN-zz1mpXDLlKbxaaYPsm3o"

CURRENT=$(cat .prod_version 2>/dev/null || echo 0)
NEXT=$((CURRENT + 1))
echo "$NEXT" > .prod_version

BUILD_DIR=$(mktemp -d)
PAGES="IwolPark_Index.html IwolPark_TABLET.html IwolPark_Dashboard_Admin.html IwolPark_Dashboard_Corporativo.html IwolPark_Pensiones.html IwolPark_Demanda.html"
EXTRA="manifest_tablet.json manifest_admin.json manifest_corporativo.json sw.js"

for f in $PAGES $EXTRA; do
  [ -f "$f" ] && cp "$f" "$BUILD_DIR/"
done

for f in $PAGES; do
  target="$BUILD_DIR/$f"
  # Version + credenciales de Producción
  sed -i -E "s/(id=\"app-version\"[^>]*>)v[0-9]+</\1v${NEXT}</" "$target"
  sed -i "s#${QA_URL}#${PROD_SUPABASE_URL}#g" "$target"
  sed -i "s#${QA_KEY}#${PROD_SUPABASE_KEY}#g" "$target"
  # Aviso visual permanente para nunca confundir el ambiente
  BANNER='<div style="position:fixed;top:0;left:0;right:0;background:#D93025;color:#fff;text-align:center;font-size:11px;font-weight:800;padding:3px;z-index:999999;letter-spacing:1px">PRODUCCIÓN</div>'
  sed -i "s|<body>|<body>${BANNER}|" "$target"
done

netlify deploy --prod --dir="$BUILD_DIR" --site="$PROD_SITE_ID"

rm -rf "$BUILD_DIR"
echo "Producción v${NEXT} desplegada a iwol.click"
