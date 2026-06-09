#!/usr/bin/env bash
#
# build.sh
#
# Compile attractor.f90 to attractor.wasm via LFortran, then inline the
# resulting binary as base64 into template.html, producing attractor.html
# as a single-file Field Instrument.
#
# Requirements:
#   lfortran  (https://lfortran.org)
#   wasm-ld   (ships with LLVM/clang)
#   base64
#
# Output:
#   attractor.wasm    (intermediate)
#   attractor.html    (final single-file artifact)

set -euo pipefail

SRC=attractor.f90
OBJ=attractor.o
WASM=attractor.wasm
TEMPLATE=template.html
OUT=attractor.html

echo "[1/3] compiling Fortran to wasm32 object"
lfortran -c "${SRC}" --target wasm32 -o "${OBJ}"

echo "[2/3] linking wasm with exports"
wasm-ld --no-entry --import-memory --allow-undefined "${OBJ}" -o "${WASM}" \
  --export=get_buffer_address \
  --export=get_buffer_capacity \
  --export=set_params \
  --export=reset_state \
  --export=integrate

echo "[3/3] inlining wasm into template -> ${OUT}"
WASM_B64=$(base64 -w0 "${WASM}")
# Use a small awk to substitute the placeholder, since the base64 string
# is long enough to make sed unhappy on some platforms.
awk -v b64="${WASM_B64}" '{
  gsub(/\{\{WASM_BASE64\}\}/, b64)
  print
}' "${TEMPLATE}" > "${OUT}"

echo "done. open ${OUT} in a browser."
