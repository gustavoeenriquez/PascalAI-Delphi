# API de host: PascalAI dentro de una aplicación Delphi

Unidad pública: `PascalAI.Engine` (el host no necesita usar ninguna otra en el caso común).

## 1. Objetos principales

| Tipo | Qué es | Vida | Hilos |
|---|---|---|---|
| `TPaiEngine` (`TComponent`) | Configuración: unidades nativas, rutas, perfil de permisos, límites, caché de unidades | La de la aplicación (o el formulario/datamodule) | Seguro: compilar desde varios hilos a la vez |
| `IPaiProgram` (interfaz, contada) | Resultado inmutable de compilar | Mientras alguien lo referencie | Compartible |
| `IPaiContext` (interfaz, contada) | Una ejecución: globales, pila, montón, límites | Una ejecución o varias llamadas seguidas | Un hilo a la vez |
| `TPaiValue` (record) | Valor que cruza la frontera host↔script | Por valor | — |

## 2. Uso básico

```pascal
uses PascalAI.Engine;

var
  Engine: TPaiEngine;
  Prog: IPaiProgram;
  Ctx: IPaiContext;
begin
  Engine := TPaiEngine.Create(nil);
  try
    Engine.Profile := spPure;
    Engine.Limits.MaxTimeMs := 2000;

    Prog := Engine.Compile(
      'var Total: Integer;' + sLineBreak +
      'function Doble(X: Integer): Integer; begin Result := X * 2; end;' + sLineBreak +
      'Total := Doble(21);', 'ejemplo');

    Ctx := Prog.NewContext;
    Ctx.Run;                                         // ejecuta el bloque principal
    Writeln(Ctx.Globals['Total'].AsInteger);         // 42
    Writeln(Ctx.Call('Doble', [10]).AsInteger);      // 20, sin recompilar
  finally
    Engine.Free;
  end;
end;
```

### 2.1 Compilar

```pascal
function Compile(const ASource: string; const AName: string = 'script'): IPaiProgram;
function CompileFile(const APath: string): IPaiProgram;
function TryCompile(const ASource, AName: string; out AProgram: IPaiProgram;
  out ADiagnostics: TPaiDiagnostics): Boolean;
function LoadProgram(const APath: string): IPaiProgram;      // .paic
procedure IPaiProgram.SaveToFile(const APath: string);       // .paic
procedure IPaiProgram.SaveToStream(AStream: TStream);
```

`Compile` lanza `EPaiCompileError` (con la lista completa en `.Diagnostics`). `TryCompile` no
lanza. `TPaiDiagnostics.ToJSON` produce el formato del CLI (`pai check --json`).

### 2.2 Variables de entrada y salida

Dos formas, combinables:

**a) Globales predeclaradas por el host** — el script las usa sin declararlas:

```pascal
Engine.DeclareGlobal('Input',  'string');
Engine.DeclareGlobal('Output', 'string');
Engine.DeclareGlobal('Intentos', 'Integer', TPaiValue.From(3));   // con valor por defecto
...
Ctx.Globals['Input'] := 'texto del LLM';
Ctx.Run;
Resultado := Ctx.Globals['Output'].AsString;
```

Las globales predeclaradas son **parte del programa compilado** (con tipo estático), no texto
inyectado. `DeclareGlobal` afecta a las compilaciones posteriores.

**b) Llamar una función del script con argumentos:**

```pascal
Ok := Ctx.Call('Validar', [Json, 3]).AsBoolean;
R  := Ctx.Call('Extraer', [Texto]).AsRecord<TMiRecord>;  // record Delphi ↔ record del script por nombre de campo
```

`Call` ejecuta primero el bloque de inicialización si el contexto no se ha inicializado (globales
y `initialization` de las unidades), pero **no** el bloque principal.

### 2.3 TPaiValue

Record (`PascalAI.Engine`) con conversión implícita desde `Integer`, `Int64`, `Double`, `Boolean`,
`string`, `TArray<string>` y `TArray<Integer>`; `From`, `FromArray`, `FromFields`, `FromRecord<T>`,
`FromJSON` y `FromObject(Obj, Propiedad)` para lo demás; accesores `AsInteger`, `AsInt64`, `AsFloat`,
`AsBoolean`, `AsString`, `AsArray`, `AsRecord<T>` (por RTTI, por nombre de campo), `AsObject` y
`AsJSON`; `Kind` (`pvNull`, `pvInteger`, `pvFloat`, `pvBoolean`, `pvString`, `pvArray`, `pvRecord`,
`pvObject`) para inspeccionar.

