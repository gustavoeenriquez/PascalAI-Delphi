program Asistente;

// Un asistente de IA dentro de una aplicación Delphi, configurado con pai.package como un programa de pai:
// el proveedor, el modelo y la base de datos salen del archivo, no del código.
//
//   - Engine.LoadPackageConfig busca pai.package en la carpeta del ejecutable y hacia arriba.
//   - Tal como viene, el modelo es mock/costo (responde sin red ni claves). Para uno de verdad, quita el ';'
//     de las líneas de [providers] y [models] en pai.package (Ollama local o Claude con ANTHROPIC_API_KEY).
//   - El modelo consulta la base de pedidos con una herramienta escrita en el script (PedidosDe).
//
// Uso: Asistente.exe "¿Qué pedidos tiene el Hotel Andino?"

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, PascalAI.Engine;

const
  SCRIPT =
    'uses SysUtils, Pai.AI;' + sLineBreak +
    '' + sLineBreak +
    '/// Los pedidos de un cliente: producto, cantidad y estado, uno por línea.' + sLineBreak +
    '[Tool]' + sLineBreak +
    'function PedidosDe(const Cliente: string): string;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := '''';' + sLineBreak +
    '  for var F in Database(''pedidos'').Rows(' + sLineBreak +
    '      ''select producto, cantidad, estado from pedido where cliente like :c'', C := ''%'' + Cliente + ''%'') do' + sLineBreak +
    '    Result := Result + Format(''%s x %d (%s)'', [F.Str(''producto''), F.Int(''cantidad''), F.Str(''estado'')]) + sLineBreak;' + sLineBreak +
    '  if Result = '''' then Result := ''No hay pedidos de ese cliente.'';' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'model Asistente' + sLineBreak +
    '  primary ''mock/costo'';' + sLineBreak +
    '  system ''Eres el asistente de ventas de Café La Montaña. Respondes corto y en español. '' +' + sLineBreak +
    '    ''Para saber los pedidos de un cliente, usa PedidosDe.'';' + sLineBreak +
    '  tools PedidosDe;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'function Preguntar(const Texto: string): string;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := Asistente.Ask(Texto);' + sLineBreak +
    'end;';

  DATOS =
    'create table if not exists pedido (cliente text, producto text, cantidad integer, estado text);' +
    'delete from pedido;' +
    'insert into pedido values (''Hotel Andino'', ''café de origen 500 g'', 40, ''despachado'');' +
    'insert into pedido values (''Hotel Andino'', ''molino'', 2, ''por despachar'');' +
    'insert into pedido values (''Sofía Ríos'', ''cafetera'', 1, ''entregado'');';

var
  Engine: TPaiEngine;
begin
  SetConsoleOutputCP(CP_UTF8);
  SetTextCodePage(Output, CP_UTF8);
  try
    Engine := TPaiEngine.Create(nil);
    try
      // [providers], [models] y [databases] de pai.package (las claves, siempre en variables de entorno)
      Engine.LoadPackageConfig(ExtractFilePath(ParamStr(0)));
      var Ctx := Engine.Compile(SCRIPT, 'asistente').NewContext;
      // datos de ejemplo (empresa, personas y datos ficticios)
      Engine.Compile('Database(''pedidos'').Exec(''' + DATOS.Replace('''', '''''') + ''');', 'datos').NewContext.Run;
      var Pregunta := '¿Qué pedidos tiene el Hotel Andino?';
      if ParamCount > 0 then
        Pregunta := ParamStr(1);
      Writeln('> ', Pregunta);
      Writeln(Ctx.Call('Preguntar', [Pregunta]).AsString);
      Ctx := nil;
    finally
      Engine.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
