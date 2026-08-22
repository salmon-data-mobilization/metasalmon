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

### Q1 — What does "the KNB test environment" actually mean?
**Unblocks:** S3 entirely, and through it S4's golden-path section — the top
priority. **The largest single unblock on this list.**
The S3 execplan specifies `urn:node:mnTestKNB` / `dataone_test_token` with no
cited source, and nobody has checked whether that node is live or whether a
token is obtainable. psc-data-transformations asserts the contradicting model:
KNB exposes no server-side draft, and a restricted persistent *production*
version IS the staging state (`deposit_kind: production`).
**Recommendation:** check the DataONE node registry for `urn:node:mnTestKNB`
first — that single fact decides whether S3 as written is buildable. Regardless
of the answer, write the workshop's golden path against production
private-review now (the only path executable against released code, and the one
the ecosystem has actually run once), without letting that quietly kill S3 —
twenty learners minting persistent production objects is the failure S3 exists
to prevent. **Owner:** [S3](sequences/s3-knb-staging.md). *New evidence (2026-08-21):* the
workshop's own session-6 KNB text already describes the production
private-review model — so of the two contradictory answers, the one the
teaching material encodes is psc-data-transformations', not the S3 execplan's.

### Q2 — Workshop scope: currency pass now, or the nine-episode rebuild?
**Unblocks:** S4's shape and schedule.
The workshop teaches `method_iri` (removed at 0.3.0) as current, and four
session-6 chunks render R errors into the published site. A currency pass is
proceeding as non-blocked work (the lockfile fix and factually-wrong content);
the rebuild and the golden-path section wait on this and Q1.
**The one input agents cannot supply: is a workshop delivery date booked?**
If yes, currency-then-golden-path is the only survivable scope; if no, the
rebuild becomes defensible. **Owner:** [S4](sequences/s4-workshop-rebuild.md).

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
keeps moving, on top of the widening-claim cost above. Still open — recorded,
not resolved.

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

*(none yet — answers move here with their date and where the ruling was
recorded)*