## 3. Ejecución, límites y eventos

```pascal
Ctx.Limits.MaxInstructions := 10_000_000;
Ctx.Limits.MaxTimeMs := 500;
Ctx.Limits.MaxMemoryBytes := 64 * 1024 * 1024;
Ctx.Run;                       // síncrono en el hilo que llama
Ctx.Cancel;                    // desde cualquier otro hilo
```

Eventos del motor (en el hilo de la ejecución; el host decide si sincroniza con la UI):

| Evento | Cuándo |
|---|---|
| `OnOutput(Ctx, Text)` | `Write`/`WriteLn` del script. Por defecto: consola en el CLI; en un host, se acumula en `Ctx.OutputText` |
| `OnEmit(Ctx, Name, Value)` | El script llama `Emit('progreso', 50)` (unidad `PascalAI.Host`). Para hooks/telemetría del grafo |
| `OnLog(Ctx, Level, Text)` | `Log.Info(...)` del script |
| `OnError(Ctx, Clase, Mensaje)` | Excepción no capturada, antes de propagarse al host |

Errores al host:
- `EPaiCompileError` — `Diagnostics: TPaiDiagnostics`.
- `EPaiRuntimeError` — `ScriptClass` (p. ej. `'EConvertError'`), `Message`, `StackTrace` (la traza
  como texto, como la imprime el CLI), `Frames` (`TArray<TPaiTraceFrame>` con función/archivo/línea,
  el más interno primero), `Code` (`PAI4xxx`/`PAI5xxx`).
- `EPaiLimitError` (hereda de la anterior) — límite superado; `Kind` dice cuál.

### 3.1 Código no confiable: `SandboxRun`

```pascal
var O := Default(TPaiSandboxOptions);   // Profile '' = pure, 10 s, 200 M instrucciones, 256 MB
O.Input := Datos;
O.Allow := ['fs.read:./datos/*'];
var R := Engine.SandboxRun(CodigoDelModelo, O);           // síncrono; no lanza por el código
if not R.Ok then DevolverAlModelo(R.Json);                // diagnósticos o error de ejecución
var D := Engine.SandboxCheck(CodigoDelModelo);            // solo compilar
```

- El mismo núcleo que `Sandbox.Run` del script: `TPaiSandboxOptions`/`TPaiSandboxResult` son
  `TCodeOptions`/`TCodeResult`.
- El techo es el del motor: `Profile`, `AllowedPaths` y `Permissions` son el padre del código (un `Allow` pedido no
  los supera), y `Limits` acota cada límite pedido. Los secretos, solo con `Allow('secret:NOMBRE')` explícito.
- El código solo ve la biblioteca y las unidades de código del host que se nombren en `SandboxUnits` (de
  `AddUnitSource`; las nativas y `PaiHost` no llegan al sandbox). Un nombre que no es una unidad de código es
  `EArgumentException`.
- `SandboxRun(Codigo, Opciones, Cancelado)`: la función se mira cada 50 ms; `True` cancela el código.

## 4. Exponer cosas del host al script

### 4.1 Funciones

La firma se escribe **en Pascal** y la implementación es un método anónimo con acceso tipado:

```pascal
Engine.RegisterFunction('function Sumar(A, B: Integer): Integer;',
  procedure(const C: TPaiCall)
  begin
    C.Result.AsInteger := C.Arg(0).AsInteger + C.Arg(1).AsInteger;
  end);

Engine.RegisterFunction('procedure Notificar(const Canal, Texto: string);',
  procedure(const C: TPaiCall)
  begin
    MiBus.Publicar(C.Arg(0).AsString, C.Arg(1).AsString);
  end, [nfThreadSafe]);
```

- `TPaiCall` separa argumentos y resultado (no comparten memoria: lo de Lape no puede pasar).
- Los parámetros `var`/`out` se escriben con `C.Arg(i).AsXxx := ...`.
- Una excepción Delphi dentro de la implementación se convierte en excepción del script.
- `nfThreadSafe` declara que la función se puede llamar desde varios contextos a la vez.

### 4.2 Unidades nativas

Para bibliotecas grandes, la unidad se declara con su `interface` en Pascal y se enlaza por nombre:

