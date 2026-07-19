-- IwolPark Promo — migración de base de datos
-- Correr en Supabase → SQL Editor (la anon key no puede hacer DDL).
-- Aplica igual en QA (knaibgqehwvjuclsfdmo) y en cada proyecto de Producción.

CREATE TABLE IF NOT EXISTS locales (
  id            BIGSERIAL PRIMARY KEY,
  nombre        TEXT NOT NULL,
  numero_local  TEXT,
  categoria     TEXT,
  contacto      TEXT,
  telefono      TEXT,
  logo_base64   TEXT,
  activo        BOOLEAN DEFAULT true,
  plaza         TEXT DEFAULT 'Plaza IWOL',
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS campanas (
  id              BIGSERIAL PRIMARY KEY,
  local_id        BIGINT REFERENCES locales(id),
  nombre_campana  TEXT NOT NULL,
  titulo_promo    TEXT NOT NULL,
  texto_promo     TEXT NOT NULL,
  tipo_promo      TEXT NOT NULL
                  CHECK (tipo_promo IN ('descuento_pct','descuento_fijo','2x1','leyenda','codigo')),
  valor_promo     TEXT,
  fecha_inicio    DATE NOT NULL,
  fecha_fin       DATE NOT NULL,
  hora_inicio     TIME DEFAULT '00:00',
  hora_fin        TIME DEFAULT '23:59',
  -- Guarda las mismas 3 franjas ya usadas en todo IwolPark ('05:00–10:00',
  -- '10:00–17:00', '17:00–22:00') — vacío = todas las franjas.
  franjas         TEXT[],
  dias_semana     TEXT[],              -- ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom']
  tipos_cliente   TEXT[],              -- ['normal','preferencial','pension','empleado','cortesia']
  estado          TEXT NOT NULL DEFAULT 'activa'
                  CHECK (estado IN ('activa','pausada','terminada','programada')),
  impactos        INT DEFAULT 0,
  presupuesto_impactos INT,
  costo_campana   NUMERIC(10,2),
  costo_por_impacto NUMERIC(10,4),
  campana_origen_id BIGINT,
  notas           TEXT,
  creado_por      TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS impactos_detalle (
  id           BIGSERIAL PRIMARY KEY,
  campana_id   BIGINT REFERENCES campanas(id),
  ticket_folio TEXT,
  cajero       TEXT,
  franja       TEXT,
  dia_semana   TEXT,
  tipo_cliente TEXT,
  fecha        DATE DEFAULT CURRENT_DATE,
  hora         TIME DEFAULT CURRENT_TIME,
  created_at   TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE locales           ENABLE ROW LEVEL SECURITY;
ALTER TABLE campanas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE impactos_detalle  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "locales_all"  ON locales;
DROP POLICY IF EXISTS "campanas_all" ON campanas;
DROP POLICY IF EXISTS "impactos_all" ON impactos_detalle;
CREATE POLICY "locales_all"  ON locales          FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "campanas_all" ON campanas         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "impactos_all" ON impactos_detalle FOR ALL TO anon USING (true) WITH CHECK (true);
