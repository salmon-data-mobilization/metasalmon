---
type: InformationObject
title: "Open questions for Brett"
description: "The single durable log of decisions only Brett can make: what each question is, what it unblocks, the recommendation on the table, and its status. Agents append here whenever work surfaces a decision; Brett's answers move a status line, and the ruling is then recorded in the owning card."
status: draft
tags: [questions, decisions, coordination]
psc:
  id: metasalmon:questions
  contexts: [metasalmon:context:hub-coordination]
---

# Open questions for Brett

**How this file works.** One entry per decision that genuinely needs Brett —
not tasks, not defects, not anything an agent could settle from evidence.
Agents append new questions at the bottom of the OPEN section whenever work
surfaces one, with what it unblocks and a recommendation. When Brett answers
(in chat, a PR comment, or an issue), the answering agent moves the entry to
ANSWERED with the ruling, its date, and where it was recorded — the ruling
itself lives in the owning card or execplan; this file is the index, not the
authority. An entry is never deleted: an answered question that later reopens
gets a new entry pointing at the old one.

Detail for most entries lives in the recon record
([backlog](backlog.md), the sequence cards, and the
[S10 execplan](plans/2026-08-15-s10-metasalmonpy-parity-replay.md)); each
entry links its owner.

## Open

### Q3 — Backlog #90: may a descriptor `schema.fields` entry carry I-ADOPT keys?
**Unblocks:** the gold standard passing the spec validator; S1's premise.
The evidence is one-sided and the item now says so: nothing normative names
`validate_package.py`, the published v0.3 profile permits the keys, Frictionless
allows custom field properties, and no CI anywhere runs the script.
**Recommendation:** permit the keys — make `descriptor_field_from_column()`
learn them, deriving the allowlist from `column_dictionary.schema.json`.
**Owner:** [backlog #90](backlog.md). *Also sequenced behind this ruling:*
backlog #109 (`spec_version` enforcement in smn-data-pkg touches the same
validator).

### Q4 — Which artifact is THE gold standard, and where is its finish line?
**Unblocks:** S12, the workshop's teaching artifact, what metasalmonpy mirrors.
30-row `nuseds-fraser-coho-sample.csv` (already drifted into fabrication in
smn-data-pkg's copy) vs the 173-row `nuseds-fraser-coho-2023-2024.csv` (has a
reproducible derivation script and licensed upstream).
**Recommendation:** promote the 173-row slice; demote the 30-row file to a
named speed fixture; finish line = strict local validation AND spec-validator
clean (stage 1), then a deposit under S3's exit criteria (stage 2).
**Owner:** [S12](sequences/s12-fraser-coho-gold-standard.md).

### Q5 — De-prioritise gcdfo in full, or carve out what the gold standard needs?
**Unblocks:** how semantically complete the gold standard can be.
Two of its four unmapped code columns are metasalmon wiring defects being fixed
now with released gcdfo terms (no gcdfo work needed). The genuine gcdfo needs
are PFMA subareas and whatever Q8 decides.
**Recommendation:** narrow carve-out for exactly those; psc-salmon-vocabularies
stays fully de-prioritised. **Owner:** roadmap sequencing constraints.

### Q6 — smn PR #27: the modelling rulings (now eight questions)
**Unblocks:** 22 smn terms, gcdfo holds #68/#70 (not #74's species half, and
NOT Fraser Recruits, which needs none of it).
The build/determinism half is proceeding as non-blocked work. The eight open
modelling questions live in the S9 decision table — including the new eighth:
sockeye river-type peerhood, which the commons records as `contested`
(Beacham & Withler treat river-type as a special case of sea-type) while the
PR mints flat peers.
**Recommendation:** rule the eight as one pass; add the peerhood scope note
(one triple now vs a migration later).
**Owner:** [S9 step 7](sequences/s9-ontology-alignment.md).

