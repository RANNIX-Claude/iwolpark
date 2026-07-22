-- Igual que pension_id: permite saber si un empleado YA tiene un boleto
-- abierto ahora mismo, para no dejarlo aparecer de nuevo en el combo de
-- "Entrada Empleado" hasta que registre su salida.
alter table tickets add column if not exists empleado_id bigint references empleados(id);
