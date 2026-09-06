# CLAUDE.md — IwolPark
## Sistema de Estacionamiento · Plaza IWOL, Metepec, Edo. de México
## RANNIX Consulting

---

## Identidad del Proyecto

**IwolPark** es el sistema operativo de estacionamiento de Plaza IWOL: control de
entradas/salidas, cobro en caja, pensionados, promociones y analítica de demanda.

Arquitectura deliberadamente simple: **HTML monolítico por pantalla**, sin build,
sin framework, sin bundler. Cada archivo `.html` es una aplicación completa y
autocontenida (HTML + CSS + JS + credenciales Supabase embebidas) que se abre con
doble clic desde `C:\Park\files` o se sirve estática desde Netlify.

Esto es intencional: las cajas de la plaza son máquinas Windows con Chrome en modo
kiosco e impresora térmica POS-58. No hay Node ni servidor local en sitio.

Desarrollado por **Roberto Aguilar Cota / RANNIX Consulting**.

---

## ⚠️ AMBIENTES — LEER ANTES DE CUALQUIER DEPLOY

Existen **tres** sitios Netlify y **tres** proyectos Supabase distintos. Confundirlos
significa escribir datos de prueba en la base real del cliente.

### 🟢 QA / Control de Calidad
| | |
|---|---|
| Supabase | `gbciwuprgrzllagtlqij` |
| URL BD | `https://gbciwuprgrzllagtlqij.supabase.co` |
| Netlify | `iwolpark-qa.netlify.app` |
| Site ID | `4aa186ce-8fe5-4a51-9ce3-2b90736d00c8` |
| Deploy | `./deploy.sh` |
| Credenciales | **Embebidas en los `.html` del repositorio** |
| Contador | `VERSION` (versionado en git) |
| Banner | ninguno |

Réplica del esquema de Producción. Es el ambiente por defecto: todo archivo fuente
del repo apunta aquí. Trabajar en local = trabajar contra QA.

### 🟣 PRODUCCIÓN REAL — `iwol.click`
| | |
|---|---|
| Supabase | `syryisrelcjgdulxmgro` |
| URL BD | `https://syryisrelcjgdulxmgro.supabase.co` |
| Netlify | `iwolpark-produccion2.netlify.app` → **iwol.click** |
| Site ID | `0143f712-153f-4afd-919b-7cde0a300ce9` |
| Deploy | `./deploy_prod2.sh` |
| Credenciales | `.env.prod2` → `PROD2_SUPABASE_URL`, `PROD2_SUPABASE_KEY` (**no versionado**, se reconstruye con `./bootstrap_local.sh`) |
| Contador | `.prod2_version` (**no versionado**, idem) |
| Banner | morado `#5E3B9C` — "PRODUCCIÓN (COPIA PARALELA · SERVIDOR PROPIO)" |

**Este es el sistema en vivo del cliente.** Datos reales de operación.

### ⚪ Producción original — LEGADO, sin dominio
| | |
|---|---|
| Supabase | solo en `.env.prod` (ref no registrado en el repo) |
| Netlify | `keen-chebakia-9df9bf.netlify.app` |
| Site ID | `57993770-172d-45f4-8fdd-8fe43338e736` |
| Deploy | `./deploy_prod.sh` · vista previa: `./deploy_prod_preview.sh` |
| Banner | rojo `#D93025` — "PRODUCCIÓN" |

El **25-jul-2026** el dominio `iwol.click` se movió de aquí a `iwolpark-produccion2`.
Este sitio ya no tiene usuarios. No desplegar sin revisar antes si sigue vivo.

### Identificación visual en pantalla
| Banner | Ambiente |
|---|---|
| sin banner | QA |
| 🟣 morado | **iwol.click — producción real** |
| 🔴 rojo | producción legado (o copia local de producción) |
| 🟠 naranja | vista previa de producción |

`IwolPark_Demanda.html` nunca lleva banner: siempre va embebida en `<iframe>` dentro
de Admin/Corporativo, que ya traen el suyo.

