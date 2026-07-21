-- Extiende avisos_operador para permitir respuesta del cajero (no solo
-- Admin -> cajero como antes). origen distingue quién mandó cada fila;
-- hilo_id agrupa una conversación (apunta al id del primer mensaje del
-- hilo); leido_admin es el "no leído" para el lado de Admin (el lado del
-- cajero ya usa localStorage, ver _avisosVistos() en TABLET.html).
alter table avisos_operador add column if not exists origen text not null default 'admin';
alter table avisos_operador add column if not exists hilo_id bigint references avisos_operador(id);
alter table avisos_operador add column if not exists leido_admin boolean not null default true;
