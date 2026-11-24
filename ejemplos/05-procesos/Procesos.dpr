program Procesos;

// Agentes y procesos de PascalAI que hablan con la aplicación Delphi.
//
//   1. La aplicación como agente: RegisterHostAgent declara un agente (TPantalla) que el script usa con
//      Process<TPantalla>('pantalla'); cada mensaje lo atiende Delphi.
//   2. Un agente vivo del script (TBarra), lanzado y llamado desde Delphi: guarda su estado entre llamadas.
//   3. Un proceso con hijos (Turno lanza una molienda por bebida, en paralelo) y sus eventos en la aplicación.
//
// Café La Montaña: empresa y datos ficticios.

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, PascalAI.Engine;

const
  SCRIPT =
    'uses SysUtils;' + sLineBreak +
    '' + sLineBreak +
    '/// La barra: un agente vivo. Atiende los pedidos de a uno y lleva la cuenta del día.' + sLineBreak +
    'agent TBarra' + sLineBreak +
    '  var' + sLineBreak +
    '    Hechas: Integer;' + sLineBreak +
    '  function Preparar(const Bebida: string): string;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'function TBarra.Preparar(const Bebida: string): string;' + sLineBreak +
    'begin' + sLineBreak +
    '  Process<TPantalla>(''pantalla'').Mostrar(''preparando '' + Bebida);' + sLineBreak +
    '  await Delay(300);' + sLineBreak +
    '  Inc(Hechas);' + sLineBreak +
    '  Result := Format(''Listo: %s (%d hoy)'', [Bebida, Hechas]);' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    '/// Moler el café de una bebida (tarda según la bebida)' + sLineBreak +
    'function Moler(const Bebida: string): string;' + sLineBreak +
    'begin' + sLineBreak +
    '  Process<TPantalla>(''pantalla'').Mostrar(''moliendo para '' + Bebida);' + sLineBreak +
    '  await Delay(200 + Length(Bebida) * 60);' + sLineBreak +
    '  Process<TPantalla>(''pantalla'').Mostrar(''listo el café de '' + Bebida);' + sLineBreak +
    '  Result := Bebida;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    '/// Un turno: una molienda por bebida, todas a la vez' + sLineBreak +
    'function Turno(const Bebidas: string): string;' + sLineBreak +
    'var' + sLineBreak +
    '  Ps: TArray<TProcess<string>>;' + sLineBreak +
    'begin' + sLineBreak +
    '  for var B in Bebidas.Split(['','']) do' + sLineBreak +
    '    Ps := Ps + [spawn Moler(B.Trim)];' + sLineBreak +
    '  Result := string.Join('', '', await all Ps);' + sLineBreak +
    'end;';

var
  Candado: TObject;

// Los mensajes llegan desde los hilos del motor: se escribe de a uno
procedure Escribir(const S: string);
begin
  TMonitor.Enter(Candado);
  try
    Writeln(S);
  finally
    TMonitor.Exit(Candado);
  end;
end;

begin
  SetConsoleOutputCP(CP_UTF8);
  SetTextCodePage(Output, CP_UTF8);
  Candado := TObject.Create;
  var Motor := TPaiEngine.Create(nil);
  try
    // 1. La aplicación como agente: el script le manda mensajes a 'pantalla'
    Motor.RegisterHostAgent('pantalla',
      'agent TPantalla' + sLineBreak +
      '  function Mostrar(const Texto: string): Boolean;' + sLineBreak +
      'end;',
      procedure(const M: IPaiMessage)
      begin
        if M.Method = 'Mostrar' then
        begin
          Escribir('  [pantalla] ' + M.Arg(0).AsString);
          M.Reply(True);       // una function: el proceso espera esta respuesta (sin ocupar un hilo)
        end;
      end);
    var Ctx := Motor.Compile(SCRIPT, 'procesos').NewContext;

    // 2. Un agente vivo del script, lanzado y llamado desde Delphi
    Escribir('== Un agente vivo');
    var Barra := Ctx.SpawnAgent('TBarra', [], 'barra');
    Escribir(Barra.Call('Preparar', ['capuchino']).AsString);
    Escribir(Barra.Call('Preparar', ['latte']).AsString);
    Barra.Stop;

    // 3. Un proceso con hijos, y sus eventos en la aplicación
    Escribir('');
    Escribir('== Un turno: tres moliendas a la vez');
    var P := Ctx.Spawn('Turno', ['capuchino grande, tinto, aromática'], nil,
      procedure(const E: TPaiProcessEvent)
      begin
        if E.Name = 'process.spawn' then
          Escribir('  [evento] process.spawn ' + E.ProcessName)
        else if E.Name = 'process.complete' then
          Escribir('  [evento] process.complete ' + E.ProcessName);
      end);
    P.Wait(10000);
    Escribir('Turno listo: ' + P.Result.AsString);
    P := nil;
    Barra := nil;
    Ctx := nil;
  finally
    Motor.Free;
    Candado.Free;
  end;
end.
