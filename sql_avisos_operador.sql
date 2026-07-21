-- Avisos que el Admin puede mandar a uno, varios o todos los cajeros — se
-- muestran como una alerta al abrir/usar la tablet (ej. "presiona Actualizar
-- antes de iniciar tu turno"). destinatario NULL o 'todos' = para todos los
-- cajeros; si no, debe coincidir exactamente con el nombre del cajero.
create table if not exists avisos_operador (
  id bigint generated always as identity primary key,
  plaza_id uuid references dim_plaza(plaza_id),
  destinatario text,
  mensaje text not null,
  creado_por text,
  created_at timestamptz default now()
);