---

## Archivos NO versionados (`.gitignore`)

Un `git clone` limpio **no** puede desplegar a producción. Falta:

```
.env.prod          credenciales Supabase producción legado
.env.prod2         credenciales Supabase iwol.click
.prod_version      contador de versión legado
.prod2_version     contador de versión iwol.click
*_PRODUCCION.html  copias locales con credenciales reales
```

Para PROD2 esto ya no se hace a mano:

```bash
./bootstrap_local.sh   # escribe .env.prod2 y .prod2_version, no despliega nada
```

El script pide la anon key (o la toma de `PROD2_SUPABASE_KEY`, o de un
`*_PRODUCCION.html` local que aún la tenga), la **valida contra el servidor antes
de escribir nada**, y saca el contador de `versiones_app`. Es idempotente: si un
archivo ya existe no lo pisa, y aborta si `.gitignore` no cubre ambos.

El ambiente **legado** (`.env.prod`, `.prod_version`) sigue siendo manual: su
proyecto Supabase no está registrado en el repo (ver Pendientes).

### 🔴 Recuperar el contador ANTES del primer deploy

`deploy_prod2.sh` hace `CURRENT=$(cat .prod2_version || echo 0)` y escribe el
resultado a `versiones_app`, que es lo que dispara la actualización forzada en cada
terminal. Sin el archivo, el deploy publica **v1** y anuncia v1 a tablets que corren
v101: nunca ven una versión mayor y **la actualización forzada queda rota en
silencio, en la plaza del cliente**.

`bootstrap_local.sh` existe para que esto no dependa de que alguien se acuerde. A
mano, el equivalente es:

```sql
-- correr en el SQL Editor de la base destino
select app, version from versiones_app;
```
```bash
echo <version_real> > .prod2_version
```

**QA y Producción usan numeraciones independientes.** No son comparables entre sí.
Al 06-sep-2026: QA `VERSION` = 187, PROD2 `versiones_app` = 101 en las tres apps.

---

## Aplicaciones

| Archivo | Rol | Uso |
|---|---|---|
| `IwolPark_Index.html` | Portal de acceso | raíz del sitio (ver `netlify.toml`) |
| `IwolPark_TABLET.html` | **Cajero** | caja, Chrome `--kiosk-printing`, POS-58 |
| `IwolPark_Pensiones.html` | Pensionados | alta, cobranza, semáforo de vigencia |
| `IwolPark_Dashboard_Admin.html` | Admin de plaza | KPIs, movimientos, reportes |
| `IwolPark_Admin_Movil.html` | Admin móvil | versión responsiva |
| `IwolPark_Dashboard_Corporativo.html` | Corporativo | consolidado |
| `corporativo.html` | Corporativo (PROD2) | nombre corto, solo iwol.click; se despliega únicamente por `deploy_prod2.sh` |
| `IwolPark_Dashboard_Cajeros.html` | Rendimiento de cajeros | productividad por operador |
| `IwolPark_Demanda.html` | Análisis de demanda | mapa de calor, embebido en iframe |
| `IwolPark_Promo_Admin.html` | Promociones | vouchers, toggle general |
| `IwolPark_Central.html` | Consola central | |

### Archivos duplicados — eliminados (06-sep-2026)
`IwolPark_Dashboard_Corporativo - copia.html`, `IwolPark_Dashboard_Corporativo_.html`
y `IwolPark_Demanda-DESKTOP-HTN791F.html` eran residuos de edición sin una sola
referencia en el repo. Se borraron; siguen en el historial de git si hiciera falta
rescatar algo (`git log -- "<archivo>"`). Nota: `deploy.sh` despliega `--dir=.`, así
que mientras existieron se publicaban al sitio de QA sin que nadie los usara.

---

## Base de Datos

`IwolPark_schema.sql` define el esquema base:

