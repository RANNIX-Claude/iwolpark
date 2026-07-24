-- Columna IP para la bitácora — se llena al capturar los atajos de teclado
-- (F2-F8) en la caseta, además de hora/fecha (created_at) y usuario, que ya
-- existían.
alter table bitacora add column if not exists ip text;
