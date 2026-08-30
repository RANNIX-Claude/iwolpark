# IwolPark — Sistema de control de estacionamiento

Plaza IWOL, Metepec, Estado de México. Desarrollado por **Roberto Aguilar Cota /
RANNIX Consulting**.

Sistema en producción real, cobrando dinero a clientes en `iwol.click`.
Cada módulo es **un solo archivo HTML autocontenido** (HTML + `<style>` + `<script>`
inline), servido estático desde Netlify y hablando directo a Supabase con la anon key
protegida por RLS. No hay backend propio, ni build step, ni `package.json` en la raíz.

La simplicidad es deliberada, no deuda: las cajas de la plaza son máquinas Windows con
Chrome en modo kiosco e impresora térmica POS-58. No hay Node ni servidor local en sitio.
Cada `.html` se abre con doble clic desde `C:\Park\files` o se sirve desde Netlify.

## Módulos

| Archivo | Perfil | Función |
|---|---|---|
| `IwolPark_Index.html` | — | Portal de entrada (raíz redirige aquí vía `netlify.toml`). |
| `IwolPark_TABLET.html` | **Operador** | Emisión, impresión, cobro y salida de tickets. Chrome `--kiosk-printing`, POS-58. El más grande (~509 KB) y el más delicado: es la caja. |
| `IwolPark_Dashboard_Cajeros.html` | Operador | Rendimiento y productividad por operador. |
| `IwolPark_Dashboard_Admin.html` | **Administrador** | KPIs, incidencias, operación diaria, cortes. |
| `IwolPark_Admin_Movil.html` | Administrador | Versión móvil del admin. |
| `IwolPark_Pensiones.html` | Administrador | Pensionados: alta, cobranza, semáforo de vigencia. |
| `IwolPark_Promo_Admin.html` | Administrador | Promociones, vouchers, interruptor general. |
| `IwolPark_Dashboard_Corporativo.html` | **Corporativo** | Oficina central, consolidado. En PROD2 se sirve como `corporativo.html`. |
| `IwolPark_Demanda.html` | — | Mapa de calor y evolución mensual. **Nunca se abre sola**: va embebida en `<iframe>` dentro de Admin/Corporativo. Por eso no lleva banner de ambiente. |
| `IwolPark_Central.html` | — | Consola central. |

Ignora los `.txt` con los mismos nombres (`IwolPark_TABLET.txt`, etc.): son respaldos viejos,
están en `.gitignore` y **no** son la fuente.

### Archivos duplicados a limpiar

`IwolPark_Dashboard_Corporativo - copia.html`, `IwolPark_Dashboard_Corporativo_.html`,
`IwolPark_Demanda-DESKTOP-HTN791F.html` — residuos de edición, no se despliegan.
Al buscar dónde vive una lógica, confirma contra la lista de módulos de arriba.

## Los tres ambientes

Existen **tres** sitios Netlify y **tres** proyectos Supabase distintos. Confundirlos
significa escribir datos de prueba en la base real del cliente.

Las credenciales de **QA viven hardcodeadas en los HTML fuente**. Producción se genera
sustituyéndolas con `sed` en un directorio temporal — el fuente nunca contiene credenciales
de producción.

### 🟢 QA / desarrollo

| | |
|---|---|
| Supabase | `gbciwuprgrzllagtlqij` (réplica de prod: esquema + datos reales) |
| Netlify | `iwolpark-qa.netlify.app` |
| Site ID | `4aa186ce-8fe5-4a51-9ce3-2b90736d00c8` |
| Deploy | `./deploy.sh` |
| Credenciales | **embebidas en los `.html` del repositorio** |
| Contador | `VERSION` (versionado en git) |
| Banner | ninguno |

Es el ambiente por defecto: todo archivo fuente del repo apunta aquí.
Trabajar en local = trabajar contra QA.

### 🟣 PRODUCCIÓN REAL — `iwol.click`

| | |
|---|---|
| Supabase | `syryisrelcjgdulxmgro` |
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
| Contador | `.prod_version` |
| Banner | rojo `#D93025` — "PRODUCCIÓN" |

El **25-jul-2026** el dominio `iwol.click` se movió de aquí a `iwolpark-produccion2`.
Este sitio ya no tiene usuarios. No desplegar sin revisar antes si sigue vivo.

**`iwol.click` apunta a PROD2.** Si alguien dice "súbelo a producción", es
**`deploy_prod2.sh`**. `deploy_prod.sh` despliega al sitio anterior, que ya no es
lo que ven los clientes.

Los `.env.prod*` no están versionados y no deben estarlo. Nunca escribas credenciales de
producción dentro de un `.html`, ni siquiera temporalmente — el fuente se commitea
automáticamente.

### Identificación visual en pantalla

| Banner | Ambiente |
|---|---|
| sin banner | QA |
| 🟣 morado | **iwol.click — producción real** |
| 🔴 rojo | producción legado (o copia local de producción) |
| 🟠 naranja | vista previa de producción |

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

**QA y Producción usan numeraciones independientes.** No son comparables entre sí:
ver v188 en QA y v101 en producción no significa que producción esté atrasada.

