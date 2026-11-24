program Reglas;

// Reglas de negocio que el usuario cambia sin recompilar la aplicación: el descuento de un pedido
// se calcula con un script de PascalAI que se edita en el formulario.
//
// Reglas.exe --prueba salida.txt  calcula unos pedidos sin mostrar la ventana y escribe el resultado.

uses
  System.SysUtils,
  Vcl.Forms,
  UPrincipal in 'UPrincipal.pas' {FPrincipal};


begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  if SameText(ParamStr(1), '--prueba') then
    Application.ShowMainForm := False;
  Application.CreateForm(TFPrincipal, FPrincipal);
  Application.Run;
end.