**Dimensiones** — `dim_plaza`, `dim_tipo_boleto`, `dim_tiempo`
**Operación** — `cajeros`, `turnos`, `fact_operacion`, `sync_queue`
**Tarifas** — `tarifas_historico` → vista `v_tarifas_vigentes`
**Pensiones** — `clientes`, `vehiculos`, `pensiones`, `pagos_pension`
**Vistas KPI** — `v_kpi_dia`, `v_kpi_franja`, `v_kpi_cajero`, `v_resumen_mensual`,
`v_pensiones_estado`, `v_cobranza_mes`

### Migraciones incrementales
No hay herramienta de migraciones. Son scripts sueltos que se corren **a mano en el
SQL Editor de cada ambiente**, en orden, y hay que aplicarlos en QA **y** en cada
base de Producción:

| Script | Qué agrega |
|---|---|
| `sql_versiones_app.sql` | tabla `versiones_app` — control de versión por app |
| `sql_avisos_operador.sql` | avisos del Admin a cajeros |
| `sql_avisos_chat.sql` | respuesta del cajero al aviso |
| `sql_bitacora_ip.sql` | columna IP en bitácora |
| `sql_folio_salida.sql` | folio de salida `S-AAMMDDNNN` |
| `sql_pension_id_tickets.sql` | pensión con vehículo dentro, en vivo |
| `sql_pension_id_fk.sql` | FK real de `pension_id` (PostgREST la requiere) |
| `sql_empleado_id.sql` | boleto activo por empleado |
| `sql_historico_mensual.sql` | hechos: histórico mensual de ingresos |
| `sql_promo_migracion.sql` | módulo de Promociones |
| `sql_promociones_toggle.sql` | interruptor general de Promociones |

⚠️ **Deriva de esquema**: al no estar automatizado, QA y Producción pueden divergir.
Verificar que el script esté aplicado en destino antes de desplegar código que lo use.

---

## Control de versión de apps

Cada `.html` trae `verificarVersionServidor()`: al iniciar sesión consulta
`versiones_app` y, si el servidor tiene una versión mayor, obliga a actualizar.

El flujo de `deploy.sh` / `deploy_prod2.sh`:
1. incrementa el contador
2. estampa `vN` en `id="app-version"` de cada página vía `sed`
3. despliega a Netlify
4. hace `POST` a `versiones_app` con `on_conflict=app` para `tablet`, `admin`, `corporativo`

Romper cualquiera de esos cuatro pasos rompe la actualización forzada.

---

## Deploy

```bash
./bootstrap_local.sh       # Reconstruye .env.prod2 y .prod2_version en un clon limpio. No despliega.
./deploy.sh                # QA — commitea, pushea y despliega. Bumpea VERSION.
./deploy_prod_preview.sh   # URL única de preview con credenciales reales. No toca el sitio vivo.
./deploy_prod2.sh          # PRODUCCIÓN iwol.click. Requiere .env.prod2 + .prod2_version.
./generar_locales_produccion.sh   # copias *_PRODUCCION.html para abrir sin internet
```

**Regla**: los scripts de producción **nunca** modifican ni commitean los archivos
fuente. Copian a un `mktemp -d`, sustituyen credenciales ahí y despliegan solo esa
copia efímera. Los fuentes se quedan siempre con credenciales de QA. Mantener esa
propiedad en cualquier cambio a los scripts.

Son bash con `sed -i` y `mktemp`: en Windows correrlos desde **Git Bash**, no CMD ni
PowerShell.

---

## Instalación en máquinas de la plaza

`INSTALAR_IWOLPARK.bat` copia los HTML a `C:\Park\files`, crea `ABRIR_CAJERO.bat`
(Chrome `--kiosk-printing`), `ABRIR_ADMIN.bat` y `ABRIR_PENSIONES.bat`, pone iconos
en el escritorio y configura la impresora POS-58 como predeterminada.

NIPs default: cajero `1111`, admin `111111` — cambiar en parámetros tras instalar.

