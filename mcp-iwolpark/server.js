#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const SUPABASE_URL = process.env.SUPABASE_URL || "https://knaibgqehwvjuclsfdmo.supabase.co";
const SUPABASE_KEY =
  process.env.SUPABASE_ANON_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtuYWliZ3FlaHd2anVjbHNmZG1vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2MzEzNjcsImV4cCI6MjA5OTIwNzM2N30.CCUxpvi8IdAtxwx5PUBefstJvflmUabovE92IbotGvE";

// Solo estas tablas son accesibles desde este MCP, aunque el anon key/RLS
// permitieran otras — el alcance de esta herramienta es IwolPark (tickets/cortes).
const ALLOWED_TABLES = ["tickets", "cortes"];
const tableSchema = z.enum(ALLOWED_TABLES).describe("Tabla: 'tickets' o 'cortes'");

function buildHeaders(extra = {}) {
  return {
    apikey: SUPABASE_KEY,
    Authorization: `Bearer ${SUPABASE_KEY}`,
    "Content-Type": "application/json",
    ...extra,
  };
}

// Convierte { columna: valor } a query params estilo PostgREST.
// Si el valor ya trae un operador ('gte.2026-07-01', 'like.Tester*', 'in.(a,b)')
// se respeta tal cual; si no, se asume igualdad ('eq.').
function filtersToParams(filters) {
  const params = new URLSearchParams();
  for (const [col, raw] of Object.entries(filters || {})) {
    const val = String(raw);
    const hasOperator = /^[a-z]+\./.test(val);
    params.append(col, hasOperator ? val : `eq.${val}`);
  }
  return params;
}

const server = new McpServer({ name: "iwolpark-db", version: "1.0.0" });

server.tool(
  "iwolpark_select",
  "Consulta filas de 'tickets' o 'cortes' en la base de datos de IwolPark (Supabase), respetando las políticas RLS del anon key.",
  {
    table: tableSchema,
    select: z.string().optional().describe("Columnas a devolver, ej. 'folio,estatus,importe'. Por defecto '*'."),
    filters: z
      .record(z.string())
      .optional()
      .describe("Filtros columna->valor. Usa operador PostgREST (ej. 'gte.2026-07-01') o un valor simple para igualdad."),
    order: z.string().optional().describe("Ej. 'created_at.desc'"),
    limit: z.number().int().min(1).max(1000).optional().default(50),
  },
  async ({ table, select, filters, order, limit }) => {
    const params = filtersToParams(filters);
    params.set("select", select || "*");
    params.set("limit", String(limit ?? 50));
    if (order) params.set("order", order);
    const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${params.toString()}`, {
      headers: buildHeaders(),
    });
    const body = await r.text();
    if (!r.ok) return { content: [{ type: "text", text: `Error ${r.status}: ${body}` }], isError: true };
    return { content: [{ type: "text", text: body }] };
  }
);

server.tool(
  "iwolpark_count",
  "Cuenta cuántas filas de 'tickets' o 'cortes' cumplen los filtros dados.",
  {
    table: tableSchema,
    filters: z.record(z.string()).optional(),
  },
  async ({ table, filters }) => {
    const params = filtersToParams(filters);
    params.set("select", "id");
    params.set("limit", "1");
    const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${params.toString()}`, {
      headers: buildHeaders({ Prefer: "count=exact" }),
    });
    if (!r.ok) {
      const body = await r.text();
      return { content: [{ type: "text", text: `Error ${r.status}: ${body}` }], isError: true };
    }
    const range = r.headers.get("content-range") || "";
    const total = range.split("/")[1] || "desconocido";
    return { content: [{ type: "text", text: total }] };
  }
);

server.tool(
  "iwolpark_insert",
  "Inserta una fila nueva en 'tickets' o 'cortes'.",
  {
    table: tableSchema,
    data: z.record(z.any()).describe("Objeto columna->valor a insertar"),
  },
  async ({ table, data }) => {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
      method: "POST",
      headers: buildHeaders({ Prefer: "return=representation" }),
      body: JSON.stringify(data),
    });
    const body = await r.text();
    if (!r.ok) return { content: [{ type: "text", text: `Error ${r.status}: ${body}` }], isError: true };
    return { content: [{ type: "text", text: body }] };
  }
);

server.tool(
  "iwolpark_update",
  "Actualiza filas de 'tickets' o 'cortes' que cumplan los filtros. Los filtros son obligatorios para evitar updates masivos accidentales.",
  {
    table: tableSchema,
    filters: z.record(z.string()).describe("Filtros obligatorios, ej. { folio: 'UFC-829' }"),
    data: z.record(z.any()).describe("Columnas a actualizar"),
  },
  async ({ table, filters, data }) => {
    if (!filters || Object.keys(filters).length === 0) {
      return {
        content: [{ type: "text", text: "Rechazado: se requieren filtros para actualizar (no se permite update sin condiciones)." }],
        isError: true,
      };
    }
    const params = filtersToParams(filters);
    const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${params.toString()}`, {
      method: "PATCH",
      headers: buildHeaders({ Prefer: "return=representation" }),
      body: JSON.stringify(data),
    });
    const body = await r.text();
    if (!r.ok) return { content: [{ type: "text", text: `Error ${r.status}: ${body}` }], isError: true };
    return { content: [{ type: "text", text: body }] };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
