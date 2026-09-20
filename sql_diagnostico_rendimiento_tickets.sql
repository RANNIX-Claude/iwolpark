-- Diagnóstico de rendimiento de `tickets` — NO modifica nada, solo lee.
--
-- Existe por un síntoma concreto: en el Dashboard Admin de iwol.click, el
-- filtro "Este mes" del tab Histórico se queda esperando y termina cayendo
-- en "Sin conexión · datos demo" — es decir, la consulta no se está
-- tardando, está FALLANDO, y el dashboard lo disimula pintando datos
-- inventados en pantalla.
--
-- La sospecha inicial era falta de índices sobre un volumen que ya pasó los
-- 10,000 tickets. Una reproducción local con 12,040 tickets descartó esa
-- causa: sin un solo índice, la consulta del mes corre en 3.9 ms. Estas
-- consultas sirven para confirmarlo sobre los datos reales y encontrar la
-- causa verdadera.
--
-- Correr en el SQL Editor del proyecto afectado (PROD2, iwol.click) y, para
-- comparar, en QA.

-- ── 1 · ¿Cuántos tickets hay y cuánto pesan? ──────────────────────────
select
  count(*)                                             as total_tickets,
  count(*) filter (where estatus = 'cancelado')        as cancelados,
  count(*) filter (where estatus = 'abierto')          as abiertos,
  min(fecha_op)                                        as primer_ticket,
  max(fecha_op)                                        as ultimo_ticket,
  pg_size_pretty(pg_total_relation_size('tickets'))    as tamano_total,
  pg_size_pretty(pg_indexes_size('tickets'))           as tamano_indices
from tickets;

-- ── 2 · Volumen por mes (para ver el ritmo real de crecimiento) ───────
select anio, mes, count(*) as tickets,
       sum(importe) filter (where estatus in ('cobrado','perdido')) as ingresos
from tickets
group by anio, mes
order by anio, mes;

-- ── 3 · ¿Qué índices existen? ─────────────────────────────────────────
select indexname, indexdef
from pg_indexes
where schemaname = 'public' and tablename in ('tickets','bitacora','cortes')
order by tablename, indexname;

-- ── 4 · ¿Se usan esos índices, o la tabla se lee entera cada vez? ─────
-- idx_scan = 0 en un índice que existe significa que nadie lo aprovecha.
-- seq_scan alto en tickets = la tabla se recorre completa una y otra vez.
select
  s.relname as tabla, s.seq_scan, s.seq_tup_read,
  s.idx_scan, s.n_live_tup, s.n_dead_tup,
  s.last_autovacuum, s.last_autoanalyze
from pg_stat_user_tables s
where s.relname in ('tickets','bitacora','cortes');

select
  i.relname as tabla, i.indexrelname as indice,
  i.idx_scan as veces_usado, pg_size_pretty(pg_relation_size(i.indexrelid)) as tamano
from pg_stat_user_indexes i
where i.relname in ('tickets','bitacora','cortes')
order by i.idx_scan asc;

-- ── 5 · Hinchazón por UPDATE ──────────────────────────────────────────
-- Cada boleto se INSERTA al entrar y se ACTUALIZA al cobrar (el PATCH de
-- enviarSupabase), así que cada ticket deja al menos una versión muerta.
-- Si autovacuum se está quedando atrás, la tabla ocupa mucho más de lo que
-- sus filas justifican y cada lectura recorre páginas vacías.
-- Sano: dead_pct por debajo de ~10%.
select
  n_live_tup, n_dead_tup,
  round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 1) as dead_pct
from pg_stat_user_tables where relname = 'tickets';

-- ── 6 · El plan real de la consulta del dashboard ─────────────────────
-- Es literalmente lo que pide el Histórico con "Este mes":
--   tickets?fecha_op=gte.<1ro>&fecha_op=lte.<fin>&order=created_at.desc
-- Ajusta las fechas al mes en curso antes de correrlo.
explain (analyze, buffers)
select * from tickets
where fecha_op >= date_trunc('month', current_date)::date
  and fecha_op <= (date_trunc('month', current_date) + interval '1 month - 1 day')::date
order by created_at desc
limit 1000 offset 0;

-- ── 7 · El límite de tiempo que corta las consultas del anon key ──────
-- Supabase le impone un statement_timeout al rol anon. Si la consulta lo
-- excede, PostgREST devuelve error y el dashboard salta a datos demo.
select rolname, rolconfig from pg_roles
where rolname in ('anon','authenticated','service_role');
show statement_timeout;

-- ── 8 · ¿Cuánto pesa lo que viaja por la red? ─────────────────────────
-- El dashboard pide `select=*` (las ~27 columnas) aunque solo use 11.
select
  count(*) as filas_del_mes,
  pg_size_pretty(sum(length(row_to_json(t)::text))::bigint) as payload_select_estrella
from tickets t
where fecha_op >= date_trunc('month', current_date)::date;
