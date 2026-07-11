-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ══════════════════════════════════════════
--  IwolPark · Supabase Schema v1.0
--  Data Warehouse + Operaciones
-- ══════════════════════════════════════════

-- ── DIMENSIONES ──────────────────────────

CREATE TABLE dim_plaza (
  plaza_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre          TEXT NOT NULL,
  ciudad          TEXT NOT NULL DEFAULT 'Metepec',
  estado          TEXT NOT NULL DEFAULT 'Edo. México',
  capacidad_total INT  NOT NULL DEFAULT 40,
  empresa_grupo   TEXT NOT NULL DEFAULT 'Inmobiliaria Alcedines del Norte',
  rfc             TEXT NOT NULL DEFAULT 'IAN2009238UA',
  direccion       TEXT,
  tarifa_normal   NUMERIC(10,2) NOT NULL DEFAULT 15.00,
  tarifa_pref     NUMERIC(10,2) NOT NULL DEFAULT 6.00,
  tarifa_perdido  NUMERIC(10,2) NOT NULL DEFAULT 150.00,
  tolerancia_min  INT  NOT NULL DEFAULT 15,
  hora_relevo_1   TIME DEFAULT '14:00',
  hora_relevo_2   TIME DEFAULT '22:00',
  activa          BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- Plaza IWOL seed
INSERT INTO dim_plaza (nombre, ciudad, capacidad_total) VALUES
  ('Plaza IWOL', 'Metepec', 68);

CREATE TABLE dim_tipo_boleto (
  tipo_id          SERIAL PRIMARY KEY,
  codigo           TEXT NOT NULL UNIQUE, -- 'normal','preferencial','perdido','cortesia','pension'
  descripcion      TEXT NOT NULL,
  genera_ingreso   BOOLEAN DEFAULT true,
  color_hex        TEXT DEFAULT '#7B5EA7'
);

INSERT INTO dim_tipo_boleto (codigo, descripcion, genera_ingreso, color_hex) VALUES
  ('normal',       'Entrada Normal',        true,  '#0A66C2'),
  ('preferencial', 'Entrada Preferencial',  true,  '#7B5EA7'),
  ('perdido',      'Boleto Perdido',        true,  '#D93025'),
  ('cortesia',     'Cortesía (≤15 min)',    false, '#888888'),
  ('pension',      'Pensión Mensual',       true,  '#0D9457');

CREATE TABLE dim_tiempo (
  tiempo_id    BIGSERIAL PRIMARY KEY,
  fecha        DATE      NOT NULL,
  hora         TIME      NOT NULL,
  franja       TEXT      NOT NULL CHECK (franja IN ('Matutino','Vespertino','Nocturno')),
  dia_semana   TEXT      NOT NULL, -- 'Lunes','Martes',...
  num_dia      INT       NOT NULL, -- 1=Lun ... 7=Dom
  semana_año   INT       NOT NULL,
  mes          INT       NOT NULL,
  nombre_mes   TEXT      NOT NULL,
  año          INT       NOT NULL,
  es_fin_semana BOOLEAN  NOT NULL DEFAULT false,
  UNIQUE (fecha, hora)
);

-- ── USUARIOS / CAJEROS ───────────────────

CREATE TABLE cajeros (
  cajero_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plaza_id    UUID REFERENCES dim_plaza(plaza_id),
  nombre      TEXT NOT NULL,
  usuario     TEXT NOT NULL UNIQUE,
  nip_hash    TEXT, -- SHA256 del NIP (4 dígitos cajero, 6 admin)
  rol         TEXT NOT NULL DEFAULT 'cajero'
              CHECK (rol IN ('cajero','admin_plaza','corporativo','super_admin')),
  activo      BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now(),
  last_login  TIMESTAMPTZ
);

-- NIP default: cajero=1111, admin=111111
INSERT INTO cajeros (nombre, usuario, nip_hash, rol) VALUES
  ('Cajero Default', 'cajero1', encode(digest('1111', 'sha256'), 'hex'), 'cajero'),
  ('Administrador',  'admin',   encode(digest('111111', 'sha256'), 'hex'), 'admin_plaza');

-- ── TURNOS ───────────────────────────────

CREATE TABLE turnos (
  turno_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plaza_id        UUID REFERENCES dim_plaza(plaza_id),
  cajero_id       UUID REFERENCES cajeros(cajero_id),
  inicio_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  fin_at          TIMESTAMPTZ,
  tipo            TEXT NOT NULL DEFAULT 'apertura'
                  CHECK (tipo IN ('apertura','relevo','cierre')),
  fondo_inicial   NUMERIC(10,2) NOT NULL DEFAULT 0,
  total_cobrado   NUMERIC(10,2) DEFAULT 0,
  total_entregado NUMERIC(10,2),
  cajero_relevo_id UUID REFERENCES cajeros(cajero_id),
  estado          TEXT NOT NULL DEFAULT 'activo'
                  CHECK (estado IN ('activo','relevado','cerrado')),
  notas           TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- ── FACT TABLE OPERACIONES ───────────────

CREATE TABLE fact_operacion (
  operacion_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Claves foráneas dimensionales
  plaza_id         UUID REFERENCES dim_plaza(plaza_id),
  cajero_id        UUID REFERENCES cajeros(cajero_id),
  turno_id         UUID REFERENCES turnos(turno_id),
  tipo_id          INT  REFERENCES dim_tipo_boleto(tipo_id),
  -- Datos del ticket
  folio            TEXT NOT NULL,
  hora_entrada_at  TIMESTAMPTZ NOT NULL,
  hora_salida_at   TIMESTAMPTZ,
  -- Métricas
  minutos_estancia INT,
  horas_cobradas   INT,
  tarifa_snapshot  NUMERIC(10,2),
  penalizacion     NUMERIC(10,2) DEFAULT 0,
  importe          NUMERIC(10,2) NOT NULL DEFAULT 0,
  -- Dimensión tiempo (pre-calculada para performance)
  fecha_op         DATE,
  hora_op          TIME,
  franja           TEXT,
  dia_semana       TEXT,
  mes              INT,
  año              INT,
  -- Sync
  folio_local      TEXT, -- folio del dispositivo local
  synced_at        TIMESTAMPTZ DEFAULT now(),
  created_at       TIMESTAMPTZ DEFAULT now()
);

-- ── VISTAS ANALÍTICAS ────────────────────

-- KPIs diarios por plaza
CREATE VIEW v_kpi_dia AS
SELECT
  plaza_id,
  fecha_op                                              AS fecha,
  COUNT(*)                                              AS total_operaciones,
  COUNT(*) FILTER (WHERE tipo_id = 1)                   AS normales,
  COUNT(*) FILTER (WHERE tipo_id = 2)                   AS preferenciales,
  COUNT(*) FILTER (WHERE tipo_id = 3)                   AS perdidos,
  COUNT(*) FILTER (WHERE tipo_id = 4)                   AS cortesias,
  SUM(importe)                                          AS ingreso_total,
  AVG(importe) FILTER (WHERE importe > 0)               AS ticket_promedio,
  AVG(minutos_estancia) FILTER (WHERE minutos_estancia > 0) AS estancia_promedio_min,
  MAX(minutos_estancia)                                 AS estancia_maxima_min
FROM fact_operacion
GROUP BY plaza_id, fecha_op;

-- KPIs por franja horaria
CREATE VIEW v_kpi_franja AS
SELECT
  plaza_id,
  fecha_op,
  franja,
  COUNT(*)                       AS operaciones,
  SUM(importe)                   AS ingreso,
  AVG(minutos_estancia)          AS estancia_prom
FROM fact_operacion
GROUP BY plaza_id, fecha_op, franja;

-- KPIs por cajero
CREATE VIEW v_kpi_cajero AS
SELECT
  f.plaza_id,
  f.cajero_id,
  c.nombre                       AS cajero,
  f.fecha_op,
  COUNT(*)                       AS operaciones,
  SUM(f.importe)                 AS cobrado,
  AVG(f.minutos_estancia)        AS estancia_prom
FROM fact_operacion f
JOIN cajeros c ON c.cajero_id = f.cajero_id
GROUP BY f.plaza_id, f.cajero_id, c.nombre, f.fecha_op;

-- Resumen mensual corporativo
CREATE VIEW v_resumen_mensual AS
SELECT
  p.nombre                              AS plaza,
  EXTRACT(YEAR  FROM f.fecha_op)::INT  AS año,
  EXTRACT(MONTH FROM f.fecha_op)::INT  AS mes,
  COUNT(*)                              AS operaciones,
  SUM(f.importe)                        AS ingreso_total,
  AVG(f.importe) FILTER (WHERE f.importe > 0) AS ticket_promedio,
  COUNT(*) FILTER (WHERE f.tipo_id = 3)        AS boletos_perdidos
FROM fact_operacion f
JOIN dim_plaza p ON p.plaza_id = f.plaza_id
GROUP BY p.nombre,
         EXTRACT(YEAR  FROM f.fecha_op),
         EXTRACT(MONTH FROM f.fecha_op)
ORDER BY año DESC, mes DESC;

-- ── SYNC QUEUE (offline → Supabase) ──────

CREATE TABLE sync_queue (
  id          BIGSERIAL PRIMARY KEY,
  plaza_id    UUID,
  tabla       TEXT NOT NULL,
  operacion   TEXT NOT NULL CHECK (operacion IN ('INSERT','UPDATE')),
  payload     JSONB NOT NULL,
  intentos    INT DEFAULT 0,
  synced      BOOLEAN DEFAULT false,
  error_msg   TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  synced_at   TIMESTAMPTZ
);

-- ── ROW LEVEL SECURITY ───────────────────

ALTER TABLE fact_operacion ENABLE ROW LEVEL SECURITY;
ALTER TABLE turnos          ENABLE ROW LEVEL SECURITY;
ALTER TABLE cajeros         ENABLE ROW LEVEL SECURITY;

-- Cajero: solo ve su plaza
CREATE POLICY "cajero_su_plaza" ON fact_operacion
  FOR ALL TO authenticated
  USING (plaza_id = (SELECT plaza_id FROM cajeros WHERE cajero_id::text = auth.uid()::text));

-- Admin plaza: solo su plaza
CREATE POLICY "admin_su_plaza" ON fact_operacion
  FOR SELECT TO authenticated
  USING (plaza_id = (SELECT plaza_id FROM cajeros WHERE cajero_id::text = auth.uid()::text));

-- Corporativo: todas las plazas
CREATE POLICY "corporativo_todo" ON fact_operacion
  FOR SELECT TO authenticated
  USING ((SELECT rol FROM cajeros WHERE cajero_id::text = auth.uid()::text) 
         IN ('corporativo','super_admin'));

-- ── ÍNDICES PARA PERFORMANCE ─────────────
CREATE INDEX idx_fact_fecha    ON fact_operacion (fecha_op);
CREATE INDEX idx_fact_plaza    ON fact_operacion (plaza_id);
CREATE INDEX idx_fact_turno    ON fact_operacion (turno_id);
CREATE INDEX idx_fact_cajero   ON fact_operacion (cajero_id);
CREATE INDEX idx_fact_franja   ON fact_operacion (franja);
CREATE INDEX idx_sync_pending  ON sync_queue (synced) WHERE synced = false;

-- ══════════════════════════════════════════
--  MÓDULO PENSIONES · IwolPark
--  SCD Type 2 para historial de tarifas
-- ══════════════════════════════════════════

-- ── HISTORIAL DE TARIFAS (SCD Type 2) ────
-- Guarda TODA la historia: tarifa vigente + anteriores
-- Nunca se sobreescribe, solo se cierra el período

CREATE TABLE tarifas_historico (
  tarifa_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plaza_id        UUID REFERENCES dim_plaza(plaza_id),
  concepto        TEXT NOT NULL CHECK (concepto IN (
                    'normal','preferencial','perdido',
                    'pension_dia','pension_noche','pension_24h'
                  )),
  monto           NUMERIC(10,2) NOT NULL,
  vigente_desde   DATE NOT NULL,
  vigente_hasta   DATE,           -- NULL = tarifa actualmente vigente
  motivo_cambio   TEXT,           -- "Ajuste inflación 2026", etc.
  creado_por      UUID REFERENCES cajeros(cajero_id),
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- Seed tarifas iniciales Plaza IWOL
INSERT INTO tarifas_historico (concepto, monto, vigente_desde, motivo_cambio) VALUES
  ('normal',        15.00, '2026-01-01', 'Tarifa inicial'),
  ('preferencial',   6.00, '2026-01-01', 'Tarifa inicial'),
  ('perdido',      150.00, '2026-01-01', 'Tarifa inicial'),
  ('pension_dia',  600.00, '2026-01-01', 'Tarifa inicial'),
  ('pension_noche',400.00, '2026-01-01', 'Tarifa inicial'),
  ('pension_24h',  900.00, '2026-01-01', 'Tarifa inicial');

-- Vista: tarifa vigente hoy (siempre la más reciente sin fecha_hasta)
CREATE VIEW v_tarifas_vigentes AS
SELECT DISTINCT ON (concepto)
  tarifa_id, concepto, monto, vigente_desde, motivo_cambio
FROM tarifas_historico
WHERE vigente_hasta IS NULL
   OR vigente_hasta >= CURRENT_DATE
ORDER BY concepto, vigente_desde DESC;

-- Función para cambiar tarifa (cierra la anterior, abre la nueva)
CREATE OR REPLACE FUNCTION cambiar_tarifa(
  p_concepto   TEXT,
  p_monto      NUMERIC,
  p_desde      DATE,
  p_motivo     TEXT,
  p_cajero_id  UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE v_id UUID;
BEGIN
  -- Cerrar tarifa vigente anterior
  UPDATE tarifas_historico
  SET    vigente_hasta = p_desde - 1
  WHERE  concepto = p_concepto
    AND  vigente_hasta IS NULL;
  -- Insertar nueva tarifa
  INSERT INTO tarifas_historico
    (concepto, monto, vigente_desde, motivo_cambio, creado_por)
  VALUES (p_concepto, p_monto, p_desde, p_motivo, p_cajero_id)
  RETURNING tarifa_id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- ── CLIENTES / PENSIONADOS ────────────────

CREATE TABLE clientes (
  cliente_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plaza_id     UUID REFERENCES dim_plaza(plaza_id),
  nombre       TEXT NOT NULL,
  telefono     TEXT,
  whatsapp     TEXT,
  email        TEXT,
  activo       BOOLEAN DEFAULT true,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

-- ── VEHÍCULOS ─────────────────────────────

CREATE TABLE vehiculos (
  vehiculo_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id   UUID NOT NULL REFERENCES clientes(cliente_id),
  placas       TEXT NOT NULL,
  marca        TEXT NOT NULL,
  modelo       TEXT NOT NULL,
  anio         INT,
  color        TEXT NOT NULL,
  num_serie    TEXT,
  notas        TEXT,
  activo       BOOLEAN DEFAULT true,
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- ── PENSIONES ─────────────────────────────

CREATE TABLE pensiones (
  pension_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plaza_id         UUID REFERENCES dim_plaza(plaza_id),
  cliente_id       UUID NOT NULL REFERENCES clientes(cliente_id),
  vehiculo_id      UUID REFERENCES vehiculos(vehiculo_id),
  tipo             TEXT NOT NULL CHECK (tipo IN ('dia','noche','24h')),
  hora_inicio      TIME,         -- 07:00 para día
  hora_fin         TIME,         -- 22:00 para día
  -- Monto snapshot al momento de contratar (para auditoría)
  monto_mensual    NUMERIC(10,2) NOT NULL,
  tarifa_id_origen UUID REFERENCES tarifas_historico(tarifa_id),
  -- Vigencia
  fecha_inicio     DATE NOT NULL,
  dia_pago         INT NOT NULL DEFAULT 1   -- día del mes para pagar (1-28)
                   CHECK (dia_pago BETWEEN 1 AND 28),
  -- Estado
  estado           TEXT NOT NULL DEFAULT 'activo'
                   CHECK (estado IN ('activo','suspendido','cancelado')),
  -- Acceso
  codigo_acceso    TEXT UNIQUE,  -- código de barras / QR para la tarjeta
  notas            TEXT,
  -- Admin
  registrado_por   UUID REFERENCES cajeros(cajero_id),
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

-- ── PAGOS DE PENSIÓN ──────────────────────

CREATE TABLE pagos_pension (
  pago_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pension_id      UUID NOT NULL REFERENCES pensiones(pension_id),
  -- Período que cubre este pago
  periodo_mes     INT NOT NULL CHECK (periodo_mes BETWEEN 1 AND 12),
  periodo_año     INT NOT NULL,
  -- Monto
  monto_tarifa    NUMERIC(10,2) NOT NULL,  -- tarifa vigente ese período
  monto_pagado    NUMERIC(10,2),           -- lo que realmente pagó
  diferencia      NUMERIC(10,2),  -- calculado: monto_pagado - monto_tarifa
  -- Comprobante / conciliación
  referencia_pago TEXT,         -- número de transferencia, cheque, etc.
  comprobante_url TEXT,         -- URL del comprobante adjunto
  metodo_pago     TEXT DEFAULT 'efectivo'
                  CHECK (metodo_pago IN ('efectivo','transferencia','deposito','tarjeta')),
  -- Estado de conciliación
  estado          TEXT NOT NULL DEFAULT 'pendiente'
                  CHECK (estado IN (
                    'pendiente',     -- aún no ha pagado
                    'por_validar',   -- pagó, enviando comprobante, admin debe validar
                    'validado',      -- admin confirmó el pago
                    'rechazado'      -- comprobante inválido o insuficiente
                  )),
  -- Fechas
  fecha_pago      DATE,          -- cuándo pagó el cliente
  fecha_limite    DATE,          -- hasta cuándo tiene para pagar
  fecha_validacion TIMESTAMPTZ,  -- cuándo el admin validó
  -- Quién operó
  registrado_por  UUID REFERENCES cajeros(cajero_id),   -- quien anotó el pago
  validado_por    UUID REFERENCES cajeros(cajero_id),   -- admin que validó
  notas           TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- ── VISTAS SEMÁFORO ───────────────────────

-- Estado de cada pensión HOY
CREATE VIEW v_pensiones_estado AS
SELECT
  p.pension_id,
  p.plaza_id,
  c.nombre                                    AS cliente,
  c.telefono,
  c.whatsapp,
  v.placas,
  v.marca || ' ' || v.modelo || ' ' || v.color AS vehiculo,
  p.tipo,
  p.monto_mensual,
  p.dia_pago,
  p.estado                                    AS estado_pension,
  -- Último pago validado
  (SELECT MAX(periodo_año*100 + periodo_mes)
   FROM pagos_pension pp
   WHERE pp.pension_id = p.pension_id
     AND pp.estado = 'validado')              AS ultimo_periodo_pagado,
  -- Pago del mes actual
  (SELECT pp.estado
   FROM pagos_pension pp
   WHERE pp.pension_id = p.pension_id
     AND pp.periodo_mes = EXTRACT(MONTH FROM CURRENT_DATE)
     AND pp.periodo_año = EXTRACT(YEAR  FROM CURRENT_DATE)
   LIMIT 1)                                   AS estado_mes_actual,
  -- Semáforo
  CASE
    WHEN p.estado != 'activo' THEN 'inactiva'
    WHEN EXISTS (
      SELECT 1 FROM pagos_pension pp
      WHERE pp.pension_id = p.pension_id
        AND pp.periodo_mes = EXTRACT(MONTH FROM CURRENT_DATE)
        AND pp.periodo_año = EXTRACT(YEAR  FROM CURRENT_DATE)
        AND pp.estado = 'validado'
    ) THEN 'al_corriente'       -- 🟢
    WHEN EXTRACT(DAY FROM CURRENT_DATE) <= p.dia_pago
    THEN 'por_vencer'           -- 🟡 aún está en plazo
    ELSE 'vencido'              -- 🔴 pasó el día de pago sin pagar
  END                                         AS semaforo
FROM pensiones p
JOIN clientes  c ON c.cliente_id = p.cliente_id
LEFT JOIN vehiculos v ON v.vehiculo_id = p.vehiculo_id
WHERE p.estado = 'activo';

-- Cobranza pendiente del mes
CREATE VIEW v_cobranza_mes AS
SELECT
  p.pension_id,
  c.nombre        AS cliente,
  c.whatsapp,
  v.placas,
  p.tipo,
  p.monto_mensual,
  p.dia_pago,
  pp.estado       AS estado_pago,
  pp.referencia_pago,
  pp.fecha_pago,
  EXTRACT(MONTH FROM CURRENT_DATE) AS mes_actual,
  EXTRACT(YEAR  FROM CURRENT_DATE) AS año_actual
FROM pensiones p
JOIN clientes c ON c.cliente_id = p.cliente_id
LEFT JOIN vehiculos v ON v.vehiculo_id = p.vehiculo_id
LEFT JOIN pagos_pension pp ON pp.pension_id = p.pension_id
  AND pp.periodo_mes = EXTRACT(MONTH FROM CURRENT_DATE)
  AND pp.periodo_año = EXTRACT(YEAR  FROM CURRENT_DATE)
WHERE p.estado = 'activo'
ORDER BY p.dia_pago, c.nombre;

-- ── ÍNDICES ───────────────────────────────
CREATE INDEX idx_pagos_pension    ON pagos_pension (pension_id, periodo_año, periodo_mes);
CREATE INDEX idx_pagos_estado     ON pagos_pension (estado);
CREATE INDEX idx_pensiones_estado ON pensiones (estado);
CREATE INDEX idx_tarifas_concepto ON tarifas_historico (concepto, vigente_desde);
