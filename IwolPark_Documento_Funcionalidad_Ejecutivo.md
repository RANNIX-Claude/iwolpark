# IwolPark — Sistema de Gestión de Estacionamiento
## Documento de funcionalidad para presentación ejecutiva

**Cliente:** Inmobiliaria Alcedines del Norte — Plaza IWOL, Metepec, Estado de México
**Desarrollado por:** RANNIX Consulting
**Capacidad de la plaza:** 68 cajones

---

## 1. Resumen ejecutivo

IwolPark es el sistema propio que digitalizó por completo la operación del estacionamiento de Plaza IWOL: desde el boleto que recibe un cliente al entrar, hasta los reportes que ve la dirección para tomar decisiones de negocio. Sustituye el control manual/en papel por un sistema en tiempo real, con historial completo, reportes automáticos y control de accesos por rol.

El sistema se compone de **tres aplicaciones operativas** y **tres tableros de análisis**, todos conectados a la misma base de datos en la nube (Supabase), por lo que la información se ve reflejada de inmediato en todos los módulos.

| Aplicación | Quién la usa | Para qué |
|---|---|---|
| **Caseta (TABLET)** | Cajeros en turno | Dar entrada, cobrar y cerrar el turno |
| **Dashboard Admin** | Administración de la plaza | Supervisar la operación del día, configurar tarifas y usuarios |
| **Dashboard Corporativo** | Oficina Central | Visión ejecutiva consolidada, multi-pestaña |
| **Análisis de Demanda** | Administración / Oficina Central | Patrones de uso por hora, día y franja |
| **Rendimiento de Cajeros** | Oficina Central | Comparativo de desempeño por cajero, mes contra mes |
| **Pensiones** | Administración | Control de clientes con mensualidad fija |

---

## 2. Caseta — App del cajero (TABLET)

Es la aplicación que opera el cajero en la caseta de cobro, diseñada para usarse en una tablet, con botones grandes y flujo rápido.

**Funciones principales:**
- **Entrada de vehículo:** genera un folio único al instante y un boleto imprimible con código de barras, sin necesidad de capturar datos — un toque y el boleto sale.
- **Tipos de entrada:** Normal, Preferencial, Empleado (cortesía) y Pensionado, cada uno con su propia tarifa y regla de cobro.
- **Cobro / salida:** al escanear o teclear el folio, el sistema calcula automáticamente el tiempo de estancia y el importe según la tarifa vigente; imprime el comprobante de pago.
- **Boleto perdido:** flujo de penalización con impresión de comprobante por duplicado.
- **Cortesía automática:** si un vehículo estuvo menos del tiempo de tolerancia configurado, el cobro se condona automáticamente (no requiere que el cajero lo marque a mano).
- **Consulta de folio (F8):** permite buscar cualquier boleto — de esta caseta o de otra sesión — y reimprimir el comprobante de pago.
- **Atajos de teclado (F2–F7):** para operación rápida sin usar el mouse/touch en cada botón.
- **Modo sin conexión:** si se cae el internet, la caseta sigue cobrando con normalidad (guarda todo localmente) y sincroniza automáticamente en cuanto vuelve la señal — no se pierden ventas.
- **Instalable como app (PWA):** se agrega a la pantalla de inicio de la tablet, abre en pantalla completa como una aplicación nativa.
- **Control de acceso:** cada cajero entra con su propio usuario y contraseña; todo movimiento queda asociado a quién lo hizo.

*(Sugerencia de captura: pantalla principal con los 4 botones grandes, el ticket impreso, y la ventana de Consultar folio.)*

---

## 3. Dashboard Admin — Administración de la plaza

Tablero operativo del día a día, pensado para quien administra la plaza. Se actualiza en vivo y permite filtrar por período (Hoy, Ayer, Antier, Esta semana, Este mes o un rango personalizado).

**Indicadores principales (KPIs):**
- Ingresos del período, tickets emitidos, autos en plaza en este momento, boletos perdidos, ticket promedio, % de ocupación.

**Tableros visuales:**
- **Ocupación actual:** medidor visual de cajones ocupados, desglosado por tipo (Normal / Preferencial / Empleado / Pensión).
- **Desglose de tickets:** participación de cada tipo de boleto (Normal, Preferencial, Perdido, Cortesía, Pensión, Empleado), con montos.
- **Rendimiento por cajero:** ranking de cajeros por ingresos generados en el período.
- **Ingresos por franja horaria:** comparación de las tres franjas de operación (mañana, mediodía, tarde-noche).
- **Actividad — Comparativo:** número de tickets por hora, superponiendo el período actual contra el período anterior equivalente, para ver de un vistazo si la plaza está creciendo o bajando.
- **Ingresos por cajero y día:** tabla semanal con el ingreso de cada cajero por día, con totales por día y total general.
- **Corte del día:** detalle completo de todas las operaciones del período, exportable a Excel/CSV.

Todos los indicadores tienen **"drill-down"**: un clic sobre cualquier número abre el detalle exacto de los tickets que lo componen — nunca es una caja negra.

**Herramientas administrativas (menú):**
- **Parámetros del sistema:** tarifas, tolerancia, horarios de operación, capacidad de la plaza, catálogo de cajeros/operadores (con alta de usuario y contraseña) y catálogo de empleados con cortesía.
- **Bitácora de auditoría:** registro cronológico de toda acción sensible del sistema (logins, cobros, cancelaciones, cierres de turno), con filtros por fecha, usuario y tipo de acción, y exportación.
- **Consulta de tickets:** buscador avanzado sobre el historial completo — por folio, cajero, fechas, horas, montos — que muestra absolutamente todas las columnas del registro. Pensado como herramienta de soporte para ubicar rápido cualquier movimiento.
- **Gestión manual de tickets:** permite cancelar un boleto dejando registrado el motivo (para rastrear fallas del sistema), y capturar manualmente un movimiento cuando hubo una contingencia (ej. falla de energía) y no quedó registrado en automático.

