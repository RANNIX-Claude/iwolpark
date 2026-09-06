#!/bin/bash
# Reconstruye los archivos que .gitignore excluye y sin los cuales un clon
# limpio NO puede desplegar a producción: .env.prod2 y .prod2_version.
#
# Existe por un fallo silencioso: deploy_prod2.sh hace
# CURRENT=$(cat .prod2_version || echo 0) y publica CURRENT+1 en la tabla
# versiones_app. Si el archivo no está, publica v1 en una plaza cuyas
# tablets corren v101 — nunca ven una versión mayor, la actualización
# forzada deja de dispararse y nadie se entera hasta que un cajero opera
# con código viejo. El contador no se adivina: se lee del servidor.
#
# De dónde sale la anon key de PROD2 (decisión, no accidente):
# antes vivía embebida en corporativo.html, el único HTML versionado con
# credenciales reales. Ese archivo ya se normalizó a QA como los demás, así
# que el repositorio limpio ya no contiene la key — que es justo lo que se
# buscaba. El script la busca, en orden, en:
#   1. la variable de entorno PROD2_SUPABASE_KEY (para correrlo sin manos)
#   2. cualquier HTML del directorio que todavía apunte a PROD2
#      (*_PRODUCCION.html, o un clon viejo con corporativo.html sin normalizar)
#   3. captura interactiva, pegándola del dashboard de Supabase
#      (Project Settings → API → anon public)
# A propósito NO se saca del historial de git: ahí quedó la key expuesta y
# depender de ella volvería permanente la exposición; además, el día que se
# rote, el valor del historial ya no sirve y el dashboard sí.
#
# No despliega nada. Correr desde Git Bash en Windows.
set -e
cd "$(dirname "$0")"

PROD2_REF="syryisrelcjgdulxmgro"          # proyecto Supabase de iwol.click
PROD2_URL_DEFAULT="https://${PROD2_REF}.supabase.co"
ENV_FILE=".env.prod2"
VER_FILE=".prod2_version"

# ---------------------------------------------------------------------------
# 0. .gitignore primero: nunca crear un archivo con credenciales reales en un
#    árbol donde git lo vaya a ver. Se revalida al final, por si alguien edita
#    .gitignore mientras tanto.
# ---------------------------------------------------------------------------
verificar_gitignore() {
  local faltantes=""
  for f in "$ENV_FILE" "$VER_FILE"; do
    if git rev-parse --git-dir >/dev/null 2>&1; then
      git check-ignore -q "$f" 2>/dev/null || faltantes="$faltantes $f"
    else
      grep -qxF "$f" .gitignore 2>/dev/null || faltantes="$faltantes $f"
    fi
  done
  if [ -n "$faltantes" ]; then
    echo "ABORTA: .gitignore no cubre:$faltantes"
    echo "Agrégalos antes de continuar — si no, el próximo 'git add -A' commitea"
    echo "las credenciales de producción a un repositorio público."
    exit 1
  fi
}
verificar_gitignore
echo "[1/4] .gitignore cubre $ENV_FILE y $VER_FILE"

# ---------------------------------------------------------------------------
# 1. .env.prod2
# ---------------------------------------------------------------------------
if [ -f "$ENV_FILE" ]; then
  echo "[2/4] $ENV_FILE ya existe — no se toca."
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  if [ -z "$PROD2_SUPABASE_URL" ] || [ -z "$PROD2_SUPABASE_KEY" ]; then
    echo "ABORTA: $ENV_FILE existe pero le falta PROD2_SUPABASE_URL o PROD2_SUPABASE_KEY."
    echo "Bórralo y vuelve a correr este script para regenerarlo."
    exit 1
  fi
