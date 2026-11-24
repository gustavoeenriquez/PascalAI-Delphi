unit UPrincipal;

// El formulario: TPaiEngine (de la paleta PascalAI), un memo con las reglas y un pedido de prueba.
// La aplicación le da al script una función suya (PrecioDe) y llama la función Descuento del script.

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  PascalAI.Engine;

type
  TFPrincipal = class(TForm)
    Motor: TPaiEngine;
    PanelPedido: TPanel;
    LblProducto: TLabel;
    EdProducto: TEdit;
    LblCantidad: TLabel;
    EdCantidad: TEdit;
    ChkVip: TCheckBox;
    BtnCalcular: TButton;
    MemoReglas: TMemo;
    MemoResultado: TMemo;
    Divisor: TSplitter;
    procedure FormCreate(Sender: TObject);
    procedure BtnCalcularClick(Sender: TObject);
  private
    function Calcular(const Producto: string; Cantidad: Integer; Vip: Boolean): string;
    procedure Prueba;
  end;

var
  FPrincipal: TFPrincipal;

implementation

{$R *.dfm}

const
  REGLAS_INICIALES =
    '// Las reglas de descuento. Cámbialas y pulsa Calcular: no hay que recompilar la aplicación.' + sLineBreak +
    '' + sLineBreak +
    'function Descuento(const Producto: string; Cantidad: Integer; Vip: Boolean): Double;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := 0;' + sLineBreak +
    '  if Cantidad >= 10 then Result := 0.10;          // por volumen' + sLineBreak +
    '  if Vip then Result := Result + 0.05;            // clientes VIP' + sLineBreak +
    '  if PrecioDe(Producto) * Cantidad > 500000 then  // pedidos grandes' + sLineBreak +
    '    Result := Result + 0.03;' + sLineBreak +
    '  if Result > 0.15 then Result := 0.15;           // nunca más del 15 %' + sLineBreak +
    'end;';

function PrecioDe(const Producto: string): Double;
begin
  if SameText(Producto, 'molino') then
    Result := 89000
  else if SameText(Producto, 'cafetera') then
    Result := 145000
  else
    Result := 25000;
end;

procedure TFPrincipal.FormCreate(Sender: TObject);
begin
  MemoReglas.Text := REGLAS_INICIALES;
  // una función de la aplicación que el script puede usar; la firma va en Pascal
  Motor.RegisterFunction('function PrecioDe(const Producto: string): Double;',
    procedure(const C: TPaiCall)
    begin
      C.Result.AsFloat := PrecioDe(C.Arg(0).AsString);
    end);
  if SameText(ParamStr(1), '--prueba') then
    Prueba;
end;

function TFPrincipal.Calcular(const Producto: string; Cantidad: Integer; Vip: Boolean): string;
var
  Prog: IPaiProgram;
  Diag: TPaiDiagnostics;
begin
  // TryCompile no lanza: si las reglas tienen un error, se muestra en vez del resultado
  // (los diagnósticos los libera quien llama)
  var Ok := Motor.TryCompile(MemoReglas.Text, 'reglas', Prog, Diag);
  try
    if not Ok then
      Exit('Las reglas tienen errores:' + sLineBreak + Diag.ToText.Trim);
  finally
    Diag.Free;
  end;
  var Ctx := Prog.NewContext;
  var D := Ctx.Call('Descuento', [Producto, Cantidad, Vip]).AsFloat;
  var Bruto := PrecioDe(Producto) * Cantidad;
  Result := Format('%d x %s = %.0n   descuento %.0f %%   total %.0n',
    [Cantidad, Producto, Bruto, D * 100, Bruto * (1 - D)]);
end;

procedure TFPrincipal.BtnCalcularClick(Sender: TObject);
begin
  try
    MemoResultado.Lines.Add(Calcular(EdProducto.Text, StrToIntDef(EdCantidad.Text, 1), ChkVip.Checked));
  except
    on E: Exception do
      MemoResultado.Lines.Add(E.ClassName + ': ' + E.Message);
  end;
end;

procedure TFPrincipal.Prueba;
// Reglas.exe --prueba salida.txt: unos pedidos con las reglas iniciales, con una regla cambiada y con un error
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    try
      L.Add(Calcular('molino', 2, False));
      L.Add(Calcular('cafetera', 12, True));
      L.Add(Calcular('molino', 6, False));
      // la regla por volumen baja de 10 a 5 unidades, sin recompilar
      MemoReglas.Text := StringReplace(MemoReglas.Text, 'Cantidad >= 10', 'Cantidad >= 5', []);
      L.Add(Calcular('molino', 6, False));
      MemoReglas.Text := 'function Descuento(const Producto: string; Cantidad: Integer; Vip: Boolean): Double;' +
        sLineBreak + 'begin Result := Cantidad * ; end;';
      L.Add(Calcular('molino', 1, False));
    except
      on E: Exception do
        L.Add(E.ClassName + ': ' + E.Message);
    end;
    L.WriteBOM := False;
    L.SaveToFile(ParamStr(2), TEncoding.UTF8);
  finally
    L.Free;
  end;
  Application.Terminate;
end;

end.
