-- Interruptor general del módulo de Promociones — correr en Supabase → SQL
-- Editor (la anon key no puede hacer DDL). Aplica en QA, IWOL_QA y Producción.

ALTER TABLE dim_plaza ADD COLUMN IF NOT EXISTS promociones_habilitado BOOLEAN DEFAULT true;
