-- pension_id ya existía en tickets pero sin FK real — sin eso PostgREST no
-- puede hacer el embed automático (tickets?select=*,pensiones(...)) que
-- necesita la ventana de Movimientos para mostrar cliente/tipo/vehículo de
-- la pensión sin una segunda consulta manual.
alter table tickets add constraint tickets_pension_id_fkey
  foreign key (pension_id) references pensiones(pension_id);
