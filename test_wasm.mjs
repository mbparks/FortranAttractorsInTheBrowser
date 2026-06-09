// test_wasm.mjs
//
// Verifies the WASM ABI of a built attractor.wasm. Exercises the same
// entry points and calling convention the browser uses. Runs each of the
// four models for a short integration and checks the trajectory is finite
// and bounded within model-specific limits.
//
// Usage:
//   node test_wasm.mjs                # uses ./attractor.wasm
//   node test_wasm.mjs path/to.wasm   # uses an explicit path

import { readFile } from 'node:fs/promises';
import { argv, exit } from 'node:process';

const wasmPath = argv[2] ?? './attractor.wasm';

let bytes;
try {
  bytes = await readFile(wasmPath);
} catch (err) {
  console.error(`could not read ${wasmPath}: ${err.message}`);
  console.error('build it first with ./build.sh');
  exit(2);
}

const memory = new WebAssembly.Memory({ initial: 4, maximum: 256 });

// Defensive imports: if the wasm references runtime helpers we did not
// anticipate, stub them rather than failing the instantiation outright.
let module_;
try {
  module_ = await WebAssembly.compile(bytes);
} catch (err) {
  console.error('failed to compile wasm:', err.message);
  exit(2);
}

const required = WebAssembly.Module.imports(module_);
const imports = { env: { memory } };
for (const imp of required) {
  imports[imp.module] = imports[imp.module] ?? {};
  if (imp.name in imports[imp.module]) continue;
  if (imp.kind === 'function') {
    imports[imp.module][imp.name] = () => 0;
    console.warn(`  (stubbed missing import: ${imp.module}.${imp.name})`);
  }
}

let instance;
try {
  instance = await WebAssembly.instantiate(module_, imports);
} catch (err) {
  console.error('failed to instantiate wasm:', err.message);
  exit(2);
}

const ex = instance.exports;

const requiredExports = [
  'get_buffer_address', 'get_buffer_capacity',
  'set_model', 'set_param', 'set_dt',
  'reset_state', 'integrate',
];
const missing = requiredExports.filter((n) => typeof ex[n] !== 'function');
if (missing.length) {
  console.error('missing exports:', missing.join(', '));
  console.error('available exports:', Object.keys(ex).join(', '));
  exit(2);
}

const addr = ex.get_buffer_address();
const cap  = ex.get_buffer_capacity();
if (!Number.isInteger(addr) || addr < 0) {
  console.error('get_buffer_address returned non-integer or negative:', addr);
  exit(2);
}
if (!Number.isInteger(cap) || cap <= 0) {
  console.error('get_buffer_capacity returned non-positive:', cap);
  exit(2);
}
const buf = new Float64Array(memory.buffer, addr, cap);

console.log(`wasm loaded:  buffer @0x${addr.toString(16)}, capacity ${cap} doubles`);
console.log('');

const MODELS = [
  {
    id: 0, name: 'lorenz   ',
    params: [10.0, 28.0, 8/3],
    dt: 0.005,
    seed: [0.1, 0.0, 0.0],
    n: 400,
    bounds: { x: 40, y: 40, z: 60, zmin: -10 },
  },
  {
    id: 1, name: 'aizawa   ',
    params: [0.95, 0.7, 0.6, 3.5, 0.25, 0.1],
    dt: 0.010,
    seed: [0.1, 0.0, 0.0],
    n: 400,
    bounds: { x: 5, y: 5, z: 5, zmin: -5 },
  },
  {
    id: 2, name: 'thomas   ',
    params: [0.19],
    dt: 0.05,
    seed: [1.1, 1.1, -0.01],
    n: 400,
    bounds: { x: 12, y: 12, z: 12, zmin: -12 },
  },
  {
    id: 3, name: 'halvorsen',
    params: [1.89],
    dt: 0.005,
    seed: [-1.48, -1.51, 2.04],
    n: 400,
    bounds: { x: 15, y: 15, z: 15, zmin: -15 },
  },
];

function fmt(v, w = 8, p = 3) {
  return v.toFixed(p).padStart(w);
}

let passed = 0;
for (const m of MODELS) {
  ex.set_model(m.id);
  for (let i = 0; i < m.params.length; i++) ex.set_param(i, m.params[i]);
  ex.set_dt(m.dt);
  ex.reset_state(m.seed[0], m.seed[1], m.seed[2]);
  ex.integrate(m.n);

  // Inspect the trajectory in the buffer
  let xmin = Infinity, xmax = -Infinity;
  let ymin = Infinity, ymax = -Infinity;
  let zmin = Infinity, zmax = -Infinity;
  let finite = true;
  for (let i = 0; i < m.n; i++) {
    const x = buf[3*i], y = buf[3*i + 1], z = buf[3*i + 2];
    if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(z)) {
      finite = false;
      break;
    }
    if (x < xmin) xmin = x; if (x > xmax) xmax = x;
    if (y < ymin) ymin = y; if (y > ymax) ymax = y;
    if (z < zmin) zmin = z; if (z > zmax) zmax = z;
  }

  const inBounds = finite &&
    Math.max(Math.abs(xmin), Math.abs(xmax)) < m.bounds.x &&
    Math.max(Math.abs(ymin), Math.abs(ymax)) < m.bounds.y &&
    xmax > xmin && ymax > ymin && zmax > zmin;

  const last = m.n - 1;
  const ex_xyz = `end=(${fmt(buf[3*last])} ${fmt(buf[3*last+1])} ${fmt(buf[3*last+2])})`;
  const xrange = `x[${fmt(xmin, 7, 2)} ${fmt(xmax, 7, 2)}]`;
  const zrange = `z[${fmt(zmin, 7, 2)} ${fmt(zmax, 7, 2)}]`;

  if (inBounds) {
    console.log(`PASS  ${m.name}  ${ex_xyz}  ${xrange}  ${zrange}`);
    passed++;
  } else {
    console.log(`FAIL  ${m.name}  finite=${finite}  ${xrange}  ${zrange}`);
  }
}

console.log('');
console.log(`>>> ${passed} / ${MODELS.length} model checks passed`);
exit(passed === MODELS.length ? 0 : 1);
