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
| Credenciales | `.env.prod2` → `PROD2_SUPABASE_URL`, `PROD2_SUPABASE_KEY` (**no versionado**) |
| Contador | `.prod2_version` (**no versionado**) |
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

Se reconstruyen desde el dashboard de Supabase (Project Settings → API) y desde la
tabla `versiones_app` de cada base.

### 🔴 Recuperar el contador ANTES del primer deploy

`deploy_prod2.sh` hace `CURRENT=$(cat .prod2_version || echo 0)` y escribe el
resultado a `versiones_app`, que es lo que dispara la actualización forzada en cada
terminal. Sin el archivo, el deploy publica **v1** y anuncia v1 a tablets que corren
v101: nunca ven una versión mayor y **la actualización forzada queda rota en
silencio, en la plaza del cliente**.

```sql
-- correr en el SQL Editor de la base destino
select app, version from versiones_app;
```
```bash
echo <version_real> > .prod2_version
```

**QA y Producción usan numeraciones independientes.** No son comparables entre sí.

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
| `corporativo.html` | Corporativo (PROD2) | nombre corto, solo iwol.click |
| `IwolPark_Dashboard_Cajeros.html` | Rendimiento de cajeros | productividad por operador |
| `IwolPark_Demanda.html` | Análisis de demanda | mapa de calor, embebido en iframe |
| `IwolPark_Promo_Admin.html` | Promociones | vouchers, toggle general |
| `IwolPark_Central.html` | Consola central | |

### Archivos duplicados a limpiar
`IwolPark_Dashboard_Corporativo - copia.html`, `IwolPark_Dashboard_Corporativo_.html`,
`IwolPark_Demanda-DESKTOP-HTN791F.html` — residuos de edición, no se despliegan.

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
**QA**. Correrlo desde un clon limpio instala QA en la caja del cliente. Para
producción hay que correr antes `generar_locales_produccion.sh` y copiar los
`*_PRODUCCION.html`. El instalador no lo advierte.

---

## Servidor MCP

`mcp-iwolpark/server.js` — servidor MCP para consultar y escribir la base vía anon
key. Configurado en `.mcp.json` apuntando a **QA**. Instalar con
`npm install --prefix mcp-iwolpark`.

---

## Seguridad

- Las anon keys son públicas por diseño (van al navegador). **La única defensa real
  es RLS en Supabase.** Cualquier tabla nueva necesita sus políticas.
- ⚠️ `corporativo.html` está versionado con las credenciales de **Producción
  (`syryisrelcjgdulxmgro`)**, no de QA como el resto. En un repositorio público.
  Revisar RLS de esa base y considerar normalizar el archivo al patrón de los demás.
- Nunca commitear `.env.prod`, `.env.prod2` ni archivos `*_PRODUCCION.html`.

---

## Reglas de Trabajo

1. **Ante la duda, el ambiente es QA.** Producción solo por `deploy_prod2.sh` y con
   `deploy_prod_preview.sh` validado antes.
2. **Nunca commitear credenciales de Producción.**
3. **Recuperar `.prod2_version` desde `versiones_app`** antes del primer deploy tras
   un clon nuevo.
4. **Aplicar los `sql_*.sql` en todos los ambientes**, no solo en QA.
5. **No romper el patrón de copia efímera** de los scripts de producción.
6. Las páginas se despliegan como archivos estáticos: **sin build, sin dependencias**.
