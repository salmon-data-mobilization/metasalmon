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

## Additive main integration (2026-10-01)

Merged `origin/main` at `d0339c0` after the B-59 configuration documentation
landed. Regenerated NEWS HTML, Markdown and search from the merged, unchanged
`NEWS.md` with pkgdown 2.2.0 and Pandoc 3.8.3. Search retains all 551
non-NEWS records from that main commit in the same order, including duplicate
records; the NEWS portion grows from 69 to 70 records and includes B-59's
entry. All seven favicon source/output byte pairs still match. The generated
NEWS page has two reference links whose pages are supplied by PR245; PR247
still depends on that PR landing before it is ready to merge.

## Native integration after PR250 (2026-10-01)

Merged `origin/main` at `e3fa5df` additively. The only conflict was generated
`docs/search.json`; the NEWS HTML and Markdown merged cleanly. Ran the native
`scripts/build-pkgdown.R --news-only` once with pkgdown 2.2.0 and pinned
Pandoc 3.8.3. `NEWS.md` remains byte-identical to incoming main. The rebuilt
search index has 658 records: 70 NEWS and 588 non-NEWS. All 588 incoming
non-NEWS records are byte-equivalent as parsed records and retain their order,
including duplicates. The NEWS pages include the B-60, PR215 and PR250
entries. The packet API links resolve to reference pages now present on main
after PR245, and all seven favicon input/output pairs still match byte for
byte. The focused reference-index check passes (68 exports, 64 topics), and
`git diff --check` passes. Fresh CI is required on this merge head.

Generated SHA-256 values: `docs/news/index.html`
`a0225b2e4594595215df3655a6de5084f1766c95c0476251b807a09d02f8daa2`,
`docs/news/index.md`
`b4fd0ea5535585ce183ee5bd5f7e9ad8b66a0de5284b1bd3463dace293956283`,
and `docs/search.json`
`e7a818734e510e714262eae5da393e6946551e500c3c05335b1a67677b837347`.

## Manifest URL correction after review (2026-10-01)

The recovered manifest initially matched the previously published output, but
its two icon `src` values began with `/`. From the configured project URL
`https://salmon-data-mobilization.github.io/metasalmon/`, that resolves to
the domain root rather than the committed icon files under `/metasalmon/`.
Both `src` values are now relative in the authoring and published manifests.
`urljoin()` checks resolve each to the project path and find both corresponding
files in `docs/`; the old leading-slash values resolve to the domain root.
The two manifest copies remain byte-identical. No icon image bytes changed.

## Recovered asset hashes

| Asset | SHA-256 of both source and existing output |
| --- | --- |
| `apple-touch-icon.png` | `29480130b173a722ed0cf63faa1c4878444476fc7748f382e95268cdfb08144f` |
| `favicon-96x96.png` | `912fb79195b6f883fc3d01d10d3a3e2961dc448a381081304519e120546c237f` |
| `favicon.ico` | `68c29fc545632efb336ce19f823fe35e9d6d820c51168ec4c2531f323d2f5297` |
| `favicon.svg` | `6e9b2cd3bd2ff4b3fcb45ce4e0862bcc996558034ae9788b92144f3dca91b3d6` |
| `site.webmanifest` | `1cf0234a4c176518c20293be1beacc9b98565112ead667c5cb5f9eeb8be68275` |
| `web-app-manifest-192x192.png` | `401ae7aaf5217203e054b1349a727a58c2079cda2674beae1098c7e85b4ce652` |
| `web-app-manifest-512x512.png` | `aeaf5d760979cfbc4e13413a0ae1d027ad5a1c9a1962a3b616ecf5501b561ce6` |
