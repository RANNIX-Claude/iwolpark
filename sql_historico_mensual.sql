-- Tabla de hechos: histórico mensual de ingresos por plaza, para el cuadro
-- "Evolución mensual" del tablero de Demanda. Combina años previos al
-- sistema (capturados una sola vez a mano) con meses ya calculados por el
-- propio sistema a partir de tickets reales.
create table if not exists historico_mensual (
  id uuid primary key default gen_random_uuid(),
  plaza_id uuid not null references dim_plaza(plaza_id),
  anio integer not null,
  mes integer not null check (mes between 1 and 12),
  monto_total numeric not null default 0,
  tickets_totales integer not null default 0,
  origen text not null check (origen in ('manual','sistema')),
  actualizado_en timestamptz not null default now(),
  unique (plaza_id, anio, mes)
);