## Flujo de trabajo

1. Se desarrolla contra QA (credenciales ya en el fuente, no hay que configurar nada).
2. `./deploy.sh` — sube VERSION, estampa `v{N}` en el badge `id="app-version"` de cada página,
   hace `git add -A`, commit `Deploy v{N}`, push, despliega a QA y registra la versión en
   la tabla `versiones_app`.
3. Se prueba en QA.
4. `./deploy_prod2.sh` — **solo con autorización explícita del usuario.** No commitea nada;
   construye una copia efímera con credenciales de producción y banner morado.

```bash
./deploy.sh                       # QA — commitea, pushea y despliega. Bumpea VERSION.
./deploy_prod_preview.sh          # URL única de preview con credenciales reales. No toca el sitio vivo.
./deploy_prod2.sh                 # PRODUCCIÓN iwol.click. Requiere .env.prod2 + .prod2_version.
./generar_locales_produccion.sh   # copias *_PRODUCCION.html para abrir sin internet
```

`deploy.sh` hace `git add -A`: revisa que no haya archivos sueltos antes de correrlo.
Tiene `set -e`, así que si el `git push` falla (remoto adelantado) **aborta antes de
desplegar**: el commit local queda hecho pero Netlify y `versiones_app` no se tocan.

**Regla**: los scripts de producción **nunca** modifican ni commitean los archivos
fuente. Copian a un `mktemp -d`, sustituyen credenciales ahí y despliegan solo esa
copia efímera. Mantener esa propiedad en cualquier cambio a los scripts.

Son bash con `sed -i` y `mktemp`: en Windows correrlos desde **Git Bash**, no CMD ni
PowerShell.

## Control de versión de apps

Cada `.html` trae `verificarVersionServidor()`: al iniciar sesión consulta
`versiones_app` y, si el servidor tiene una versión mayor, obliga a actualizar.

El flujo de `deploy.sh` / `deploy_prod2.sh`:

1. incrementa el contador
2. estampa `vN` en `id="app-version"` de cada página vía `sed`
3. despliega a Netlify
4. hace `POST` a `versiones_app` con `on_conflict=app` para `tablet`, `admin`, `corporativo`

Romper cualquiera de esos cuatro pasos rompe la actualización forzada. Por eso
**el paso de registrar la versión no es opcional**: si se salta, los operadores se
quedan con la versión anterior en caché.

## Base de datos

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
`IwolPark_schema.sql` es del 11 de julio y ya no refleja la base. No hay forma de saber
qué se aplicó en cuál ambiente: si QA y producción se comportan distinto ante el mismo
código, sospecha primero de esto. Verifica que el script esté aplicado en destino antes
de desplegar código que lo use.

## Acceso a datos: MCP `iwolpark-db`

Servidor propio en `mcp-iwolpark/server.js`, configurado en `.mcp.json`. Instalar con
`npm install --prefix mcp-iwolpark`. Herramientas:
`iwolpark_select`, `iwolpark_count`, `iwolpark_insert`, `iwolpark_update`.

Ya trae dos protecciones que hay que respetar, no rodear:

- Solo expone `tickets` y `cortes` (`ALLOWED_TABLES`).
- `iwolpark_update` **exige filtros**, precisamente para que no exista un update masivo accidental.

Apunta al proyecto **QA**. Ojo con el fallback hardcodeado en `server.js`: si
`SUPABASE_URL`/`SUPABASE_ANON_KEY` no llegan por el entorno, cae a un ref de proyecto
*distinto* (`knaibgqehwvjuclsfdmo`) sin avisar. Si los datos no cuadran con lo que se ve en
pantalla, verifica primero contra qué base estás consultando.

## Instalación en máquinas de la plaza

`INSTALAR_IWOLPARK.bat` copia los HTML a `C:\Park\files`, crea `ABRIR_CAJERO.bat`
(Chrome `--kiosk-printing`), `ABRIR_ADMIN.bat` y `ABRIR_PENSIONES.bat`, pone iconos
en el escritorio y configura la impresora POS-58 como predeterminada.

NIPs default: cajero `1111`, admin `111111` — cambiar en parámetros tras instalar.

⚠️ **El `.bat` copia los HTML del directorio donde está**, que traen credenciales de
**QA**. Correrlo desde un clon limpio instala QA en la caja del cliente. Para
producción hay que correr antes `generar_locales_produccion.sh` y copiar los
`*_PRODUCCION.html`. El instalador no lo advierte.

## ⚠ SEGURIDAD — LEER ANTES DE TOCAR LA BASE

Auditoría del 2026-08-29. **Hay huecos abiertos.** El sistema lleva ~2 meses en
producción con esta configuración.

### El problema de fondo

La aplicación no tiene identidad por usuario. El login valida contra `cajeros`
vía `rpc/login_cajero`, pero de ahí en adelante **todo se hace con la llave
anónima**. Para Postgres, el cajero legítimo y un extraño en internet son el
mismo rol: `anon`. Por eso el RLS hoy no puede proteger nada — no tiene a quién
distinguir.

Las anon keys son públicas por diseño (van al navegador). **La única defensa real
es RLS en Supabase.** Cualquier tabla nueva necesita sus políticas.

