-- Permite saber, en vivo, si una pensión ya tiene un vehículo dentro de la
-- plaza ahora mismo (para no dejar imprimir un segundo boleto de esa misma
-- pensión mientras el primero sigue abierto). Sin FK a propósito: un ticket
-- histórico debe seguir existiendo aunque la pensión se elimine más adelante.
alter table tickets add column if not exists pension_id uuid;