```pascal
type
  TMiUnidad = class(TPaiNativeUnit)
  protected
    procedure Declare(B: TPaiUnitBuilder); override;
  end;

procedure TMiUnidad.Declare(B: TPaiUnitBuilder);
begin
  B.Name := 'Facturas';
  B.Interface_ :=
    'type TFactura = record Numero: string; Total: Double; end;' +
    'function Buscar(const Numero: string): TFactura;' +
    'function Pendientes: TArray<TFactura>;';
  B.Bind('Buscar', DoBuscar);
  B.Bind('Pendientes', DoPendientes);
end;

Engine.RegisterUnit(TMiUnidad);      // el script hace: uses Facturas;
```

La biblioteca estándar (`SysUtils`, `Pai.JSON`...) no usa este mecanismo: sus nativas se registran por
nombre (`RegisterNative`) y el compilador conoce sus declaraciones. Para el host, en cambio, una unidad
nativa es interfaz en Pascal + enlaces. Las firmas en Pascal permiten además generar documentación y la
lista de símbolos para autocompletado o para darle contexto a una IA (`pai symbols Facturas`).

### 4.3 Clases y objetos por RTTI

```pascal
Engine.RegisterClass(TCliente);                 // métodos y propiedades públicos/published
Engine.RegisterClass(TCliente, ['Nombre', 'Saldo', 'Abonar']);   // lista blanca
Ctx.Globals['Cliente'] := TPaiValue.FromObject(MiCliente, soBorrowed);
```

Propiedad del objeto:
- `soBorrowed` — el host lo libera; el script no puede llamar `Free` (error `PAI4020`).
- `soOwned` — el contexto lo libera al terminar.

Los objetos que el script crea con `TCliente.Create(...)` son suyos (`Free` los libera; si no,
el contexto); los que devuelve un método del host quedan prestados. La global que recibe el
objeto se declara antes con `Engine.DeclareGlobal('Cliente', 'TCliente')`, y la clase padre se
registra antes que la hija.

Requiere `{$RTTI}` en las clases del host para los miembros que no son published. Se cubren
propiedades, métodos con tipos simples, `string`, records y objetos registrados. Los métodos
genéricos no se registran (la RTTI de Delphi no los expone: el host registra la versión concreta). Los eventos de una clase registrada (`procedure ... of object`) se conectan desde el script a un
método de un agente: `Sensor.OnLectura := M.Lectura;`. Cada disparo, desde el hilo que sea, es un
mensaje asíncrono a su buzón (no corre en el hilo del host); solo eventos sin resultado; al liberar el
contexto, los eventos conectados quedan en `nil` (libere el contexto antes que los objetos del host). Un
agente no lee globales que guardan objetos (PAI2630): los datos le llegan por mensaje. En un anfitrión,
los agentes con nombre siguen vivos después de `Ctx.Run` y el host les habla con `Ctx.Process('nombre')`
(un `IPaiAgent`); se detienen al liberar el contexto. El script puede heredar de una clase del host
(`class(TCliente)`): `inherited Create(...)` crea el objeto base; los métodos nativos no son
virtuales (una subclase los oculta, no los redefine).

### 4.4 Unidades de código del host

```pascal
Engine.AddUnitSource('Reglas', ReglasPas);   // código Pascal guardado en BD, configuración, etc.
```

### 4.5 Bases de datos y `pai.package`

Un programa usa `Database('ventas')` con las bases que declara `[databases]` de `pai.package`. Un host
las declara sin archivo, con la misma sintaxis, o toma un `pai.package` como lo hace `pai run` (desde un host no se
lee solo):

```pascal
Engine.BaseDir := 'C:\MiApp\datos';                      // las rutas relativas (vacía: la carpeta del .exe)
Engine.AddDatabase('ventas', 'sqlite; path=ventas.db');   // = ventas = sqlite; path=ventas.db de [databases]
Engine.AddDatabase('erp', 'postgres; url=postgres://app@db:5432/erp; password=secret:ERP_PG');
Engine.RemoveDatabase('erp');
Engine.LoadPackageConfig('C:\MiApp\pai.package');        // o una carpeta: busca pai.package en ella y hacia arriba
```

- `AddDatabase(Nombre, Spec, BaseDir = '')`: la línea se revisa al declararla: un motor desconocido (o, con
  `PAI_SQL_LOCAL`, la variante Community, `postgres`/`mysql`) da `EPaiError` con `EConfigError`. La conexión se abre en el primer
  uso, como en `pai`. Reemplaza otra base del mismo nombre.
