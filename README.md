# PascalAI para Delphi

**Español** · [English](README.en.md)

El motor de [PascalAI](https://github.com/gustavoeenriquez/PascalAI-Learn) dentro de tu aplicación Delphi:
un componente `TPaiEngine` en la paleta que compila y corre programas de PascalAI (reglas de negocio que el
usuario cambia sin recompilar, agentes y flujos de IA, código que escribe un modelo y corre en un sandbox).

```pascal
uses PascalAI.Engine;

var Ctx := Motor.Compile(
  'function Descuento(Cantidad: Integer): Double;' + sLineBreak +
  'begin if Cantidad >= 10 then Result := 0.10 else Result := 0; end;').NewContext;
ShowMessage(FloatToStr(Ctx.Call('Descuento', [12]).AsFloat));   // 0,1
```

Este repositorio tiene los **paquetes compilados** (en [Releases](https://github.com/gustavoeenriquez/PascalAI-Delphi/releases)),
los ejemplos y la documentación. El código del motor no es público.

## Requisitos

- **Delphi 13** (RAD Studio 13, compilador 37.0). Las DCU de Delphi solo sirven para la versión con que se
  compilaron: con otra versión, el compilador dice que no encuentra o no puede usar las unidades.
- Hay dos descargas, según tu edición de Delphi:

  | Descarga | Para | Bases de datos desde los scripts |
  |---|---|---|
  | `...-delphi13-community.zip` | Community y Professional | SQLite |
  | `...-delphi13-enterprise.zip` | Enterprise y Architect | SQLite, PostgreSQL y MySQL/MariaDB |

  La diferencia son los drivers de FireDAC para PostgreSQL y MySQL, que solo trae Enterprise. Con la versión
  Community, un script que abre una base postgres recibe un `EConfigError` que lo explica.
- Windows: aplicaciones de **32 y 64 bits** (VCL, FMX o de consola).
- Para usar modelos de IA desde los scripts, la clave del proveedor en una variable de entorno
  (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`...), o un Ollama local. Nunca en el código.

## Instalar

1. Descarga el zip de tu edición de [Releases](https://github.com/gustavoeenriquez/PascalAI-Delphi/releases)
   y descomprímelo, por ejemplo en `C:\PascalAI-Delphi`. Si quieres, compara su SHA-256 con `SHA256SUMS.txt`.
2. **Ruta de las unidades.** En *Tools > Options > Language > Delphi > Library*, para cada plataforma, agrega a
   *Library path* su carpeta `dcu`:
   - Windows 32-bit: `C:\PascalAI-Delphi\Win32\dcu`
   - Windows 64-bit: `C:\PascalAI-Delphi\Win64\dcu`
3. **El IDE tiene que encontrar `PascalAI.bpl`.** En *Tools > Options > IDE > Environment Variables*, agrega
   a `PATH` (con *Add Override*) la carpeta del IDE que usas: `C:\PascalAI-Delphi\Win32` para el IDE de 32 bits,
   `C:\PascalAI-Delphi\Win64` para el de 64 bits. Reinicia el IDE.
4. *Component > Install Packages > Add...* y elige `PascalAIDesign.bpl` de esa misma carpeta.
   En la paleta aparece la página **PascalAI** con `TPaiEngine` y `TPaiScript`.

Tu aplicación queda **enlazada estáticamente**: no hay que distribuir ningún BPL con ella, salvo que compiles
con paquetes de ejecución (*Link with runtime packages* con `PascalAI`).

## Ejemplos

| Carpeta | Qué muestra |
|---|---|
| [`ejemplos/01-consola`](ejemplos/01-consola/Consola.dpr) | Lo básico de la API: compilar, leer variables, llamar funciones del script, darle al script una función y un objeto de la aplicación, el sandbox y un modelo de IA (`mock`, sin red) |
| [`ejemplos/02-reglas-vcl`](ejemplos/02-reglas-vcl) | Un formulario con `TPaiEngine` de la paleta: las reglas de descuento son un script que el usuario edita y prueba sin recompilar; los errores del script se muestran, no rompen la aplicación |

Abre el `.dpr` en el IDE (crea el proyecto la primera vez). Desde la línea de comandos:

```bat
dcc64 -NSSystem;Winapi;Vcl -UC:\PascalAI-Delphi\Win64\dcu ejemplos\01-consola\Consola.dpr
```

## Lo esencial de la API

| Para | Usa |
|---|---|
| Compilar | `Motor.Compile(Fuente)` (lanza `EPaiCompileError`) o `Motor.TryCompile(Fuente, Nombre, Prog, Diag)` (no lanza; libera `Diag`) |
| Correr | `Ctx := Prog.NewContext; Ctx.Run;` y lo escrito con `WriteLn` en `Ctx.OutputText` |
| Pasar y leer datos | `Motor.DeclareGlobal('Cliente', 'string')` y `Ctx.Globals['Cliente']`; `Ctx.Call('Funcion', [Args])` |
| Darle funciones al script | `Motor.RegisterFunction('function PrecioDe(const P: string): Double;', procedure(const C: TPaiCall) ...)` |
| Darle objetos al script | `Motor.RegisterClass(TCliente, ['Nombre', 'Abonar'])` y `TPaiValue.FromObject(Obj, soBorrowed)` |
| Limitar | `Motor.Profile := spPure` (sin disco ni red), `Motor.Limits.MaxTimeMs`, `MaxMemoryBytes`... |
| Código que no es de confianza | `Motor.SandboxRun(Codigo)`: nunca lanza; `Ok`, `Output`, `ErrorMessage`, `Json` |
| Bases de datos | `PaiSqlConfigure('ventas', 'sqlite; path=ventas.db', CarpetaBase)` (unidad `PascalAI.Sql`) y en el script `Database('ventas')` |
| Agentes y procesos | `Ctx.Spawn`, `Ctx.Process('nombre')`, canales y eventos del script hacia la aplicación |

La referencia completa está en la [especificación de la API de host](docs/api-host.md).

## Licencia

Los paquetes se pueden usar gratis con fines educativos y personales. Para cualquier otro uso (por ejemplo,
una aplicación comercial), hay que pedir permiso al autor. Ver [LICENCIA.txt](LICENCIA.txt).
Los ejemplos de este repositorio son MIT: cópialos y úsalos en tus programas.
