# ForTRANart · Field Instrument 017

A single-file browser Field Instrument that integrates one of four strange
attractors in Fortran and traces its trajectory as a pen-plotter drawing on
graph paper. Numerical work runs as WebAssembly compiled from Fortran via
LFortran; rendering is plain Canvas 2D.

Models: Lorenz-63, Aizawa, Thomas, Halvorsen. Switching models reseeds the
trajectory and reloads the canonical parameter set; everything is editable
from the panel.

## Files

```
attractor.f90    Fortran source. attractor_state module holds the
                 buffer + parameters; attractor_core module holds the
                 RK4 integrator and the C-bound entry points.
test_driver.f90  Native test harness. Runs each model for 400 RK4 steps
                 and checks the trajectory is finite and bounded.
test_wasm.mjs    Node.js test harness. Loads attractor.wasm, exercises
                 the WASM ABI, and runs the same per-model sanity checks.
build.sh         Compile to wasm32 (LFortran), link (wasm-ld), inline as
                 base64 into template.html, write attractor.html.
verify.sh        End-to-end verification: Phase 1 native test (gfortran),
                 Phase 2 wasm ABI test (lfortran + node), Phase 3 bundle.
template.html    Single-file UI with the {{WASM_BASE64}} placeholder
                 and a JS fallback integrator.
attractor.html   Final single-file artifact (produced by build.sh or
                 verify.sh phase 3).
README.md        This file.
```

## Building

Easiest path: install the toolchain, then run `verify.sh`. It walks all
three phases (native test, wasm test, single-file bundle) and skips
gracefully if any tool is missing.

Requirements:

- `gfortran` for the native test (apt: `gfortran`)
- `lfortran` for the wasm build (conda-forge: `conda install -c conda-forge lfortran`)
- `wasm-ld` for linking (apt: `lld`)
- `node` for the wasm ABI test (apt: `nodejs`)
- `base64`, `awk`, `bash`

```
chmod +x verify.sh
./verify.sh
```

If you only want to bundle (skipping verification), run `./build.sh`.

Open the resulting `attractor.html` in any modern browser. No server required.

## JS fallback

`template.html` is itself a working artifact even before any wasm is built. When
the `{{WASM_BASE64}}` placeholder is still in place, the page silently falls
back to a JavaScript integrator that mirrors the Fortran exactly (same
parameters, same RK4 step, same buffer cadence). This lets you iterate on the
aesthetic and the controls without waiting on the toolchain. The status footer
shows which engine is live: `engine: js` or `engine: fortran/wasm`.

## Fortran/WASM contract

The Fortran side exposes these C-bound entry points (all live in
`attractor_core` as module procedures, since the Fortran standard
forbids `BIND(C, NAME="...")` on procedures contained inside a program):

```
get_buffer_address  -> c_ptr   linear-memory pointer to the output buffer
get_buffer_capacity -> i32     number of doubles in the buffer
set_model(m)                   pick 0..3 (Lorenz, Aizawa, Thomas, Halvorsen)
set_param(idx, val)            set pars(idx+1); JS knows the per-model map
set_dt(h)                      integration step
reset_state(x0, y0, z0)        seed the trajectory
integrate(n_steps)             advance and fill the buffer
```

The JS side allocates a `WebAssembly.Memory`, hands it in as `env.memory`,
reads the buffer pointer once at boot, and constructs a `Float64Array` view
into linear memory. Each frame it calls `integrate(N)` and reads the first
`3*N` doubles from the view.

Model dispatch happens inside `deriv` (a private helper in `attractor_core`)
via a `select case` on `model_id`. Parameters live in a generic `pars(8)`
array; the JS-side `MODELS` registry in `template.html` is the source of
truth for how each model maps its named parameters into that array.

## Verification

The build pipeline ships with two layers of verification:

`test_driver.f90` compiles natively against `attractor_core` via `gfortran`
and exercises each of the four models for 400 RK4 steps. It checks every
point is finite (no NaN, no Inf) and that the trajectory stays within
model-specific bounds (Lorenz inside roughly [-40, 40] x [-40, 40] x [0, 60],
Aizawa inside [-5, 5]^3, Thomas inside [-12, 12]^3, Halvorsen inside
[-15, 15]^3). This verifies the algebra and the RK4 integration without
needing LFortran.

`test_wasm.mjs` does the same checks against a built `attractor.wasm`,
exercising the WASM ABI the same way the browser does: instantiate with
imported memory, fetch the buffer pointer and capacity, build a
`Float64Array` view, drive each model through `set_model` /  `set_param` /
`set_dt` /  `reset_state` /  `integrate`. If LFortran is on PATH,
`verify.sh` runs this automatically after building the wasm.

Reference trajectory endpoints (from the gfortran-verified native run,
400 steps each):

```
lorenz     end=(  -7.7706,  -6.9477,  27.2279)
aizawa     end=(   0.1816,   1.3157,   1.3187)
thomas     end=(   0.7124,   0.7522,   0.4728)
halvorsen  end=(   5.6323,  -9.8266,  -9.2591)
```

The wasm build should reproduce these to roughly machine precision over
the first hundred steps; after that, chaos amplifies floating-point
differences and exact agreement is no longer expected.

## Design

The aesthetic is a Calcomp-style pen plotter drawing on engineering graph
paper. The trace is fountain-pen indigo on a warm paper ground, with a
hairline sage grid at 20px and a heavier rule at 100px. Pen weight varies
with instantaneous velocity, so the slow regions of each attractor (the
wings of Lorenz, the lobes of Aizawa, the slow turns of Thomas, the curling
chambers of Halvorsen) lay down a heavier line than the fast crossings. Each
model carries its own velocity reference so the pen-weight calibration stays
consistent across the four shapes.

A corner stamp records the engine, the active model, its parameters, and a
run timestamp, the way a real plotter would print a header on the sheet.

Type is IBM Plex Sans and IBM Plex Mono. No serif display face, no
broadsheet-by-default layout, no terracotta accent. The single oxblood accent
is reserved for active state: the engaged model, the focused field, and the
run indicator.

## Notes on LFortran

LFortran's wasm target is in alpha and may not support every Fortran construct
in `attractor.f90`. If a build fails, the JS fallback keeps the artifact
viewable while the Fortran is adjusted. Likely sticking points are
`c_loc(buffer)` on a module-scope array, returning `type(c_ptr)` from a
`bind(c)` function, and `c_double` array indexing. These are all in current
LFortran roadmap territory.

The gfortran phase will catch any pure-Fortran issues. The wasm phase will
catch any LFortran-specific codegen issues. Together they isolate which
layer needs the fix.

## License

This project is licensed under GPL-3.0.
