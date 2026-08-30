-- ═══════════════════════════════════════════════════════════════
-- QA · PASO 1 — Cerrar credenciales y borrado masivo
-- ═══════════════════════════════════════════════════════════════
-- APLICAR SOLO EN QA (gbciwuprgrzllagtlqij). Probar los 9 módulos.
-- Producción (syryisrelcjgdulxmgro) va después, con el mismo archivo.
--
-- Esto es REDUCCIÓN DE DAÑO, no la corrección de fondo. La corrección de
-- fondo es darle identidad real a cada cajero (Supabase Auth), porque hoy
-- la base no puede distinguir al cajero legítimo de un extraño: ambos
-- llegan como 'anon'. Este archivo cierra lo explotable hoy sin tocar
-- la arquitectura ni detener la operación.
--
-- ───────────────────────────────────────────────────────────────
-- POR QUÉ URGE
-- ───────────────────────────────────────────────────────────────
-- 1. cajeros.nip_hash es SHA256 de un NIP de 4 dígitos (6 para admin) y la
--    tabla es legible por 'anon'. 10,000 combinaciones se rompen en
--    milisegundos: cualquiera puede bajar la tabla, romper los NIP y entrar
--    como super_admin. Es acceso administrativo, no solo lectura.
--
-- 2. 'anon' puede hacer DELETE sobre tickets con filtro por fecha. La
--    función de "limpiar tickets de hoy" está protegida por un NIP y un
--    modal, pero esa protección vive en el NAVEGADOR: la base acepta el
--    DELETE de quien sea. Una sola petición borra la operación de un día.

begin;

-- ───────────────────────────────────────────────────────────────
-- 1. nip_hash deja de ser legible
-- ───────────────────────────────────────────────────────────────
-- El login ya se hace por la función login_cajero (ver IwolPark_TABLET.html
-- línea 5089), así que el navegador NO necesita esta columna. Se revoca el
-- SELECT de tabla completa y se vuelve a otorgar solo sobre las columnas que
-- la aplicación sí consulta.

revoke select on public.cajeros from anon;

grant select (
  cajero_id,
  plaza_id,
  nombre,
  usuario,
  rol,
  activo,
  created_at,
  last_login
) on public.cajeros to anon;

-- ⚠ REQUISITO: login_cajero debe ser SECURITY DEFINER para poder seguir
-- leyendo nip_hash después de este revoke. Verificar ANTES de aplicar:
--
--   select proname, prosecdef from pg_proc where proname = 'login_cajero';
--
--   prosecdef = true  -> todo bien, continuar
--   prosecdef = false -> NO APLICAR todavía; primero:
--                        alter function public.login_cajero(...) security definer;

-- ───────────────────────────────────────────────────────────────
-- 2. El anónimo deja de poder borrar
-- ───────────────────────────────────────────────────────────────
-- Ningún flujo de operación necesita borrar. Los tres usos reales son
-- administrativos y deben pasar por función o por el panel.

revoke delete on public.tickets   from anon;
revoke delete on public.pensiones from anon;
revoke delete on public.empleados from anon;

-- Nota para el equipo: la baja de empleados y pensiones debería ser lógica
-- (activo = false), no física. Un empleado borrado se lleva la trazabilidad
-- de los tickets que registró.

commit;

-- ═══════════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ═══════════════════════════════════════════════════════════════
-- select table_name, column_name, privilege_type
--   from information_schema.column_privileges
--  where grantee = 'anon' and table_name = 'cajeros'
--  order by column_name;
--   -> nip_hash NO debe aparecer
--
-- select table_name, privilege_type
--   from information_schema.table_privileges
--  where grantee = 'anon' and table_name in ('tickets','pensiones','empleados')
--  order by table_name, privilege_type;
--   -> no debe aparecer DELETE en ninguna

-- ═══════════════════════════════════════════════════════════════
-- PRUEBAS EN QA ANTES DE PASAR A PRODUCCIÓN
-- ═══════════════════════════════════════════════════════════════
-- [ ] Login de cajero con NIP correcto  -> entra
-- [ ] Login con NIP incorrecto          -> rechaza
-- [ ] Login de admin y de corporativo   -> entran con su rol
-- [ ] Emitir ticket, cobrar y dar salida
-- [ ] Cierre de turno / corte
-- [ ] Alta y baja de pensión
-- [ ] Pantalla de administración de cajeros (lista sin errores)
-- [ ] La limpieza de tickets de QA ahora falla -> esperado; se hace por panel

-- ═══════════════════════════════════════════════════════════════
-- LO QUE ESTO NO ARREGLA
-- ═══════════════════════════════════════════════════════════════
-- 'anon' sigue pudiendo leer y escribir tickets, pensiones y bitácora,
-- porque la aplicación lo necesita y no hay forma de distinguir quién es
-- quién. Eso solo se corrige con identidad real por usuario.
-- Ver PASO 2 (arquitectura) — trabajo de semanas, en rama aparte.