- `LoadPackageConfig(Ruta)`: las secciones que toma `pai run` (`[databases]` y `[databases.<PAI_ENV>]`,
  `[providers]`, `[models]`, `[prices]`, `[stores]`, `[mcp]`, `[durable]`, `[timeouts]`, `[telemetry]`); las rutas
  relativas, contra la carpeta del archivo. `EPaiError` si no hay `pai.package`.
- En el componente, `Databases: TStrings` (una línea `nombre = spec` por base) y `BaseDir` son publicadas: se
  aplican al cargar el formulario y al cambiarlas (las de antes de la lista se olvidan); en diseño no se abre nada.
- Las bases son del proceso, como las de `pai`: las ven todos los motores. Al liberar un `TPaiEngine` se olvidan las
  que declaró él.
- **El proyecto.** `LoadPackageConfig` también fija la carpeta del proyecto del proceso: lo que `pai run`
  busca desde la carpeta del programa se busca ahí, y no desde la carpeta actual, aunque el programa venga de
  `Engine.Compile` sin archivo. Son `[skills]` (`tools skill('x')`), `[prompts]` (`TPrompt.Load`), `[config]`,
  `[auto]` (`tools auto`: busca, instala en `pai_packages/` y escribe `pai.lock` y `pai.package` de esa carpeta) y
  los paquetes instalados. La carpeta es una sola para todo el proceso: el último `LoadPackageConfig` manda. Sin él,
  todo eso se busca desde la carpeta actual, como antes.
- **Servidores MCP escritos en PascalAI.** Un `entrypoint` `.pas` (de `[mcp]` o de un paquete que instaló
  `tools auto`) y `$PAI` en un comando se corren con `pai`, que por defecto se busca junto al ejecutable de la
  aplicación. `TPaiEngine.PaiExe` (propiedad de clase, del proceso) da otra ruta. Los MCP con un ejecutable propio
  y las skills no lo necesitan.
- **Quién aprueba.** Con `aprobar = instalar, ejecutar` en `[auto]`, `tools auto` pregunta antes de instalar o de usar
  un paquete. En una aplicación contesta `PaiHumanHandler` (unidad `PascalAI.AI.Human`): una función que recibe la
  pregunta y devuelve `'sí'` o `'no'` (en la consola, o un diálogo en VCL/FMX). Ejemplo: `ejemplos/04-skills-auto`.
- **Claves en español o en inglés.** `[auto]` acepta las dos formas: `permitir`/`allow`, `negar`/`deny`,
  `autores`/`authors` y `aprobar`/`approve`, con los valores `instalar`/`install` y `ejecutar`/`run`.

## 5. Componente en el IDE

`TPaiEngine` se instala en la paleta (paquete de diseño `PascalAIDesign`, sin dependencias en el
núcleo) con propiedades publicadas: `Profile`, `Limits`, `SearchPaths`, `Units` (colección de
unidades nativas activas), `Databases` y `BaseDir` (§4.5) y los eventos de §3. Un componente opcional `TPaiScript` (fuente +
motor + evento `OnDone`) cubre el caso de "un script en un formulario".

Como el inspector de objetos solo asigna métodos, los eventos publicados son `OnScriptOutput`,
`OnScriptError`, `OnScriptEmit` y `OnScriptLog` (`procedure(Sender: TObject; ...) of object`);
desde código también se pueden usar `OnOutput`, `OnError`, `OnEmit` y `OnLog` con métodos
anónimos. `Units` lista nombres de unidades registradas con `PaiRegisterUnitClass`. Paquetes en
`packages/` (`PascalAI.dpk` de ejecución, `PascalAIDesign.dpk` de diseño) para el IDE de 32 y
de 64 bits. Delphi Community y Professional no traen los drivers de FireDAC para PostgreSQL y MySQL: la
variante Community de los paquetes queda solo con SQLite, y una base `postgres` o `mysql` da `EConfigError` al abrirse.

## 6. API de procesos

Todo lo que el script puede lanzar, el host también lo puede lanzar, y el host puede
participar en la conversación entre procesos como uno más.

### 6.1 Lanzar y esperar