*(Sugerencia de captura: vista general del tablero con los KPIs y las 6 tarjetas de gráficas, y una captura del drill-down/detalle abierto.)*

---

## 4. Dashboard Corporativo — Oficina Central

Vista consolidada para la dirección del negocio, organizada en pestañas:

- **🛠️ Admin:** una réplica del tablero operativo de Admin, para que Oficina Central pueda ver el mismo detalle del día a día sin necesitar credenciales de administrador de planta.
- **📊 Ejecutivo:** indicadores de alto nivel — ingresos totales, tickets del período, ocupación promedio (calculada como el tiempo real que cada auto ocupó un cajón dentro del horario de operación, no una foto instantánea), ingresos de los últimos 6 meses, avance contra la meta mensual, y el mismo desglose de tickets y actividad comparativa que Admin.
- **⚙️ Operativo:** análisis por franja horaria y tipo de operación.
- **👤 Cajeros:** comparativo de turnos y cortes de caja por cajero.
- **📈 Demanda:** el módulo de Análisis de Demanda embebido (ver sección 5).
- **📋 Cortes:** historial de cortes de caja realizados.

El indicador de **"Ocupación promedio"** incluye un reporte de transparencia: al hacer clic se puede ver, ticket por ticket, cuántos minutos aportó cada auto al cálculo — para que el número nunca sea una caja negra frente a la dirección.

*(Sugerencia de captura: pestaña Ejecutivo completa, y el detalle del cálculo de ocupación al hacer clic.)*

---

## 5. Análisis de Demanda

Módulo enfocado en patrones de uso, útil para decisiones de personal y horarios:

- **Mapa de calor** de demanda por día de la semana y hora del día — identifica de un vistazo las horas y días de mayor y menor actividad.
- **Evolución semana actual vs. semana pasada**, día por día.
- **Desglose de tickets de la semana** y **franjas horarias** (con % de ocupación promedio y pico por franja).
- **Ingresos por cajero y día** (esta semana).
- **Insights automáticos:** el sistema redacta en texto plano observaciones como horas pico, horarios de baja demanda, y comparación fin de semana vs. entre semana.

*(Sugerencia de captura: el mapa de calor completo.)*

---

## 6. Rendimiento de Cajeros

Tablero comparativo de desempeño por cajero, inspirado en un reporte de ventas por vendedor, con tres vistas intercambiables:

- **Semana actual vs. semana anterior**
- **Mes actual vs. mes anterior** (vista principal)
- **Acumulado del año vs. mismo período del año anterior**

**Contenido:**
- Tabla comparativa por cajero: tickets, importe, variación % y participación, con **mini-gráfica de tendencia** de los últimos 4 meses por cajero.
- **Drill-down por cajero:** al hacer clic se despliega el detalle por tipo de boleto y por franja horaria.
- Tabla de "Top días de la semana" (promedio de tickets por día).
- Tabla comparativa de los últimos 12 meses, con alertas automáticas (⚠ si un cajero cae más de 10%, 🔥 si sube más de 15%).
- **5 gráficas:** ingresos por mes (año contra año), evolución de tickets e ingresos por cajero en el tiempo, mezcla de tipo de boleto por cajero, y promedio diario contra el período anterior.
- Exportación a CSV de cualquier tabla o del detalle de un cajero en particular.
- Si por algún motivo no hay conexión a la base de datos, el tablero muestra datos de demostración claramente etiquetados, para nunca aparecer en blanco.

*(Sugerencia de captura: la tabla principal con el drill-down de un cajero abierto, y la fila de 4 gráficas.)*

---

## 7. Pensiones

Módulo de administración de clientes con mensualidad fija (arrendamiento de cajón por mes en lugar de cobro por visita), con su propio catálogo de clientes y vehículos.

---

## 8. Seguridad y control de acceso

- **Login por rol:** cada una de las aplicaciones (Caseta, Admin, Corporativo) exige usuario y contraseña, y solo permite entrar a quien tiene el rol correspondiente (cajero, administrador de plaza, corporativo).
- **Bitácora de auditoría:** toda acción relevante (inicios de sesión, cobros, cancelaciones, cierres de turno, capturas manuales) queda registrada con fecha, hora y usuario responsable, consultable desde Admin.
- **Trazabilidad de cancelaciones:** ningún boleto se puede cancelar sin dejar un motivo por escrito, y el boleto cancelado nunca se borra — solo se marca como tal, preservando el historial completo.

---

## 9. Confiabilidad de la información

Un principio de diseño transversal a todo el sistema: **ningún número se muestra sin poder rastrearse hasta el boleto que lo originó.** Todos los indicadores —desde un KPI en Admin hasta el % de ocupación en Corporativo— tienen un drill-down que muestra el detalle exacto detrás del cálculo. Esto permite que cualquier reporte se pueda auditar y validar en segundos, en lugar de tomarse como una caja negra.

---

## 10. Arquitectura técnica (resumen)

- **Base de datos en la nube** (Supabase/PostgreSQL), con la información sincronizada en tiempo real entre todas las aplicaciones.
- **Ambientes separados:** un ambiente de pruebas (QA) donde se valida cada cambio nuevo antes de tocar la operación real, y el ambiente de producción real de la plaza — ningún cambio llega a producción sin probarse primero.
- **Sin instalación de software especializado:** todo funciona desde el navegador, en cualquier tablet, computadora o celular con internet.
