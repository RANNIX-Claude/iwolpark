#!/bin/bash
# Genera copias LOCALES persistentes (para abrir con doble clic, sin
# internet) con las credenciales de PRODUCCIÓN ya adentro. A diferencia de
# deploy_prod.sh (que genera una copia efímera solo para subir a Netlify),
# estos archivos SÍ se quedan guardados en esta carpeta.
#
# No se versionan en git (ver .gitignore) porque llevan las credenciales
# reales de producción embebidas. Requiere .env.prod (PROD_SUPABASE_URL /
# PROD_SUPABASE_KEY).
set -e
cd "$(dirname "$0")"

if [ ! -f .env.prod ]; then
  echo "Falta .env.prod con PROD_SUPABASE_URL y PROD_SUPABASE_KEY."
  exit 1
fi
source .env.prod

QA_URL="https://knaibgqehwvjuclsfdmo.supabase.co"
QA_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtuYWliZ3FlaHd2anVjbHNmZG1vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2MzEzNjcsImV4cCI6MjA5OTIwNzM2N30.CCUxpvi8IdAtxwx5PUBefstJvflmUabovE92IbotGvE"
BANNER='<div style="position:fixed;top:0;left:0;right:0;background:#D93025;color:#fff;text-align:center;font-size:11px;font-weight:800;padding:3px;z-index:999999;letter-spacing:1px">PRODUCCIÓN (LOCAL)</div>'

declare -A PARES=(
  ["IwolPark_TABLET.html"]="IwolPark_TABLET_PRODUCCION.html"
  ["IwolPark_Dashboard_Admin.html"]="IwolPark_Dashboard_Admin_PRODUCCION.html"
  ["IwolPark_Dashboard_Corporativo.html"]="IwolPark_Dashboard_Corporativo_PRODUCCION.html"
)

for origen in "${!PARES[@]}"; do
  destino="${PARES[$origen]}"
  cp "$origen" "$destino"
  sed -i "s#${QA_URL}#${PROD_SUPABASE_URL}#g" "$destino"
  sed -i "s#${QA_KEY}#${PROD_SUPABASE_KEY}#g" "$destino"
  sed -i "s|<body>|<body>${BANNER}|" "$destino"
  echo "Generado: $destino"
done

echo "Listo. Estos archivos NO se suben a git (credenciales reales adentro)."
