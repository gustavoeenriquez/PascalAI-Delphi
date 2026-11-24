program Consola;

// PascalAI dentro de un programa Delphi: lo básico de la API de host, de principio a fin.
//
//   1. Compilar un script y leer sus variables.
//   2. Llamar una función del script sin recompilar.
//   3. Darle al script una función de la aplicación.
//   4. Prestarle un objeto de la aplicación.
//   5. Correr código que no es de confianza (por ejemplo, escrito por un modelo) en el sandbox.
//   6. Un modelo de IA desde el script (mock/costo: responde sin red ni claves).
//   7. Una base de datos SQLite que declara la aplicación.
//
// Compilar: en el IDE, Project > Options > Delphi Compiler > Search path = la carpeta dcu de
// PascalAI para la plataforma (por ejemplo, C:\PascalAI-Delphi\Win64\dcu).

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, PascalAI.Engine;

type
  {$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}
  TCliente = class
  private
    FNombre: string;
    FSaldo: Double;
  public
    constructor Create(const ANombre: string; ASaldo: Double);
    function Abonar(Monto: Double): Double;
    property Nombre: string read FNombre write FNombre;
    property Saldo: Double read FSaldo;
  end;

constructor TCliente.Create(const ANombre: string; ASaldo: Double);
begin
  inherited Create;
  FNombre := ANombre;
  FSaldo := ASaldo;
end;

function TCliente.Abonar(Monto: Double): Double;
begin
  FSaldo := FSaldo + Monto;
  Result := FSaldo;
end;

procedure Titulo(const S: string);
begin
  Writeln;
  Writeln('== ', S);
end;

var
  Engine: TPaiEngine;
  Prog: IPaiProgram;
  Ctx: IPaiContext;
  Ana: TCliente;
begin
  SetConsoleOutputCP(CP_UTF8);
  SetTextCodePage(Output, CP_UTF8);
  try
    Engine := TPaiEngine.Create(nil);
    Ana := TCliente.Create('Ana', 100);
    try
      // 1 y 2. Compilar, correr y llamar
      Titulo('1. Compilar y leer una variable');
      Prog := Engine.Compile(
        'var Total: Integer;' + sLineBreak +
        'function Doble(X: Integer): Integer; begin Result := X * 2; end;' + sLineBreak +
        'Total := Doble(21);', 'ejemplo');
      Ctx := Prog.NewContext;
      Ctx.Run;
      Writeln('Total = ', Ctx.Globals['Total'].AsInteger);
      Titulo('2. Llamar una función del script');
      Writeln('Doble(10) = ', Ctx.Call('Doble', [10]).AsInteger);

      // 3. Una función de la aplicación, con su firma en Pascal
      Titulo('3. Una función de la aplicación');
      Engine.RegisterFunction('function PrecioDe(const Producto: string): Double;',
        procedure(const C: TPaiCall)
        begin
          if SameText(C.Arg(0).AsString, 'molino') then
            C.Result.AsFloat := 89000
          else
            C.Result.AsFloat := 25000;
        end);
      Engine.DeclareGlobal('Cantidad', 'Integer', TPaiValue.From(3));
      Ctx := Engine.Compile(
        'uses SysUtils;' + sLineBreak +
        'WriteLn(''3 molinos: '', Format(''%.0f'', [PrecioDe(''molino'') * Cantidad]));', 'precios').NewContext;
      Ctx.Run;
      Write(Ctx.OutputText);

      // 4. Un objeto de la aplicación: el script lo usa, pero no lo libera
      Titulo('4. Un objeto de la aplicación');
      Engine.RegisterClass(TCliente, ['Nombre', 'Saldo', 'Abonar']);
      Engine.DeclareGlobal('Cliente', 'TCliente');
      Ctx := Engine.Compile(
        'uses SysUtils;' + sLineBreak +
        'Cliente.Abonar(50);' + sLineBreak +
        'WriteLn(Cliente.Nombre, '' tiene '', Format(''%.0f'', [Cliente.Saldo]));', 'cliente').NewContext;
      Ctx.Globals['Cliente'] := TPaiValue.FromObject(Ana, soBorrowed);
      Ctx.Run;
      Write(Ctx.OutputText);
      Writeln('En Delphi, Ana.Saldo = ', Ana.Saldo:0:0);
      Ctx := nil;   // el contexto se libera antes que los objetos que tiene prestados

      // 5. Código que no es de confianza: sin disco, sin red y con límites
      Titulo('5. El sandbox');
      var R := Engine.SandboxRun('var S := 0; for var I := 1 to 10 do S := S + I; WriteLn(S);');
      Writeln('Ok: ', R.Ok, '  salida: ', R.Output.Trim);
      R := Engine.SandboxRun('uses IOUtils; TFile.WriteAllText(''x.txt'', ''hola'');');
      Writeln('Ok: ', R.Ok, '  ', R.ErrorClass, ': ', R.ErrorMessage);

      // 6. IA: el mismo código sirve con 'claude/...', 'openai/...' u 'ollama/...'
      Titulo('6. Un modelo de IA');
      Ctx := Engine.Compile(
        'uses Pai.AI;' + sLineBreak +
        'model M primary ''mock/costo''; end;' + sLineBreak +
        'function Preguntar(const Texto: string): string; begin Result := M.Ask(Texto); end;', 'ia').NewContext;
      Writeln(Ctx.Call('Preguntar', ['hola']).AsString);

      // 7. Una base de datos: la aplicación la declara y el script la abre por su nombre
      Titulo('7. Una base de datos');
      Engine.AddDatabase('ventas', 'sqlite; path=:memory:');
      Ctx := Engine.Compile(
        'var Db := Database(''ventas'');' + sLineBreak +
        'Db.Exec(''create table pedido (producto text, cantidad integer)'');' + sLineBreak +
        'Db.Exec(''insert into pedido values (:p, :c)'', P := ''molino'', C := 2);' + sLineBreak +
        'Db.Exec(''insert into pedido values (:p, :c)'', P := ''cafetera'', C := 12);' + sLineBreak +
        'WriteLn(''unidades vendidas: '', Db.Scalar<Integer>(''select sum(cantidad) from pedido''));', 'ventas').NewContext;
      Ctx.Run;
      Write(Ctx.OutputText);
      Ctx := nil;
    finally
      Prog := nil;
      Engine.Free;
      Ana.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