⚠️ **El `.bat` copia los HTML del directorio donde está**, que traen credenciales de
**QA**. Correrlo desde un clon limpio instala QA en la caja del cliente: la caja
cobra, imprime y cuadra, pero contra la base de pruebas.

Desde el 06-sep-2026 el instalador lo detecta. Antes de copiar nada busca el ref de
QA (`gbciwuprgrzllagtlqij`) en los HTML de su carpeta y, si lo encuentra, muestra la
advertencia y exige que se escriba `INSTALAR-QA` para continuar; cualquier otra cosa
cancela sin copiar. Si encuentra el ref de PROD2 lo anuncia como producción. Para
instalar producción: correr `generar_locales_produccion.sh`, quitar el sufijo
`_PRODUCCION` de los nombres en una carpeta aparte, y correr el instalador desde ahí.

---

## Servidor MCP

`mcp-iwolpark/server.js` — servidor MCP para consultar y escribir la base vía anon
key. Configurado en `.mcp.json` apuntando a **QA**. Instalar con
`npm install --prefix mcp-iwolpark`.

---

## Seguridad

- Las anon keys son públicas por diseño (van al navegador). **La única defensa real
  es RLS en Supabase.** Cualquier tabla nueva necesita sus políticas.
- ⚠️ **La anon key de Producción estuvo expuesta en este repositorio.**
  `corporativo.html` era el único de los 13 HTML versionado con credenciales de
  **Producción (`syryisrelcjgdulxmgro`)** en vez de QA. Se normalizó a QA el
  06-sep-2026, pero **la key sigue en el historial de git** (entró en el commit
  `928f8aa`, "Conectar Corporativo a Supabase productivo"): normalizar el archivo
  detiene la exposición hacia adelante, no la borra hacia atrás. Cualquiera con
  acceso al historial puede recuperarla. Mientras no se rote, **la única defensa de
  esa base es su RLS** — revisarla. Rotar la key es decisión del dueño y se hace en
  el dashboard de Supabase (ver Pendientes); si se rota, hay que regenerar
  `.env.prod2` (`rm .env.prod2 && ./bootstrap_local.sh`).
- Efecto colateral del arreglo: `deploy_prod2.sh` sustituye las credenciales de QA
  por las de PROD2 con `sed` sobre una copia efímera. Como `corporativo.html` ya
  traía PROD2 adentro, ese `sed` no encontraba nada que sustituir y el deploy
  funcionaba **por accidente**. Ahora sustituye de verdad.
- Nunca commitear `.env.prod`, `.env.prod2` ni archivos `*_PRODUCCION.html`.

---

## Reglas de Trabajo

1. **Ante la duda, el ambiente es QA.** Producción solo por `deploy_prod2.sh` y con
   `deploy_prod_preview.sh` validado antes.
2. **Nunca commitear credenciales de Producción.**
3. **Correr `./bootstrap_local.sh`** en todo clon nuevo antes del primer deploy a
   producción. Es lo que recupera `.prod2_version` desde `versiones_app`.
4. **Aplicar los `sql_*.sql` en todos los ambientes**, no solo en QA.
5. **No romper el patrón de copia efímera** de los scripts de producción.
6. **Todo archivo fuente apunta a QA**, sin excepciones. Si una página necesita otro
   ambiente, lo resuelve el script de deploy con su `sed`, nunca el archivo del repo.
7. Las páginas se despliegan como archivos estáticos: **sin build, sin dependencias**.

---

## Pendientes (sin resolver al 06-sep-2026)

- **Ref de Supabase del ambiente legado** — sigue sin identificar. Solo vivía en
  `.env.prod`, que no está versionado y se perdió. Sin él no se puede saber si esa
  base sigue viva ni desplegar a `keen-chebakia-9df9bf`. Se recupera del dashboard de
  Netlify (variables del sitio) o del de Supabase, comparando proyectos.
- **Rotar o no la anon key de Producción expuesta** — decisión del dueño, se ejecuta
  en Supabase. Ver Seguridad.
