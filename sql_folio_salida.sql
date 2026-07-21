-- Guarda el folio de salida (S-AAMMDDNNN) que se genera al completar un
-- cobro real (F10/F11) — necesario para que, si la tablet se reinicia a
-- medio día, el consecutivo se pueda recuperar consultando el máximo ya
-- usado hoy (igual que se hace con el folio de entrada), en vez de volver a
-- empezar en 001 y repetir un número ya impreso.
alter table tickets add column if not exists folio_salida text;