La llave anónima está en los 9 módulos y en los scripts de despliegue, y el repo
`RANNIX-Claude/iwolpark` está **público**. Rotar la llave NO sirve: va incrustada
en cada página del navegador por diseño.

### Hallazgos, por gravedad

1. **`cajeros.nip_hash` es legible por `anon`.** Es SHA256 sin sal de un NIP de
   4 dígitos (6 para admin). Se rompe sin conexión en milisegundos: cualquiera
   baja la tabla y entra como `super_admin`. **Es acceso administrativo, no solo
   fuga de datos.** La app nunca pide esa columna — el login ya usa
   `login_cajero` — así que se puede revocar sin romper nada.
2. **`anon` puede hacer DELETE** en `tickets`, `pensiones` y `empleados`.
3. **Lectura total** para `anon`: en QA, `tickets` 5,451 · `bitacora` 3,219 ·
   `pensiones` 22 · `empleados` 12 · `cajeros` 10.
4. ⚠️ **`corporativo.html` está versionado con las credenciales de Producción**
   (`syryisrelcjgdulxmgro`), no de QA como el resto — en un repositorio público.
   Revisar el RLS de esa base y considerar normalizar el archivo al patrón de los demás.
5. Producción (`syryisrelcjgdulxmgro`) **no ha sido auditada todavía**. Se
   presume igual que QA.

### Ya corregido

- Se retiró de `IwolPark_TABLET.html` la rama que borraba todos los tickets del
  día en QA (`resincronizarFoliosManual`). La guarda `esQA` estaba bien puesta y
  producción nunca borró — pero la base sí acepta ese DELETE de cualquiera, así
  que el código sobraba y el `revoke` sigue haciendo falta.

### Pendiente

- [ ] Verificar `select proname, prosecdef from pg_proc where proname='login_cajero'`
      → debe ser `true` antes de aplicar el revoke
- [ ] Aplicar `sql_qa_01_cerrar_credenciales.sql` **en QA**, probar, luego producción
- [ ] Auditar producción
- [ ] Poner el repo en privado
- [ ] Normalizar `corporativo.html` para que no lleve credenciales de producción
- [ ] `mcp-iwolpark/server.js:9` cae a un proyecto distinto (`knaibgqehwvjuclsfdmo`)
      si faltan las variables de entorno. Debe ser `throw`, no fallback silencioso.

### La corrección de fondo

Migrar a una base nueva con **Supabase Auth por cajero** (4 cajeros + 1 admin).
Se conservan los mismos usuarios (`cajero1`…) sintetizando el correo
`cajero1@iwolpark.local`, para que el operador no note el cambio. Requiere
centralizar las 29 cabeceras escritas a mano de `IwolPark_TABLET.html` y que
devuelvan el token de sesión. Estimado: 3-4 días. Cuidar el modo sin conexión:
subir la vigencia del JWT y conservar el caché local de login.

**Regla mientras tanto:** no agregar tablas ni endpoints nuevos que dependan de
que `anon` pueda escribir. Todo lo nuevo, por función con `security definer`.

## Diagnóstico de incidencias en producción

Orden de trabajo, siempre el mismo:

1. **Reproducir el síntoma con datos reales** — folio, fecha, turno, cajero.
2. **Leer el dato antes que el código.** Consulta el ticket o corte involucrado.
3. **Decidir de qué lado está el problema:**
   - Si lo capturado es correcto pero el resultado (importe, hora de salida, corte) no cuadra
     → es **código**: busca la lógica en el HTML del módulo correspondiente.
   - Si el resultado es consistente con lo capturado → es **dato u operación**: captura
     equivocada, ticket reimpreso, turno mal cerrado.
4. **Verificar la versión que el usuario tiene abierta** contra `versiones_app` antes de
   perseguir un bug: puede ser una versión vieja en caché y el bug ya estar corregido.
5. **Si el número viene de un tablero, revisa si lo lee en vivo o de una tabla de hechos.**
   `historico_mensual` guarda montos ya calculados; un desajuste contra `tickets` puede
   ser un valor sellado, no un error de cobro.
6. **Corregir en el fuente, probar en QA, liberar con `deploy_prod2.sh`.**

Corregir datos directamente en producción es el último recurso, no el primero. Si hace falta:
muestra primero el `SELECT` de exactamente las filas que se van a tocar y espera aprobación.
Es dinero cobrado; un dato mal corregido no se distingue después de uno correcto.

## Reglas de trabajo

1. **Ante la duda, el ambiente es QA.** Producción solo por `deploy_prod2.sh` y con
   `deploy_prod_preview.sh` validado antes.
2. **Nunca commitear credenciales de Producción** (`.env.prod`, `.env.prod2`,
   `*_PRODUCCION.html`).
3. **Recuperar `.prod2_version` desde `versiones_app`** antes del primer deploy tras
   un clon nuevo.
4. **Aplicar los `sql_*.sql` en todos los ambientes**, no solo en QA.
5. **No romper el patrón de copia efímera** de los scripts de producción.
6. Las páginas se despliegan como archivos estáticos: **sin build, sin dependencias**.