### Q7 — What version number may the finished metasalmonpy port carry?
**Unblocks:** S10's terminal bump only — the chunks proceed regardless.
The chunks must carry metasalmon's post-0.3.0 fixes (~107 commits past the
tag), so a bare "0.3.0" names a tree no metasalmon release contains; and
whether the parity claim requires closing #87 and #91 first is equally open.
**Recommendation:** cut a metasalmon release containing the post-0.3.0 fixes
first, then metasalmonpy claims that number — it makes both version claims
literally true. **Owner:** [S10 execplan](plans/2026-08-15-s10-metasalmonpy-parity-replay.md),
open decisions 1 and 2.
*New evidence (2026-08-22, chunk A):* the port's first subsystem chunk
(metasalmonpy PR #14, merged unversioned) was verified against metasalmon
**`main` at the moment of measurement** — `e02111a`, including PR #75 — not
against any release, and the execplan now records that as the operative
convention while this stays open. Every chunk verified this way widens the
set of delivered behaviour that no existing release number can truthfully
claim, which strengthens the recommendation above: the sooner the metasalmon
release exists, the less behaviour the final bump has to qualify away.
*Second data point (2026-08-22, chunk B):* chunk B had to **re-baseline
mid-stream** when metasalmon `main` moved under it (`39818ce` → `9d8f125`,
docs plus PR #77) — the same moving-target cost chunk A paid when `main`
moved during its fixture cut. Two chunks, two re-baselines: while no release
exists, each in-flight chunk pays a re-measurement cost against a target that
keeps moving, on top of the widening-claim cost above.

*Third data point, and it refines the second (2026-08-22, chunks D, E and F):*
all three measured against `main` at the moment of measurement — D at `9d8f125`,
E and F at `794647a` — so five of the six landed chunks now sit on option (b)'s
shape and none on any release. But E and F's move was a **re-pin, not a
re-baseline**: they confirmed the R tree was *identical* to `9d8f125` in `R/`,
`tests/` and `inst/` before re-pinning, so the move was documentation only. That
narrows the second data point's cost claim rather than confirming it — the
recurring per-chunk cost while no release exists is **checking whether the
target moved in a way that matters**, which is cheaper than re-measuring but is
paid by every chunk, and it is only cheap because someone checked. The widening
claim above is untouched: three more chunks of delivered behaviour that no
existing release number can truthfully name. Still open — recorded, not
resolved.

### Q8 — Where do PFMA subareas and a species reference get minted?
**Unblocks:** two of the four gap columns in the coho example's codes.csv.
**Recommendation:** split — species points at an external taxonomy (smn has
deliberately withdrawn its scheme); PFMA subareas go to gcdfo, which owns the
Area scheme, because splitting one regulatory vocabulary across repos for a
temporary priority ordering fractures it permanently. **Owner:**
[S12](sequences/s12-fraser-coho-gold-standard.md); intersects Q5.

### Q9 — For a spawner count, is `property_iri` `smn:Abundance` or `gcdfo:SpawnerAbundance`?
**Unblocks:** the gold standard's single annotated column, which currently
teaches two contradictory answers (shipped dictionary vs seeder output).
**Recommendation:** `smn:Abundance` as property, `gcdfo:SpawnerAbundance` as
term/variable — the decomposition the example README already argues for. If so,
the R seeder is wrong (it writes the same IRI into both slots) and gets fixed
with a test. Record as an ecosystem I-ADOPT ruling, not a metasalmon fix.
**Owner:** [S12](sequences/s12-fraser-coho-gold-standard.md).

### Q10 — Which membership test governs the hub, and is the workshop the eighth member?
**Unblocks:** every future membership question; makes S4's subject visible to
the authority sequencing it.
The bundle states the test two incompatible ways (roadmap: "output is an input
to this pipeline"; domain card: "the hub sequences that repository's work"),
and they give opposite answers for psc-data-transformations. The allowlist says
seven-is-exhaustive while the roadmap sequences an eighth repo as S4.
**Recommendation:** the domain card's test (it predicts what is actually in the
roadmap); workshop becomes the eighth member; psc-data-transformations stays a
typed external edge with its substance in S13. **Owner:** roadmap +
[domain card](domains/salmon-data-ecosystem.md), recorded as OD-1 in both.

### Q11 — Do `metadata/semantic/**` files belong in the SDP specification?
**Unblocks:** what metasalmonpy mirrors; stops metasalmon accreting spec
authority by default.
**Recommendation:** adopt them into smn-data-pkg — the status quo quietly makes
metasalmon the de facto spec, which is the failure the hub exists to prevent.
**Owner:** [backlog](backlog.md) smn-data-pkg items.

### Q12 — Backlog #93's remaining half: where does type coercion belong on the write path?
**Unblocks:** items 3–5 of #93 (SSSOM canonical bytes rendering one column two
ways; datapackage.json vs dataset.csv disagreement; the `original` fallback).
Items 1–2 are fixed/unblocked.
**Recommendation:** adopt the Python design (coerce at render, per-type,
measured); rule on parity "Ahead" row 13 in the same pass — it is the only one
where current R behaviour can silently destroy a user's file.
**Owner:** [backlog #93](backlog.md).

### Q13 — The stuck production KNB deposit: send the support request?
**Unblocks:** the ecosystem's only open publication incident, and the Fraser
recipe's migration off metasalmon 0.1.8 (migrating first risks two live heads
on a production series).
Seven-plus authenticated lookups over sixteen days is not transient. **Only you
can send an outbound support request.** After the series resolves and a receipt
is written, the recipe migrates — assign that an owner and a date then, or
"after" becomes "never". **Owner:** [S13](sequences/s13-fraser-recruits-case-study.md).

## Notes on framing

Q3's backlog item was reframed during the 2026-08-21 recon from "two defensible
readings" to "the evidence favours permitting the keys". The reframing is
evidence-backed (each claim was independently verified) and the item still says
the call is Brett's — but the frame moved, and you should know that before
reading it.

## Answered

### Q1 — What does "the KNB test environment" actually mean? — ANSWERED 2026-08-22 (Brett)

**Ruling:** there is a test/dev environment for the KNB API, and the golden
path is to develop data packages against it first; once they look good there,
post to the production KNB endpoint
(`https://knb.ecoinformatics.org/knb/d1/mn/v2`) — "as long as it works out to
use the test/dev endpoint."

**Verified the same day, read-only:** the test environment exists and answers.
`https://dev.nceas.ucsb.edu/knb/d1/mn/v2/node` returns 200 with identity
**`urn:node:mnTestKNB` / "KNB Test Node"** (demo.nceas serves the same
identity), and `urn:node:mnTestKNB` is registered in the DataONE staging CN
(`cn-stage.test.dataone.org`). Production confirmed as `urn:node:KNB`. So the
S3 execplan's node id was right and its endpoint is now sourced. **Remaining
workability question, which is Brett's:** obtaining a dev.nceas login/token and
one end-to-end test deposit. Ruling recorded in the
[S3 card](sequences/s3-knb-staging.md); S3 implementation is unblocked.

**Note on the psc-data-transformations contradiction:** its claim was that
*production* KNB exposes no server-side draft — the test node is a separate
environment, which is exactly what S3 proposed, so both statements can be true;
the private-review model remains the production-side fallback if the test path
"does not work out."

### Q2 — Workshop scope — ANSWERED 2026-08-22 (Brett)

**Ruling:** currency pass first (landed 2026-08-21, workshop PR #4), then the
golden-path/rebuild work **after the KNB test environment's API workability is
determined**. With Q1's environment verified live, workability now means: a
token plus one successful end-to-end test deposit. The
[S4 card](sequences/s4-workshop-rebuild.md) carries the ruling.
