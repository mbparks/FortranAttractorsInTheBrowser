# PLOTTER · LORENZ-63

A single-file browser Field Instrument that integrates the Lorenz-63 strange
attractor in Fortran and traces its trajectory as a pen-plotter drawing on
graph paper. Numerical work runs as WebAssembly compiled from Fortran via
LFortran; rendering is plain Canvas 2D.

## Files

```
attractor.f90    Fortran source. RK4 integrator + C-bound exports.
build.sh         Compile to wasm32 (LFortran), link (wasm-ld),
                 inline as base64 into template.html, write attractor.html.
template.html    Single-file UI with the {{WASM_BASE64}} placeholder
                 and a JS fallback integrator.
attractor.html   Final single-file artifact (produced by build.sh).
README.md        This file.
```

## Building

Requirements: `lfortran`, `wasm-ld` (ships with LLVM), `base64`, `awk`.

```
chmod +x build.sh
./build.sh
```

Open the resulting `attractor.html` in any modern browser. No server required.

## JS fallback

`template.html` is itself a working artifact even before any wasm is built. When
the `{{WASM_BASE64}}` placeholder is still in place, the page silently falls
back to a JavaScript integrator that mirrors the Fortran exactly (same
parameters, same RK4 step, same buffer cadence). This lets you iterate on the
aesthetic and the controls without waiting on the toolchain. The status footer
shows which engine is live: `engine: js` or `engine: fortran/wasm`.

## Fortran/WASM contract

The Fortran side exposes these C-bound entry points:

```
get_buffer_address  -> c_ptr   linear-memory pointer to the output buffer
get_buffer_capacity -> i32     number of doubles in the buffer
set_params(sigma, rho, beta, dt)   update Lorenz parameters
reset_state(x0, y0, z0)            seed the trajectory
integrate(n_steps)                 advance and fill the buffer
```

The JS side allocates a `WebAssembly.Memory`, hands it in as `env.memory`,
reads the buffer pointer once at boot, and constructs a `Float64Array` view
into linear memory. Each frame it calls `integrate(N)` and reads the first
`3*N` doubles from the view.

## Design

The aesthetic is a Calcomp-style pen plotter drawing on engineering graph
paper. The trace is fountain-pen indigo on a warm paper ground, with a
hairline sage grid at 20px and a heavier rule at 100px. Pen weight varies with
instantaneous velocity, so the slow loops at the wings of the attractor lay
down a heavier line than the fast crossings through the center. A corner stamp
records the engine, parameters, and timestamp of the run, the way a real
plotter would print a header on the sheet.

Type is IBM Plex Sans and IBM Plex Mono. No serif display face, no
broadsheet-by-default layout, no terracotta accent. The single oxblood accent
is reserved for active focus and the run indicator.

## Notes

LFortran's wasm target is in alpha and may not support every Fortran construct
in `attractor.f90`. If a build fails, the JS fallback keeps the artifact
viewable while the Fortran is adjusted. Likely sticking points are
`c_loc(buffer)` on a module-scope array, returning `type(c_ptr)` from a
bind(c) function, and `c_double` array indexing. These are all in current
LFortran roadmap territory.

## License

This project is licensed under GPL-3.0.
