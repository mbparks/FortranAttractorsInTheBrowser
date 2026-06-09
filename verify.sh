#!/usr/bin/env bash
#
# verify.sh
#
# End-to-end verification of ForTRANart's Fortran core and wasm build.
#
# Phase 1 (always runs): compile attractor.f90 + test_driver.f90 with
# gfortran, run the native test driver. This confirms the Fortran is
# valid and the four-model RK4 integrator produces sane trajectories.
#
# Phase 2 (runs only if lfortran is on PATH): cross-compile attractor.f90
# to wasm32 via LFortran, link with wasm-ld, then exercise the WASM ABI
# from Node.js via test_wasm.mjs.
#
# Phase 3 (runs only if Phase 2 produced a wasm): bundle the wasm into
# template.html via build.sh, producing attractor.html.

set -euo pipefail

cd "$(dirname "$0")"

echo "=================================================="
echo "Phase 1: native verification via gfortran"
echo "=================================================="

if ! command -v gfortran >/dev/null 2>&1; then
  echo "gfortran not found. Install it (e.g. apt-get install gfortran) and re-run."
  exit 2
fi

rm -f attractor_state.mod attractor_core.mod test_driver attractor_native.o test_driver.o
gfortran -Wall -Wno-unused-dummy-argument attractor.f90 test_driver.f90 -o test_driver
echo "build: ok"
echo ""
./test_driver
echo ""

echo "=================================================="
echo "Phase 2: wasm verification via lfortran (optional)"
echo "=================================================="

if ! command -v lfortran >/dev/null 2>&1; then
  echo "lfortran not found. Skipping wasm phase."
  echo "Install via conda-forge: conda install -c conda-forge lfortran"
  echo "or follow https://lfortran.org/download/"
  exit 0
fi

if ! command -v wasm-ld >/dev/null 2>&1; then
  echo "wasm-ld not found. Install lld (apt-get install lld) and re-run."
  exit 2
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node not found. Install Node.js to run the wasm ABI test."
  exit 2
fi

echo "lfortran:" "$(lfortran --version 2>&1 | head -1)"
echo "wasm-ld: " "$(wasm-ld --version 2>&1 | head -1)"
echo ""

rm -f attractor.o attractor.wasm
lfortran -c attractor.f90 --target wasm32 -o attractor.o
wasm-ld --no-entry --import-memory --allow-undefined attractor.o -o attractor.wasm \
  --export=get_buffer_address \
  --export=get_buffer_capacity \
  --export=set_model \
  --export=set_param \
  --export=set_dt \
  --export=reset_state \
  --export=integrate
echo "wasm build: ok ($(stat -c %s attractor.wasm 2>/dev/null || stat -f %z attractor.wasm) bytes)"
echo ""

node test_wasm.mjs ./attractor.wasm
echo ""

echo "=================================================="
echo "Phase 3: bundle wasm into attractor.html"
echo "=================================================="

WASM_B64=$(base64 -w0 attractor.wasm 2>/dev/null || base64 attractor.wasm | tr -d '\n')
awk -v b64="${WASM_B64}" '{
  gsub(/\{\{WASM_BASE64\}\}/, b64)
  print
}' template.html > attractor.html
echo "wrote attractor.html ($(stat -c %s attractor.html 2>/dev/null || stat -f %z attractor.html) bytes)"
echo ""
echo "all phases passed. open attractor.html in a browser."
