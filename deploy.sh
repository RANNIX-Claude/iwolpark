#!/bin/bash
# Bumps VERSION, stamps it into every page's nav badge, commits, pushes, and
# deploys to Netlify production. Run from the project root.
set -e
cd "$(dirname "$0")"

CURRENT=$(cat VERSION 2>/dev/null || echo 0)
NEXT=$((CURRENT + 1))
echo "$NEXT" > VERSION

PAGES="IwolPark_Index.html IwolPark_TABLET.html IwolPark_Dashboard_Admin.html IwolPark_Dashboard_Corporativo.html IwolPark_Pensiones.html IwolPark_Demanda.html"
for f in $PAGES; do
  sed -i -E "s/(id=\"app-version\"[^>]*>)v[0-9]+</\1v${NEXT}</" "$f"
done

git add -A
git commit -m "Deploy v${NEXT}"
git push

netlify deploy --prod --dir=.

echo "Deployed v${NEXT}"
