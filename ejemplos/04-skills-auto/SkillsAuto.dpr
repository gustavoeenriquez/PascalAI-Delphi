program SkillsAuto;

// Skills y herramientas automáticas dentro de una aplicación Delphi, con la configuración de pai.package.
//
//   - Engine.LoadPackageConfig fija la carpeta del proyecto (la de pai.package): desde ahí se leen [skills] y
//     [auto], y ahí instala tools auto (pai_packages/, pai.lock), aunque la carpeta actual sea otra.
//   - Redactor: tools skill('estilo') le da la guía de ia/estilo/SKILL.md (una skill del proyecto).
//   - Explorador: tools auto busca en el registry de PascalAI un paquete que le falte, lo instala y lo usa.
//     [auto] dice qué puede instalar (permitir) y que antes se le pregunte a la persona (aprobar = instalar).
//   - La pregunta la contesta la aplicación: PaiHumanHandler (aquí, en la consola; en una app VCL, un diálogo).
//
// Tal como viene, los modelos son mock/pasos: sin claves, cada pregunta dice qué herramientas llamar
// ([[herramienta {argumentos}]], una ronda por cada parte separada por >>). Para un modelo de verdad, quita el ';'
// de [providers] y [models] en pai.package y pregunta normal:
//   SkillsAuto.exe "Avísale a Sofía que su cafetera llega el viernes" "¿Cuánto es la raíz de 2 por 40?"
//
// tools auto necesita internet (registry.cimamaker.com). mcp-calculator es un programa de Windows de 64 bits.

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, PascalAI.Engine, PascalAI.AI.Human;

const
  SCRIPT =
    'uses SysUtils, Pai.AI;' + sLineBreak +
    '' + sLineBreak +
    'model Redactor' + sLineBreak +
    '  primary ''mock/pasos'';' + sLineBreak +
    '  system ''Escribes los mensajes a los clientes de Café La Montaña. Antes de escribir, lee la skill estilo.'';' + sLineBreak +
    '  tools skill(''estilo'');' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'model Explorador' + sLineBreak +
    '  primary ''mock/pasos'';' + sLineBreak +
    '  system ''Si te falta una herramienta, búscala en el registry (en inglés, una o dos palabras), instálala y úsala.'';' + sLineBreak +
    '  maxsteps 8;' + sLineBreak +
    '  tools auto;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'function Redactar(const Pedido: string): string;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := Redactor.Ask(Pedido);' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'function Resolver(const Pedido: string): string;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := Explorador.Ask(Pedido);' + sLineBreak +
    'end;';

  // Las preguntas para mock/pasos: qué herramientas pide el modelo en cada ronda
  PEDIDO_MOCK = '[[skill_estilo {}]]';
  PROBLEMA_MOCK = '[[search_packages {"query":"calculator"}]] >> [[install_package {"name":"mcp-calculator"}]] >> ' +
    '[[mcp-calculator {"operation":"evaluate","expression":"sqrt(2) * 40"}]]';

var
  Engine: TPaiEngine;
begin
  SetConsoleOutputCP(CP_UTF8);
  SetTextCodePage(Output, CP_UTF8);
  try
    // Quién contesta las preguntas de tools auto ("¿Instalar el paquete ...?"): la aplicación
    PaiHumanHandler :=
      function(const AId, AQuestion: string; const AOptions: TArray<string>; ATimeoutMs: Integer): string
      begin
        Write('? ', AQuestion, ' [s/n] ');
        Readln(Result);
        if Result.Trim = '' then
          Result := 'no';
        if SameText(Result.Trim, 's') then
          Result := 'sí';
      end;

    Engine := TPaiEngine.Create(nil);
    try
      // [providers], [models], [skills] y [auto] de pai.package; la carpeta del proyecto es la del archivo
      Engine.LoadPackageConfig(ExtractFilePath(ParamStr(0)));
      var Ctx := Engine.Compile(SCRIPT, 'skills-auto').NewContext;

      var Pedido := PEDIDO_MOCK;
      var Problema := PROBLEMA_MOCK;
      if ParamCount >= 1 then
        Pedido := ParamStr(1);
      if ParamCount >= 2 then
        Problema := ParamStr(2);

      Writeln('== Una skill del proyecto');
      Writeln('> ', Pedido);
      Writeln(Ctx.Call('Redactar', [Pedido]).AsString);
      Writeln;
      Writeln('== tools auto: buscar, instalar y usar');
      Writeln('> ', Problema);
      Writeln(Ctx.Call('Resolver', [Problema]).AsString);
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
