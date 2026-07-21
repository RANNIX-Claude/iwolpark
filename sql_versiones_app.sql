-- Control de versiones por app. Cada deploy actualiza estas filas; cada app
-- revisa su propia fila al iniciar sesión (y cada 60s) para saber si hay
-- una versión más nueva que la que trae cargada, y si es así, obliga a
-- actualizar antes de seguir usando el sistema.
create table if not exists versiones_app (
  app text primary key,
  version integer not null default 0,
  actualizado_en timestamptz default now()
);