```pascal
var P: IPaiProcess;
begin
  // Funciona igual para una función, un agente de tarea o un flujo
  P := Ctx.Spawn('Investigar', ['baterías de sodio'],
    procedure(const B: IPaiBoards)                     // siembra: corre ANTES de arrancar
    begin
      B['Board'].Values['Pregunta'] := 'baterías de sodio';
    end,
    procedure(const E: TPaiProcessEvent)               // eventos de esta ejecución y sus hijos
    begin
      // E.Kind (ekSpawn, ekComplete, ekFailed, ekCancelled, ekBoardChange, ekCustom; ekStart y
      // ekWaiting),
      // E.ProcessId, E.ProcessName, E.Parent, E.Flow, E.Node, E.DurationMs, E.Error, E.Value, E.ToJSON
      Telemetria.Registrar(E.ToJSON);
    end);
  P.Wait(60000);                          // o P.Cancel (se propaga a todos los descendientes)
  Writeln(P.Result.AsString);
  Writeln(P.Board['Board'].Values['Aprobado'].AsBoolean);
end;
```

`Ctx.Spawn` arranca una **ejecución raíz**: tiene sus propios blackboards. La siembra y
el manejador de eventos se pasan al arrancar, no se asignan después: así no hay carrera con el
primer proceso ni se pierden los primeros eventos.

| Miembro | Qué hace |
|---|---|
| `Ctx.Spawn(Nombre, Args, Seed, OnEvent): IPaiProcess` | Lanza y regresa enseguida; `Seed` y `OnEvent` son opcionales |
| `P.Wait(TimeoutMs)`, `P.Cancel`, `P.State` | Esperar, cancelar y consultar el estado |
| `P.Result` | Resultado |
| `P.ErrorClass`, `P.ErrorMessage`, `P.ErrorTrace`, `P.ErrorFrames`, `P.RaiseError` | La falla: clase, mensaje y la traza del script (texto y marcos); `RaiseError` la lanza como `EPaiRuntimeError` |
| `P.Board[Nombre]` | Blackboard de esa ejecución (lectura y escritura sincronizadas) |
| `P.Tree`, `Ctx.Processes` | Instantánea del árbol de procesos de la ejecución mientras corre: id, padre, nombre, rutina, estado, nodo de flujo, tiempo (`TPaiProcessInfo`) |
| `Engine.OnProcessEvent` | Todos los eventos de todas las ejecuciones del motor |
| `Engine.Find('cotizador')`, `Engine.ProcessNames` | Un agente con nombre de cualquier ejecución (`IPaiAgent`) y los nombres de los vivos |
| `Prog.Graph` | El grafo (§7): nodos, aristas y el dibujo de `pai graph` (JSON, Mermaid, DOT), para dibujar o exportar |
| `Engine.SchedulerThreads` | Hilos del planificador, compartidos por todas las ejecuciones del motor |

### 6.2 Hablar con agentes desde el host

```pascal
var C := Ctx.SpawnAgent('TCotizador', ['tarifas.json'], 'cotizador');
Precio := C.Call('Cotizar', [TPaiValue.FromRecord(Pedido)]).AsFloat;   // espera la respuesta
C.Send('Actualizar', ['tornillo', 0.12]);                                // no espera
C.Stop;
```

`Call` bloquea el hilo del host que llama, nunca un hilo del planificador. Desde la interfaz de
usuario se usa `C.CallAsync(..., procedure(const R: TPaiValue) ...)`, que entrega el resultado
con `TThread.Queue`.

### 6.3 El host como agente

El host registra **agentes nativos**: el script los ve como cualquier agente, y cada mensaje se ejecuta en
Delphi. `RegisterHostAgent(Nombre, Declaración, Manejador)` arma, con la declaración en Pascal, una clase de la unidad
implícita `PaiHostAgents`; `Process<TUI>('ui')` la da, y cada llamada llega al manejador en un hilo propio, de a una
por agente. Un `procedure` envía y sigue; una `function` espera la respuesta sin ocupar hilo. El manejador recibe un
`TPaiMessage` (`IPaiMessage`): `Method`, `Arg(I)`/`Arg('Nombre')`, `ArgsJson`, y contesta con `Reply(V)`,
`Fail(Clase, Mensaje)` (una excepción del script) o `ReplyLater` (contesta después, desde cualquier hilo); si vuelve
sin ninguna, la respuesta es `Null`. Los parámetros y el resultado viajan como JSON.

