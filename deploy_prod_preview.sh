#!/bin/bash
# Despliega una VISTA PREVIA de Producción — mismo código y mismas
# credenciales reales de Supabase Producción que deploy_prod.sh, pero SIN
# el flag --prod: Netlify genera una URL única de preview y NO toca el
# dominio real iwol.click. Así se puede probar contra datos reales de
# Producción sin arriesgar/reemplazar lo que el cliente está usando ahora.
#
# Requiere el mismo .env.prod que deploy_prod.sh (PROD_SUPABASE_URL /
# PROD_SUPABASE_KEY). No modifica .prod_version (no cuenta como release
# oficial), no commitea nada.
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

# Solo para etiquetar el banner — no toca .prod_version (esto no es un
# release oficial de Producción, es una copia de prueba).
QA_VERSION=$(grep -oE '>v[0-9]+</span>' IwolPark_TABLET.html | grep -oE '[0-9]+' | head -1)
LABEL="v${QA_VERSION}-preview"

BUILD_DIR=$(mktemp -d)
PAGES="IwolPark_Index.html IwolPark_TABLET.html IwolPark_Dashboard_Admin.html IwolPark_Dashboard_Corporativo.html IwolPark_Pensiones.html IwolPark_Demanda.html"
EXTRA="manifest_tablet.json manifest_admin.json manifest_corporativo.json sw.js"

for f in $PAGES $EXTRA; do
  [ -f "$f" ] && cp "$f" "$BUILD_DIR/"
done

for f in $PAGES; do
  target="$BUILD_DIR/$f"
  sed -i -E "s/(id=\"app-version\"[^>]*>)v[0-9]+</\1${LABEL}</" "$target"
  sed -i "s#${QA_URL}#${PROD_SUPABASE_URL}#g" "$target"
  sed -i "s#${QA_KEY}#${PROD_SUPABASE_KEY}#g" "$target"
  # Banner distinto al de producción real, para no confundir con el sitio live
  BANNER='<div style="position:fixed;top:0;left:0;right:0;background:#BA7517;color:#fff;text-align:center;font-size:11px;font-weight:800;padding:3px;z-index:999999;letter-spacing:1px">PRODUCCIÓN · VISTA PREVIA '"${LABEL}"' · NO ES EL SITIO EN VIVO</div>'
  sed -i "s|<body>|<body>${BANNER}|" "$target"
done

echo "Desplegando vista previa (sin --prod, no reemplaza iwol.click)..."
netlify deploy --dir="$BUILD_DIR" --site="$PROD_SITE_ID"

rm -rf "$BUILD_DIR"
echo "Vista previa ${LABEL} lista — usa la 'Unique deploy URL' de arriba (no la Production URL) para probarla. iwol.click sigue intacto."
