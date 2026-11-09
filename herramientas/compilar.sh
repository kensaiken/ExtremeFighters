#!/usr/bin/env bash
# Compila todo lo que lleva el instalador, desde Linux, para Windows x64.
# Necesita: Rust (rustup), el destino x86_64-pc-windows-gnu y MinGW-w64:
#   rustup target add x86_64-pc-windows-gnu
#   sudo apt install gcc-mingw-w64-x86-64 git
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/ExtremeFighters_Instalador"
WORK="$REPO/build"
mkdir -p "$OUT/bin" "$OUT/assets" "$WORK"

# 1) 3dsrecomp, la version exacta que usa Zakuro v0.2.32
[ -d "$WORK/3dsrecomp" ] || git clone https://github.com/fearkov/3dsrecomp "$WORK/3dsrecomp"
git -C "$WORK/3dsrecomp" checkout df82e6e3c1231606c38e0f2786dd07f6067979ab
(cd "$WORK/3dsrecomp" && cargo build --release --locked --target x86_64-pc-windows-gnu)
x86_64-w64-mingw32-strip -o "$OUT/bin/3dsrecomp.exe" "$WORK/3dsrecomp/target/x86_64-pc-windows-gnu/release/3dsrecomp.exe"

# 2) Zakuro v0.2.32 + parche de la edicion DBZ
[ -d "$WORK/zakuro" ] || git clone https://github.com/fearkov/zakuro "$WORK/zakuro"
git -C "$WORK/zakuro" checkout -f v0.2.32
git -C "$WORK/zakuro" clean -fdq
git -C "$WORK/zakuro" apply "$REPO/zakuro-dbz/zakuro-dbz.patch"
(cd "$WORK/zakuro" && cargo build --release --locked -p zakuro --target x86_64-pc-windows-gnu)
x86_64-w64-mingw32-strip -o "$OUT/bin/zakuro.exe" "$WORK/zakuro/target/x86_64-pc-windows-gnu/release/zakuro.exe"
cp "$REPO/zakuro-dbz/LICENSE-zakuro.txt" "$OUT/bin/"

# 2b) Servidor de salas online (Windows y Linux)
SRV="$REPO/ExtremeFighters_Servidor"
mkdir -p "$SRV"
(cd "$WORK/zakuro" && cargo build --release -p ef-servidor --target x86_64-pc-windows-gnu && cargo build --release -p ef-servidor)
x86_64-w64-mingw32-strip -o "$SRV/ef-servidor.exe" "$WORK/zakuro/target/x86_64-pc-windows-gnu/release/ef-servidor.exe"
strip -o "$SRV/ef-servidor-linux" "$WORK/zakuro/target/release/ef-servidor"
cp "$REPO/servidor/"* "$SRV/" && cp "$REPO/zakuro-dbz/LICENSE-zakuro.txt" "$SRV/"
(cd "$REPO" && rm -f ExtremeFighters_Servidor.zip && zip -qr9 ExtremeFighters_Servidor.zip ExtremeFighters_Servidor)

# 3) Lanzadores con icono (Instalar.exe y Jugar.exe)
L="$REPO/instalador/lanzadores"
(cd "$L" && cp ../assets/bola.ico . && x86_64-w64-mingw32-windres res.rc -O coff -o "$WORK/res.o")
x86_64-w64-mingw32-gcc -O2 -s -municode -mwindows "$L/launch.c" "$WORK/res.o" -o "$OUT/Instalar.exe"
x86_64-w64-mingw32-gcc -O2 -s -municode -mwindows -DPLAY "$L/launch.c" "$WORK/res.o" -o "$OUT/bin/Jugar.exe"
rm -f "$L/bola.ico"

# 4) Script del instalador, imagenes y LEEME
cp "$REPO/instalador/instalador.ps1" "$OUT/"
cp "$REPO/instalador/actualizar.ps1" "$OUT/bin/"
cp "$REPO/instalador/assets/"* "$OUT/assets/"
cp "$REPO/LEEME.txt" "$OUT/"
(cd "$REPO" && rm -f ExtremeFighters_Instalador.zip && zip -qr9 ExtremeFighters_Instalador.zip ExtremeFighters_Instalador)
echo "Listo: $REPO/ExtremeFighters_Instalador.zip"