```pascal
Engine.RegisterHostAgent('ui',
  'agent TUI' +
  '  procedure Mostrar(const Texto: string);' +
  '  function Confirmar(const Pregunta: string): Boolean;' +
  'end;',
  procedure(const M: TPaiMessage)
  begin
    if M.Method = 'Mostrar' then
      TThread.Queue(nil, procedure begin Memo1.Lines.Add(M.Arg(0).AsString); end)
    else if M.Method = 'Confirmar' then
      M.ReplyLater(...);                 // responde cuando el usuario conteste: el proceso que
  end);                                  // preguntó queda en espera sin ocupar hilo
```

En el script: `Process<TUI>('ui').Mostrar('Listo');` o
`if Process<TUI>('ui').Confirmar('¿Publicar?') then ...`. Así se conectan la interfaz, las bases de
datos o los servicios de la aplicación con los procesos, sin estado compartido.

### 6.4 Canales y blackboards compartidos con el host

`Engine.CreateChannel<T>(Capacidad)` (`T` es `Integer`, `Int64`, `Double`, `Boolean` o `string`) crea un
canal (`IPaiChannel`) que el host le pasa a un proceso con `Ch.AsValue`, como argumento o global de tipo
`TChannel<T>`; el host lee y escribe con `Send` (no espera), `Receive(Plazo)`, `TryReceive` y `Close`, seguros para
hilos. `Ctx.SetProcessEvents(Proc)` recibe los eventos de lo que corre un contexto.

Humano en el ciclo: el anfitrión contesta `AskHuman`/`Approve` con
`PaiHumanHandler`; suspender y reanudar se hace con `[Durable]`: `P.SaveState` da el diario
de la ejecución y `Ctx.Restore` lo vuelve a poner para retomarla.

## 7. El grafo del programa

Como el ejecutable es un grafo, el host lo puede recorrer sin ejecutar nada y engancharse
a él mientras corre:

```pascal
var G := Prog.Graph;                                   // IPaiGraph (inmutable, con versión)
for var N in G.Nodes do
  Writeln(N.Name, ' : ', N.Kind, ' ', N.Inputs.Count, ' entradas');
for var E in G.Edges do
  Writeln(E.Source.Name, ' -', E.Kind, '-> ', E.Target.Name);
Writeln(G.ToJson);                                     // mismo formato que pai graph --format json

Engine.OnProcessEvent :=                               // grafo de instancias en vivo
  procedure(const E: TPaiProcessEvent)
  begin
    Log(E.Node.Name, E.Instance, E.State);             // qué instancia de qué nodo cambió de estado
  end;
```

| Operación | Estado |
|---|---|
| `Prog.Graph` (nodos, aristas, conectores, versión) y `ToJson`/`ToMermaid`/`ToDot` | Hecho; los puertos tipados, pendientes |
| Pausar y reanudar una ejecución raíz (`Ctx.Pause`, `Ctx.Resume`) | Hecho |
| Reemplazar la implementación de un nodo → nueva versión del grafo (`Prog.WithNode(...)`) | Hecho |

**Cambio en caliente**. `Prog.WithNode(Nombre, Codigo): IPaiProgram` da una versión nueva del
programa con una rutina global o un agente (su declaración y todos sus métodos) reemplazado; el programa
viejo no cambia. `Ctx.Upgrade(V2)` pasa un contexto a la versión nueva: lo que ya corría (procesos, agentes
con nombre) termina con la suya, y `Run`, `Call`, `Spawn` y `SpawnAgent` usan la nueva; las globales de tipo
simple con el mismo nombre y tipo pasan con su valor.

```pascal
var V2 := V1.WithNode('Tarifa',
  'function Tarifa(Kg: Integer): Integer; begin Result := Kg * 1200 + 500; end;');
Writeln(V1.Version, ' -> ', V2.Version);       // 1 -> 2
Ctx.Upgrade(V2);
for var H in V2.History do                     // v1: envios / v2: Tarifa reemplazada
  Writeln(Format('v%d: %s', [H.Version, H.Change]));
```

- El código nuevo define solo ese nodo y conserva su firma (parámetros y resultado; en un agente, los
  métodos que tenía: puede agregar otros). Si no compila, no define el nodo o cambia la firma: `EPaiCompileError`
  (el de la firma lo dice: "cambia la firma") y no hay versión nueva.
- `Version` y `History` viven en memoria: el `.paic` no los guarda. Un programa cargado de un `.paic` no
  tiene fuente y no admite `WithNode`; tampoco uno cuyo motor ya se liberó.
- Los nodos de un flow (`'Pedido.Reserva'`) llegan después.
