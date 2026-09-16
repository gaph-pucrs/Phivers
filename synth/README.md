# Synthesis - single Phivers PE

Genus flow for one processing element (`PhiversPE`) on TSMC 28 HPC+
(`tcbn28hpcplusbwp30p140`). Block level: standard cells only, no IO pads -
a PE is a tile of the NoC, its interfaces stay on die.

## Quick start

```sh
module load ddi/231       # or: module load wimed
cd synth
make synth                # full flow, ~2.0 ns target
```

Results land in `reports/<run>/` and `outputs/<run>/`, where `<run>` defaults to
`PhiversPE_scalar_2p0ns`, so several configurations and target periods live side
by side.

## Vector unit

`PhiversPE` instantiates RS5 with `VEnable = 0`: the baseline PE is scalar.
`VECTOR=1` turns the vector unit on and `VLEN` sets the vector register width:

```sh
make synth                       # scalar     -> run PhiversPE_scalar_2p0ns
make synth VECTOR=1              # VLEN=128   -> run PhiversPE_v128_2p0ns
make synth VECTOR=1 VLEN=256     # VLEN=256   -> run PhiversPE_v256_2p0ns
```

`VLEN` has to be a multiple of 32 and at least 32: the unit slices every
register into 8, 16 or 32 bit elements (`VLENB = VLEN/8`, and `VLENB/4` is used
as a replication count), so a narrower register does not elaborate. `setup.tcl`
rejects an illegal value before Genus is even started.

Genus appends the overridden parameters to the design name
(`PhiversPE_VEnable1_VLEN128`); the flow renames it back to `PhiversPE`, so
every netlist is named the same whatever the configuration - the run directory
is what tells the configurations apart.

```sh
make synth PERIOD=1.5     # different target, different run directory
make synth VECTOR=1       # PE with the RS5 vector unit, VLEN=128
make elab                 # stop after elaboration - the fast RTL check
make generic              # stop after generic synthesis
make shell                # interactive Genus, setup already sourced
make export               # re-write the Innovus hand-off from a finished .db
make help                 # every knob
```

## Layout

```
synth/
├── Makefile              entry point, knobs
├── scripts/
│   ├── setup.tcl         paths, configuration, technology - start here
│   ├── views.mmmc        library sets, corners, analysis views
│   ├── constraints.sdc   clock, IO budget, design rules
│   ├── rtl.f             RTL file list
│   ├── reports.tcl       reporting helpers
│   └── synth.tcl         the flow itself
├── work/<run>/           scratch: logs, command files, snapshot of scripts/
├── reports/<run>/        elaborate/ generic/ map/ opt/ final/
└── outputs/<run>/        netlist, SDC, SDF, .db, Innovus hand-off
```

Nothing is hardcoded to an absolute path: the Makefile passes `SYNTH_DIR` in the
environment and `scripts/setup.tcl` derives the repository root from it.

`make synth` copies `scripts/` into `work/<run>/scripts/` and runs Genus on that
copy. Genus reads its command file incrementally, so editing a script while a
run is in flight makes it resume at the wrong offset and re-execute earlier
steps - the snapshot makes that impossible, and it also records exactly which
scripts produced a given set of results.

`scripts/rtl.f` contains file paths and nothing else. Genus has no comment
syntax in a `-f` file: every whitespace separated token is treated as a file
name, so a `#` line is read as a list of files. It warns about each word, and if
a word happens to match a real path it will read it as Verilog. `-incdir` is not
honoured there either, and is not needed - every `` `include `` in this RTL
resolves relative to the file that contains it.

## Configuration

Every knob is an environment variable read by `scripts/setup.tcl`, so it can be
overridden on the command line: `make synth EFFORT=medium CPUS=16`.

| knob | default | meaning |
|------|---------|---------|
| `PERIOD` | `2.0` | clock period in ns (2.0 ns = 500 MHz) |
| `VECTOR` | `0` | `1` enables the RS5 vector unit |
| `VLEN` | `128` | vector register width in bits, multiple of 32 |
| `RUN` | `PhiversPE_<config>_<period>ns` | name of the run directory |
| `EFFORT` | `high` | `syn_global_effort` |
| `POWER_EFFORT` | `high` | `design_power_effort` |
| `CPUS` | `8` | parallel CPUs |
| `CLOCK_GATING` | `true` | insert integrated clock gates |
| `ERROR_ON_LATCH` | `true` | stop when a latch is inferred |
| `RETIME` | `false` | register retiming |
| `PHYSICAL` | `true` | read the LEF and use PLE wire estimates |
| `LEC` | `false` | also write the Conformal dofile |
| `STOP_AFTER` | `all` | `elaborate` \| `generic` \| `map` \| `opt` \| `all` |
| `PDK_ROOT` | TSMC 28 install | technology root |

## Constraints

`scripts/constraints.sdc` models the environment of a block, not of a chip:

- `clk_i` at `PERIOD`, 5% setup uncertainty, 0.3 ns estimated post-CTS latency,
  0.1 ns transition - the clock tree does not exist yet at synthesis.
- `rst_ni` is a false path: it is an asynchronous reset whose release is
  synchronised at system level. Recovery/removal is checked after CTS.
- Every other input/output gets 40% of the period as external delay, is driven
  by a `BUFFD4BWP30P140` and loaded with 20 fF. This is a placeholder budget:
  tighten it once the neighbouring tiles are placed.
- `set_max_fanout 20`, `set_max_transition 0.30`.

## Corners

Three views, all from `scripts/views.mmmc`:

| view | library | RC | used for |
|------|---------|----|----------|
| `av_slow` | ssg 0.81 V 125 C | rcworst | setup |
| `av_typ` | tt 0.90 V 25 C | typical | power |
| `av_fast` | ffg 0.99 V -40 C | rcbest | hold |

The PDK only ships hold AOCV derates for the fast corner, which is the only
thing that corner is used for here.

## Outputs

`outputs/<run>/` contains what place and route needs:

- `PhiversPE_netlist.v` - mapped netlist
- `PhiversPE.sdc` - constraints propagated through synthesis
- `PhiversPE.sdf` - delays for gate level simulation
- `PhiversPE.db` - Genus database, to reopen the run
- `innovus/` - `write_design -innovus` hand-off
- `conformal/` - only with `LEC=true`

`reports/<run>/final/` has area, gates, clock gating, sequential mapping, power
and setup timing per view; the intermediate `generic/`, `map/` and `opt/`
directories keep the QoR after each step so regressions are easy to place.

Hold is deliberately not reported here: the clock is ideal until CTS, so hold
numbers out of Genus mean nothing. Hold closes in Innovus.

## Relation to `tsmc_28/`

`tsmc_28/` is the earlier experiment this flow grew out of. It is left as it is;
this directory replaces it for the PE. The differences: no hardcoded
`/sim/zantonio` paths, no `suspend` in the middle of the script, no IO pads at
block level, corrected SDC (the clock was constrained under the wrong name and
part of the port list was malformed), a complete file list, and reports and deliverables written per run instead of into a
shared directory.
