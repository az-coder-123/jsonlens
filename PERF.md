# Performance Report & How-to (JSONLens)

This document summarizes recent performance work, micro-benchmarks, and recommended steps to measure and improve UI rendering as well as JSON parsing/formatting.

## What I implemented
- Isolate-based parsing & formatting utilities (`JsonFormatter.formatAsync`, `minifyAsync`, `formatObjectAsync`, `JsonValidator.validateAsync`).
- Debounced input (300ms) to avoid frequent isolate spawns while typing.
- Lazy JSON tree widget (`LazyJsonTree`) that only builds children on expand and supports `defaultExpandedDepth`.

## Benchmarks (macOS run, sample file ~3.9 MB)
- JSON parse & pretty-print micro-bench (`tool/benchmarks/json_bench.dart`): measured decode/encode times for multiple sizes.
- Isolate vs main-thread integration (`tool/benchmarks/integration_bench.dart`): `formatAsync` (isolate parse+format) was faster than main-thread parse+format for the large payload (110 ms vs 170 ms).
- Stress loop (`tool/benchmarks/stress_loop.dart`): repeated `formatAsync` 50 iterations — average ~117 ms, max ~198 ms (per iteration, isolate parse+format).
- Tree traversal node count/time (`tool/benchmarks/tree_build_bench.dart`): counts nodes built for depth-limited expansions.
  - depth=1 -> nodes: 10,001, time: 0 ms
  - depth=2 -> nodes: 50,001, time: 2 ms
  - depth=3 -> nodes: 70,001, time: 3 ms
  - depth=4 -> nodes: 90,001, time: 4 ms
  - depth=5 -> nodes: 110,001, time: 7 ms
  - full -> nodes: 160,001, time: 9 ms

> Observation: limiting expansion depth dramatically reduces the number of built nodes and traversal time.

## How to profile UI interactively (recommended)
1. Run the app in profile mode: `flutter run --profile -d <device-id>`.
2. Open DevTools (the link appears in the console) and go to the Performance / Timeline view.
3. Start recording, perform the following actions in the app:
   - Paste `tool/benchmarks/large.json` into the input area.
   - Switch to Tree view and expand the root node, expand several child nodes, and scroll quickly.
4. Stop recording and inspect the frame chart for dropped frames (>16ms), and the CPU sampling for hottest functions.
5. Also use the Memory view to capture heap snapshots before/after repeated expansions to check for leaks.

## Recommendations
- Keep parsing/formatting in isolates for large payloads (use `formatAsync` / `validateAsync`). Use quick `isPotentiallyValid` heuristics to avoid isolates for small/obvious cases.
- Default to shallow expansion (e.g., `defaultExpandedDepth: 1`) and let users expand deeper nodes on demand.
- Implement virtualization in the tree if users need to expand large subtrees (more advanced; can implement deferred child lists with `ListView.builder`).
- Capture DevTools traces during interactive sessions to find rendering hotspots and GC behavior.

## Next steps (pick from these)
- Implement virtualization for large expanded subtrees (complex but reduces rendering cost for very large trees).
- Add automated performance smoke tests that run benchmarks on demand (local script already present) and record results.
- Run a live interactive DevTools profiling session and produce a short report with screenshots and frame statistics.

---

If you want, I can implement virtualization for expanded subtrees next, or run an interactive DevTools session and capture traces and a short report. Reply which you'd prefer.