else
  PROD2_SUPABASE_URL="$PROD2_URL_DEFAULT"

  if [ -n "$PROD2_SUPABASE_KEY" ]; then
    echo "[2/4] Usando PROD2_SUPABASE_KEY del entorno."
  else
    # Un HTML que todavía apunte a PROD2 trae la key al lado de la URL.
    ORIGEN=""
    for f in *.html; do
      [ -f "$f" ] || continue
      grep -q "$PROD2_REF" "$f" || continue
      PROD2_SUPABASE_KEY=$(grep -o -E "eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+" "$f" | head -1)
      [ -n "$PROD2_SUPABASE_KEY" ] && { ORIGEN="$f"; break; }
    done
    if [ -n "$ORIGEN" ]; then
      echo "[2/4] Key de PROD2 recuperada de $ORIGEN"
    elif [ -t 0 ]; then
      echo "[2/4] No hay ninguna copia local de la key de PROD2."
      echo "      Supabase → proyecto $PROD2_REF → Project Settings → API → anon public"
      read -r -p "      URL  [$PROD2_URL_DEFAULT]: " RESP
      [ -n "$RESP" ] && PROD2_SUPABASE_URL="$RESP"
      read -r -s -p "      anon key (no se muestra al escribir): " PROD2_SUPABASE_KEY
      echo
    else
      echo "ABORTA: no encontré la anon key de PROD2 y no hay terminal para pedirla."
      echo "Corre el script a mano, o pásala así:"
      echo "  PROD2_SUPABASE_KEY='eyJ...' ./bootstrap_local.sh"
      exit 1
    fi
  fi

  if [ -z "$PROD2_SUPABASE_KEY" ]; then
    echo "ABORTA: key vacía. No se escribió nada."
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# 2. Comprobar las credenciales contra el servidor ANTES de escribir nada.
#    La misma consulta sirve para leer el contador, así que se hace una vez.
#    Se usa curl como en los scripts de deploy: no hay más dependencias.
# ---------------------------------------------------------------------------
echo "[3/4] Consultando versiones_app en $PROD2_SUPABASE_URL ..."
RESPUESTA=$(curl -s -w $'\n%{http_code}' \
  "${PROD2_SUPABASE_URL}/rest/v1/versiones_app?select=app,version" \
  -H "apikey: ${PROD2_SUPABASE_KEY}" \
  -H "Authorization: Bearer ${PROD2_SUPABASE_KEY}" || true)
CODIGO=$(printf '%s' "$RESPUESTA" | tail -n 1)
CUERPO=$(printf '%s' "$RESPUESTA" | sed '$d')

if [ "$CODIGO" != "200" ]; then
  echo "ABORTA: la consulta devolvió HTTP ${CODIGO:-sin respuesta}."
  echo "        $CUERPO"
  echo "Revisa la URL y la anon key. No se escribió ningún archivo."
  exit 1
fi

VERSION_SERVIDOR=$(printf '%s' "$CUERPO" \
  | grep -o -E '"version"[[:space:]]*:[[:space:]]*[0-9]+' \
  | grep -o -E '[0-9]+' | sort -n | tail -1)

if [ -z "$VERSION_SERVIDOR" ]; then
  echo "ABORTA: versiones_app respondió sin ninguna versión legible:"
  echo "        $CUERPO"
  echo "Si la tabla está vacía, aplica sql_versiones_app.sql y registra las apps"
  echo "antes de desplegar. No se escribió ningún archivo."
  exit 1
fi
echo "      versiones_app reporta v${VERSION_SERVIDOR} (máximo entre tablet/admin/corporativo)"

# Recién ahora, con las credenciales probadas, se persiste el .env.
if [ ! -f "$ENV_FILE" ]; then
  umask 077
  cat > "$ENV_FILE" <<EOF
# Credenciales de PRODUCCIÓN (iwol.click). NO versionar.
# Generado por bootstrap_local.sh
PROD2_SUPABASE_URL="${PROD2_SUPABASE_URL}"
PROD2_SUPABASE_KEY="${PROD2_SUPABASE_KEY}"
EOF
  chmod 600 "$ENV_FILE" 2>/dev/null || true
  echo "      $ENV_FILE escrito y verificado contra el servidor."
fi

# ---------------------------------------------------------------------------
# 3. .prod2_version
#    deploy_prod2.sh publica CURRENT+1. Para que las tablets vean una versión
#    mayor, el contador local nunca puede quedar por debajo del servidor.
# ---------------------------------------------------------------------------
if [ -f "$VER_FILE" ]; then
  VERSION_LOCAL=$(tr -cd '0-9' < "$VER_FILE")
  echo "[4/4] $VER_FILE ya existe (v${VERSION_LOCAL:-vacío}) — no se pisa."
  if [ -z "$VERSION_LOCAL" ] || [ "$VERSION_LOCAL" -lt "$VERSION_SERVIDOR" ]; then
    echo
    echo "  !! El contador local (${VERSION_LOCAL:-vacío}) es MENOR que el del servidor"
    echo "     (${VERSION_SERVIDOR}). Si despliegas así, deploy_prod2.sh anunciará una"
    echo "     versión que las tablets ya superaron y la actualización forzada"
    echo "     no se dispara. Corrígelo antes de desplegar:"
    echo "         echo ${VERSION_SERVIDOR} > ${VER_FILE}"
    echo
    exit 1
  fi
else
  echo "$VERSION_SERVIDOR" > "$VER_FILE"
  echo "[4/4] $VER_FILE escrito con v${VERSION_SERVIDOR} — el próximo deploy publicará v$((VERSION_SERVIDOR + 1))."
fi

verificar_gitignore

echo
echo "Listo. El clon ya puede desplegar a producción con ./deploy_prod2.sh"
echo "(valida antes con ./deploy_prod_preview.sh)."
echo
echo "Nota: el ambiente LEGADO (.env.prod / .prod_version, sitio"
echo "keen-chebakia-9df9bf) no se reconstruye aquí: su proyecto Supabase no"
echo "está registrado en el repositorio y sigue sin identificar."
