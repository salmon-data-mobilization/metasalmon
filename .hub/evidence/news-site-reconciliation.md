# NEWS and favicon source reconciliation

Observed 2026-10-01 from main `3364b975`, using pkgdown 2.2.0 and pinned
Pandoc 3.8.3. This is a generated-page reconciliation and recovery of existing
favicon authoring inputs, with no runtime, version or ontology-term choice.

The existing favicon output was committed under `docs/`, while `.gitignore`
excluded all `pkgdown/` authoring inputs. pkgdown 2.2.0's `has_favicons()`
checks `pkgdown/favicon`; a partial build therefore omitted the icon links.
The seven recovered inputs are byte-identical to the corresponding committed
outputs. The local-scratch ignore remains, with the favicon input directory
tracked. Its exception retires if pkgdown no longer requires that location.
`.Rbuildignore` already excludes `pkgdown/` from package artifacts.

The existing NEWS-only helper from PR215 was copied to a temporary script
under this checkout's `scripts/` for each build and removed afterward. Its
normal toolchain/publication checks ran. No additional build script is added.
The original NEWS source is unchanged; HTML, Markdown and search now render
its existing development entries. One old `read_csv()` auto-link becomes plain
code text in the standalone render; its wording is unchanged. NEWS references
for the two current packet APIs use the reference pages supplied by PR245.

## Observed checks

- Initial NEWS-only build: 15.54s; three generated paths, 563 additions and
  14 removals before restoring the favicon source location.
- Build with recovered favicon sources: 13.63s. Existing icon links survive
  through pkgdown's normal template. Seven source/output byte pairs match.
- Repeat build: 13.31s; NEWS HTML, Markdown and search hashes are identical.
- Replay of B-58's actual seven-line NEWS source patch: 14.45s, only two added
  and one removed HTML lines, eight added Markdown lines, and one replaced
  development Added search record. No historical-fragment curation is needed.
  The probe's source/output bytes were restored exactly after measurement.
- Final search comparison preserves all non-NEWS records, including repeated
  records; `git diff --check` passes. No site asset or package-code churn.

The replay tests one concrete recurring cost with the same real NEWS addition.
It is not a new independent claim or a measured whole-task/time-saving share.
Current source/site drift is removed from this proposed baseline; older draft
branches still need normal integration when it lands. The central overhead
log in PR215 owns ongoing measurement.

## Recovered asset hashes

| Asset | SHA-256 of both source and existing output |
| --- | --- |
| `apple-touch-icon.png` | `29480130b173a722ed0cf63faa1c4878444476fc7748f382e95268cdfb08144f` |
| `favicon-96x96.png` | `912fb79195b6f883fc3d01d10d3a3e2961dc448a381081304519e120546c237f` |
| `favicon.ico` | `68c29fc545632efb336ce19f823fe35e9d6d820c51168ec4c2531f323d2f5297` |
| `favicon.svg` | `6e9b2cd3bd2ff4b3fcb45ce4e0862bcc996558034ae9788b92144f3dca91b3d6` |
| `site.webmanifest` | `c509d8b258fda2b18acd8926b0016f33fbb82fce83fcd236abf923a4f54db225` |
| `web-app-manifest-192x192.png` | `401ae7aaf5217203e054b1349a727a58c2079cda2674beae1098c7e85b4ce652` |
| `web-app-manifest-512x512.png` | `aeaf5d760979cfbc4e13413a0ae1d027ad5a1c9a1962a3b616ecf5501b561ce6` |
