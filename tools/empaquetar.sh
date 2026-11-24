#!/usr/bin/env bash
# Arma el zip de una versión con los paquetes ya compilados (packages/build.sh del motor).
# Uso (Git Bash):  [PAI_PKG_DIR=packages-local] tools/empaquetar.sh <carpeta del motor> <versión> [sufijo]
#   PAI_PKG_DIR: la carpeta de bin/ con los paquetes (packages = completa; packages-local = con PAI_SQL_LOCAL)
#   deja dist/PascalAI-Delphi-<versión>-delphi13[-sufijo].zip y agrega su línea a dist/SHA256SUMS.txt
set -euo pipefail
SRC="$1"; VER="$2"; SUF="${3:+-$3}"; PKG="${PAI_PKG_DIR:-packages}"
R="$(cd "$(dirname "$0")/.." && pwd)"
NOMBRE="PascalAI-Delphi-$VER-delphi13$SUF"
T="$R/dist/$NOMBRE"
rm -rf "$T"; mkdir -p "$T"
for PLAT in win32 win64; do
  D="$T/${PLAT^}"
  mkdir -p "$D/dcu"
  cp "$SRC/bin/$PKG/$PLAT"/PascalAI.bpl "$SRC/bin/$PKG/$PLAT"/PascalAI.dcp \
     "$SRC/bin/$PKG/$PLAT"/PascalAIDesign.bpl "$SRC/bin/$PKG/$PLAT"/PascalAIDesign.dcp "$D/"
  cp "$SRC/bin/$PKG/$PLAT"/dcu/*.dcu "$D/dcu/"
done
cp "$R/LICENCIA.txt" "$T/"
cp "$R/tools/LEEME.txt" "$T/"
( cd "$R/dist" && rm -f "$NOMBRE.zip" && python -c "import shutil, sys; shutil.make_archive(sys.argv[1], 'zip', '.', sys.argv[1])" "$NOMBRE" )
( cd "$R/dist" && touch SHA256SUMS.txt && grep -v " $NOMBRE.zip\$" SHA256SUMS.txt > s.tmp || true; \
  sha256sum "$NOMBRE.zip" >> s.tmp; mv s.tmp SHA256SUMS.txt; cat SHA256SUMS.txt )
