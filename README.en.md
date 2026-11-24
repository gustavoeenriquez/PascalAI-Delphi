# PascalAI for Delphi

[Español](README.md) · **English**

The [PascalAI](https://github.com/gustavoeenriquez/PascalAI-Learn) engine inside your Delphi application: a
`TPaiEngine` component on the palette that compiles and runs PascalAI programs (business rules users change
without recompiling, AI agents and flows, code written by a model and run in a sandbox).

```pascal
uses PascalAI.Engine;

var Ctx := Motor.Compile(
  'function Descuento(Cantidad: Integer): Double;' + sLineBreak +
  'begin if Cantidad >= 10 then Result := 0.10 else Result := 0; end;').NewContext;
ShowMessage(FloatToStr(Ctx.Call('Descuento', [12]).AsFloat));   // 0.1
```

This repository holds the **compiled packages** (in [Releases](https://github.com/gustavoeenriquez/PascalAI-Delphi/releases)),
the examples and the documentation. The engine source is not public. Examples, comments and the API reference
are in Spanish; the identifiers are in English, like Delphi's.

## Requirements

- **Delphi 13** (RAD Studio 13, compiler 37.0). Delphi DCUs only work with the version that built them.
- Two downloads, by Delphi edition: `...-delphi13-community.zip` (Community and Professional; SQLite from
  scripts) and `...-delphi13-enterprise.zip` (Enterprise and Architect; SQLite, PostgreSQL and MySQL/MariaDB).
  The difference is FireDAC's PostgreSQL and MySQL drivers, which only Enterprise includes.
- Windows: **32- and 64-bit** applications (VCL, FMX or console).
- To use AI models from scripts, the provider key in an environment variable (`ANTHROPIC_API_KEY`,
  `OPENAI_API_KEY`...), or a local Ollama. Never in the code.

## Install

1. Download the zip for your edition from [Releases](https://github.com/gustavoeenriquez/PascalAI-Delphi/releases)
   and unzip it, for example to `C:\PascalAI-Delphi`. Optionally compare its SHA-256 with `SHA256SUMS.txt`.
2. **Unit path.** In *Tools > Options > Language > Delphi > Library*, for each platform add its `dcu` folder to
   *Library path*: `C:\PascalAI-Delphi\Win32\dcu` (Windows 32-bit) and `C:\PascalAI-Delphi\Win64\dcu` (Windows 64-bit).
3. **The IDE must find `PascalAI.bpl`.** In *Tools > Options > IDE > Environment Variables*, add to `PATH`
   (*Add Override*) the folder for your IDE: `C:\PascalAI-Delphi\Win32` for the 32-bit IDE,
   `C:\PascalAI-Delphi\Win64` for the 64-bit IDE. Restart the IDE.
4. *Component > Install Packages > Add...* and pick `PascalAIDesign.bpl` from that same folder.
   The **PascalAI** palette page shows `TPaiEngine` and `TPaiScript`.

Your application is **statically linked**: no BPL has to ship with it, unless you build with runtime packages.

## Examples

| Folder | What it shows |
|---|---|
| [`ejemplos/01-consola`](ejemplos/01-consola/Consola.dpr) | The API basics: compile, read variables, call script functions, give the script a function and an object of the application, the sandbox and an AI model (`mock`, no network) |
| [`ejemplos/02-reglas-vcl`](ejemplos/02-reglas-vcl) | A form with `TPaiEngine` from the palette: the discount rules are a script the user edits and tries without recompiling; script errors are shown, they don't break the application |
| [`ejemplos/03-asistente`](ejemplos/03-asistente) | An AI assistant configured with `pai.package` (`Engine.LoadPackageConfig`): provider, model and database come from the file; the model queries orders with a script tool. Ships with `mock`; uncomment Ollama or Claude to use a real one |
| [`ejemplos/04-skills-auto`](ejemplos/04-skills-auto) | Skills and automatic tools: one model writes following a project skill (`[skills]`); another, with `tools auto`, searches the PascalAI registry for a calculator, asks the person for permission (`PaiHumanHandler`), installs it in the project folder and uses it. Ships with `mock`; needs internet. When run, `tools auto` adds the package to `pai.package` and creates `pai.lock` and `pai_packages/` |
| [`ejemplos/05-procesos`](ejemplos/05-procesos/Procesos.dpr) | Agents and processes with the application: the application as an agent (`RegisterHostAgent`, used by the script with `Process<T>`), a live script agent started and called from Delphi (`SpawnAgent`, `Call`), and a process with parallel children and its events (`Spawn`) |

## API essentials

| To | Use |
|---|---|
| Compile | `Engine.Compile(Source)` (raises `EPaiCompileError`) or `Engine.TryCompile(Source, Name, Prog, Diag)` (doesn't raise; free `Diag`) |
| Run | `Ctx := Prog.NewContext; Ctx.Run;` and what `WriteLn` printed in `Ctx.OutputText` |
| Pass and read data | `Engine.DeclareGlobal('Customer', 'string')` and `Ctx.Globals['Customer']`; `Ctx.Call('Function', [Args])` |
| Give the script functions | `Engine.RegisterFunction('function PriceOf(const P: string): Double;', procedure(const C: TPaiCall) ...)` |
| Give the script objects | `Engine.RegisterClass(TCustomer, ['Name', 'Pay'])` and `TPaiValue.FromObject(Obj, soBorrowed)` |
| Limit | `Engine.Profile := spPure` (no disk or network), `Engine.Limits.MaxTimeMs`, `MaxMemoryBytes`... |
| Untrusted code | `Engine.SandboxRun(Code)`: never raises; `Ok`, `Output`, `ErrorMessage`, `Json` |
| `pai.package` settings | `Engine.LoadPackageConfig(Folder)`: `[providers]`, `[models]`, `[databases]`, `[mcp]`, `[stores]`... as with `pai run`. Process-wide: all engines share them |
| Skills and `tools auto` | `[skills]` and `[auto]` in `pai.package` (`[auto]` keys in English or Spanish: `allow`/`permitir`, `deny`/`negar`, `authors`/`autores`, `approve = install, run`/`aprobar = instalar, ejecutar`): `LoadPackageConfig` sets the project folder; skills are read from it and `tools auto` installs there (`pai_packages/`, `pai.lock`). The application answers approval questions with `PaiHumanHandler` (unit `PascalAI.AI.Human`). An MCP server written in PascalAI needs `pai.exe` next to the executable, or `TPaiEngine.PaiExe` |
| Databases | `Engine.AddDatabase('sales', 'sqlite; path=sales.db')` or the `Databases` property in the Object Inspector (`BaseDir` for relative paths), and `Database('sales')` in the script |
| Provider keys | Environment variables (`key=$ANTHROPIC_API_KEY` in `[providers]`) or `Secret('NAME')`, which also looks in the Windows Credential Manager (`pai secret set`) |
| Agents and processes | `Ctx.Spawn`, `Ctx.Process('name')`, channels and events from the script to the application |

Full reference (Spanish): [docs/api-host.md](docs/api-host.md).

## License

The packages are free for educational and personal use. Any other use (for example, a commercial application)
requires the author's permission. See [LICENCIA.txt](LICENCIA.txt). The examples in this repository are MIT:
copy them into your programs.
