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
*Expansion requested and delivered (2026-08-24).* Brett: *"You'll have to
expand on Q6 for me to be able to answer. What are your precise questions and
recommendations and trade offs?"* An expanded briefing was provided the same
day. The **eight** decisions — each with its precise question, its trade-off,
and what cannot be deferred to an implementer — are stated in the
[S9 card](sequences/s9-ontology-alignment.md)'s decision section: six of them in
the decision table (rows **1–5 and 8**) and questions **6** and **7** in the
prose immediately beneath it, which are open but change nothing that gets
minted. **Still open.** A briefing is not a ruling, and this entry does not move
until the eight are ruled.

### Q9 — For a spawner count, is `property_iri` `smn:Abundance` or `gcdfo:SpawnerAbundance`?
**Unblocks:** the gold standard's single annotated column, which currently
teaches two contradictory answers (shipped dictionary vs seeder output).
**Recommendation:** `smn:Abundance` as property, `gcdfo:SpawnerAbundance` as
term/variable — the decomposition the example README already argues for. If so,
the R seeder is wrong (it writes the same IRI into both slots) and gets fixed
with a test. Record as an ecosystem I-ADOPT ruling, not a metasalmon fix.
**Owner:** [S12](sequences/s12-fraser-coho-gold-standard.md).

### Q13 — The stuck production KNB deposit: send the support request?
**Unblocks:** the ecosystem's only open publication incident, and the Fraser
recipe's migration off metasalmon 0.1.8 (migrating first risks two live heads
on a production series).
Seven-plus authenticated lookups over sixteen days is not transient. **Only you
can send an outbound support request.** After the series resolves and a receipt
is written, the recipe migrates — assign that an owner and a date then, or
"after" becomes "never". **Owner:** [S13](sequences/s13-fraser-recruits-case-study.md).

### Q17 — Should `create_sdp()` refuse a doomed write *before* running inference?
**Unblocks:** parity row 59, and a test on both sides that nothing currently pins.
Found while implementing your Q15 ruling: metasalmon re-tests the write
directory early, so a call that will be refused never reaches
`infer_salmon_datapackage_artifacts()`; metasalmonpy has no early guard and
runs the whole inference first, refusing at write time. **Measured, not read**
— a doomed `create_sdp()` runs inference 0 times in R and 1 time in Python.
**The outcome is identical either way**, which is why no assertion about the
result has ever seen it; what differs is the wasted work, and with
`llm_assess = TRUE` that work is billable. **It turns on whether a duplicated
check is worth what it saves:** the early guard is a second copy of a rule, and
a second copy drifts — it *did* drift, for the whole life of row 54, and had to
be moved by hand when the authoritative one moved. Against that, the mirror's
single-check shape can spend a full retrieval pass, or real money, producing
output it is about to refuse.
**Recommendation:** none offered; both grounds are real and the choice is yours.
**Owner:** [parity row 60](parity-deviations.md).

### Q18 — `REVIEW: ` or `REVIEW:` — does the marker's exact spelling matter?
**Unblocks:** parity row 60, and any future byte differential over
`column_dictionary.csv`.
metasalmon writes `REVIEW: https://…` (trailing space), metasalmonpy writes
`REVIEW:https://…`. Every detector on both sides matches the prefix `REVIEW:`
with no space, so each recognises the other and strict validation refuses both
— **the difference is inert to behaviour and visible only in bytes.** Found by
the Q16 differential, and it is invisible to every test either side has: both
suites build the expected string from their own prefix, so both stay green
forever whichever spelling they use. Not folded into the Q16 ruling because you
were asked about which slots a prefill may fill, not about the marker's
bytes, and changing it would move the four already-marked roles' output too.
**It turns on whether "the same package written twice" should mean the same
bytes.** If yes, one side gives way (cheapest: metasalmonpy grows a prefix
helper). If the marker is a display convention, the row stands as a caution and
nothing changes.
**Recommendation:** if you rule at all, rule the *no-space* spelling in, since
it is what both sides' detectors already encode and what the two `AGENTS.md`
files name; but the honest answer may be that this is not worth a change.
**Owner:** [parity row 61](parity-deviations.md).

## Notes on framing

Q3's backlog item was reframed during the 2026-08-21 recon from "two defensible
readings" to "the evidence favours permitting the keys". The reframing is
evidence-backed (each claim was independently verified) and the item still says
the call is Brett's — but the frame moved, and you should know that before
reading it. **Q3 was then answered on 2026-08-24 in the direction the reframed
evidence pointed.** This note stays where it is rather than moving to the
answered entry: it records that the frame moved *before* the ruling, which is
exactly the thing a reader of the ruling alone cannot see.

## Answered

### Q12 — When R turns a `Date` into text, which renderer wins? — ANSWERED 2026-08-24 (Brett)

**Ruling:** *"Fix them as per the metasalmonpy implementation by fixing all
three by coercing them once at render time per type."* So: fix, not accept —
and the design is the mirror's, which renders each cell **once**, choosing the
renderer by the value's type.

**Implemented 2026-08-25** (branch `fix/2026-08-25-q12-date-render`) and
recorded in [backlog #93](backlog.md), which is now **fully retired**. Two of
the three were code fixes routed through one new `.ms_canonical_character()`
(`R/platform-time.R`): item 3, where `.ms_sssom_canonical_bytes()` sorted by
`as.character()` and emitted through `format()`; and item 5, where
`.ms_canonical_value_tokens()`'s `original` fallback keyed a `Date` unpadded.
**Item 4 was a trace rather than a fix**: its stated mechanism is unreachable —
item 2's coercion covers every frame that reaches the descriptor — and two
corrections to its premise came out of the trace, both measured. jsonlite
serializes a `Date` through `format.Date`, so on glibc it emits `999-01-01`
too and item 4 was a **macOS-only** split even historically; and the same
*shape* is alive for `POSIXct`, in both implementations, filed as **#115**
because it needs its own ruling on which spelling a descriptor instant takes.
That last finding also corrects a sentence in the quoted question below: it
says metasalmonpy has no such divergence because `date.isoformat()`, `str()`
and `pandas.to_csv` all pad. Measured 2026-08-25 on pandas 3.0.5, the claim
holds for a `date` column and for an `object`-dtype `datetime` column, and
**fails for the dtype pandas actually chooses**: a column built from
`datetime.datetime` objects becomes `datetime64[us]`, and `to_csv` renders
`datetime(999, 6, 5, 13, 45, 30)` from it as `999-06-05 13:45:30` — unpadded —
while `str()` of the same value gives `0999-06-05 13:45:30`. That is a
year-padding split inside the mirror's own writer, of exactly the class its
`test_platform_determinism_guard.py` exists to catch. It belongs to **#115**.

**The part of the ruling that did the work is "per type."** The obvious
symmetry — treat `Date` and `POSIXct` alike — would have corrupted a path that
was never broken, exactly as item 1 found in 2026-08-21. The two live one
`git grep` apart and take opposite decisions about `POSIXct` because they sit
on different baselines, and a regression test pins that the new one did not
leak into the old one.

*(The question as it stood when it was answered follows, unedited, because the
rewrite of 2026-08-24 is itself part of the record.)*

> **Rewritten 2026-08-24, because the previous wording assumed context that was
> never stated.** Brett: *"I don't really understand what happened and what your
> asking for. Is that just for the KNB deposit making it to DataONE CN?"* No —
> and that is the first thing to fix. **This has nothing to do with KNB or
> DataONE.** No deposit, no member node, no coordinating node. It is about how
> **R converts a `Date` value into the characters written into a file**, and the
> fact that this package uses more than one converter for the same value.
>
> R has two renderers and they disagree for years before 1000:
> `format(as.Date("0999-01-01"))` gives `0999-01-01`, while
> `as.character(as.Date("0999-01-01"))` gives `999-01-01` (since R 4.3 it takes an
> internal fast path that never reaches `format()`). Different code paths in this
> package reach for different ones.
>
> **The three concrete symptoms, all in [backlog #93](backlog.md):**
>
> - **Item 4 — one call, two spellings of the same date.** A single
>   `write_salmon_datapackage()` can write `0999-01-01` into `datapackage.json`
>   (`jsonlite::write_json()` pads) and `999-01-01` into `metadata/dataset.csv`
>   (`readr::write_csv()` does not), in the same package.
> - **Item 3 — sorted by one rendering, emitted as another.**
>   `.ms_sssom_canonical_bytes()` takes its sort key through `as.character()`
>   (never padded) and its emitted bytes through `format()` (padded on macOS, not
>   on Linux). Row *order* and row *content* can therefore disagree about the same
>   value, and `mapping_date` / `publication_date` / `review_date` are declared
>   SSSOM columns.
> - **Item 5 — the fallback keys unpadded.** `.ms_canonical_value_tokens()` still
>   takes `trimws(as.character(x))` for its `original` fallback, so a `Date`
>   column declared `value_type = "string"` keys unpadded while the `date` branch
>   beside it keys padded.
>
> **Nothing is broken in practice, and saying so is part of the question.** Every
> case needs a **pre-1000 date**, and no salmon dataset has one. What is actually
> at stake is the package's **byte-reproducibility contract** — same inputs, same
> bytes, on every platform — which is the property that makes a canonical hash, an
> archive checksum and a DataONE PID mean anything. Items 1 and 2 of #93 are
> already fixed; these three are the remainder.
>
> **Recommendation:** adopt the Python design — **coerce at render, per type, and
> measure each type before touching it.** metasalmonpy has no such divergence
> because `date.isoformat()`, `str()` and `pandas.to_csv` all pad. Item 1's fix is
> the model for *how*: `Date` and `POSIXct` needed different treatment (the two
> renderers agree exactly on a `Date` and on nothing for a `POSIXct` — separator,
> zone marker, and whether a fractional second survives), so a change applied to
> both "for symmetry" would have corrupted the path that was never broken.
>
> **The one decision that is actually yours:** is a defect that cannot bite real
> salmon data worth changing a contract this package advertises — **fix the three
> now**, or **record them as accepted permanently** and state the caveat wherever
> byte reproducibility is claimed? Which functions move, and in what order, is an
> implementer's call either way. *Also on the table in the same pass:* parity
> "Ahead" row 13, the only deviation where current R behaviour can silently
> destroy a user's file.
> **Owner:** [backlog #93](backlog.md) items 3–5.

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

### Q3 — Backlog #90: may a descriptor `schema.fields` entry carry I-ADOPT keys? — ANSWERED 2026-08-24 (Brett)

**Ruling:** *"Yes I accept your recommendation."*

**What was accepted, restated so nobody has to chase the earlier text:**
descriptor `schema.fields` entries **may** carry the I-ADOPT keys, and it is
`smn-data-pkg` that moves, not the two mirrors. `SPECIFICATION.md` says the keys
are permitted, and `descriptor_field_from_column()` in
`scripts/validate_package.py` learns them — deriving the allowlist of legal extra
keys from `column_dictionary.schema.json` rather than hard-coding one — so its
exact `!=` comparison stops rejecting every semantically annotated package.
Neither `write_salmon_datapackage()` nor metasalmonpy's projection stops
emitting the seven keys.

**The larger half of the change, named in #90 and unchanged by the ruling:**
relaxing an exact comparison means deciding *which* extra keys are legal, which
is a vocabulary question. Deriving the allowlist from the dictionary schema is
what keeps it from becoming a hand-maintained list.

**Two things this does not settle.** metasalmonpy's seventh key was `method_iri`
where R's is `statistical_modifier_iri`, because it still vendored sdp-0.2.0 when
#90 was written — a separate divergence, not a consequence of this ruling. S10
chunk A has since flipped that vendored bundle to sdp-0.3.0, so the key may
already agree; **re-measure the Python projection rather than assuming either
way**, and update #90's retirement condition with what you find. And backlog **#109** (`spec_version` enforcement)
was sequenced behind this ruling only because it touches the same script; it is
now free to proceed, and should land in the same pass, since both change
`validate_package.py`'s comparison behaviour.

**Recorded in:** [backlog #90](backlog.md), and the sequencing note in
[#109](backlog.md).

### Q4 — Which artifact is THE gold standard, and where is its finish line? — ANSWERED 2026-08-24 (Brett)

**Ruling:** *"Promote the 173 row one."*

So the gold standard is **`inst/extdata/nuseds-fraser-coho-2023-2024.csv`** —
the 173-row official 2023–2024 slice with a reproducible `data-raw/` derivation
and a licensed upstream. The 30-row `nuseds-fraser-coho-sample.csv` is demoted
to the named speed fixture it already claims to be ("the fastest built-in
demo"), which is ruling **(a)** in S12's table. The backwards-compatibility
promise in the example README is therefore not broken by this ruling — the
30-row file keeps its job.

**Finish line, now stated in the card rather than in a recommendation** —
two stages: **stage 1**, the package is clean through *both* validators (strict
`validate_salmon_datapackage()` **and** `scripts/validate_package.py`); **stage
2**, it is deposited under [S3](sequences/s3-knb-staging.md)'s exit criteria and
has a resolvable identifier the docs can cite. Stage 1 is gated on Q3 (now
ruled) and on backlog #95; stage 2 is gated on S3.

**Recorded in:** [S12](sequences/s12-fraser-coho-gold-standard.md) (the open
decision is now the ruling, with the finish line beneath it), the
[backlog](backlog.md) recon items measured against it, and
[parity-deviations](parity-deviations.md) row 46, whose *which artifact* half
this settles: the mirror obligation now attaches to the 173-row example. What
stays open in row 46 is narrower — whether the two repositories share one
derivation script or each keeps its own.

### Q5 — De-prioritise gcdfo in full, or carve out what the gold standard needs? — ANSWERED 2026-08-24 (Brett)

**Ruling:** *"Carve out what the gold standard needs."*

Read it as exactly that and no wider: gcdfo is **not** de-prioritised in full and
**not** re-opened in full. The subset the gold standard depends on is carved out
and proceeds; everything else in gcdfo stays de-prioritised, and
`psc-salmon-vocabularies` stays fully de-prioritised.

**The subset, as far as the cards know it today, is one item: PFMA subareas.**
The gold standard's `AREA` column holds `29F`, `29G`, `29J`, `29K` — Subareas,
which gcdfo PR #86 deliberately did not mint (it minted the 48 Areas and said so
in a `skos:scopeNote`). Q8 sends subareas to gcdfo, so that mint **is** the
carve-out. Nothing else in the example needs gcdfo work: `SPECIES` goes to an
external taxonomy under Q8, and the other two unmapped code columns were
metasalmon wiring defects already fixed in the development version
(backlog **#101** the `ESTIMATE_CLASSIFICATION` crosswalk, **#102** the
enumeration crosswalk `create_sdp()` did not use).

**What is genuinely a next step, with an owner.** The ruling fixes *what class*
of term is carved out; it does not fix the **mint scope** — the four Subareas the
example actually holds, or all 604 of SOR/2007-77 Schedule 2. That is the next
decision, and it is a vocabulary-completeness call rather than a priority one.
**Owner:** [S12](sequences/s12-fraser-coho-gold-standard.md) states the need and
holds the evidence; [S9 step 7](sequences/s9-ontology-alignment.md) routes the
request into gcdfo through `detect_semantic_term_gaps()` →
`render_ontology_term_request()` → `submit_term_request_issues()`; the carve-out
itself is recorded in the [roadmap](roadmap.md)'s active sequencing constraints.
Note **#97**: that detector is blind to a zero-candidate search, which is the
shape this gap has, so filing it today is manual work.

**Recorded in:** [roadmap](roadmap.md) (active sequencing constraints),
[S12](sequences/s12-fraser-coho-gold-standard.md), and the PFMA section of the
[S9 card](sequences/s9-ontology-alignment.md).

### Q7 — What version number may the finished metasalmonpy port carry? — ANSWERED 2026-08-24 (Brett)

**Ruling:** *"yes, cut a metasalmon release containing the post-0.3.0 fixes
first, then metasalmonpy claims that number — it makes both version claims
literally true."*

That is option **(c)** in the [S10 execplan](plans/2026-08-15-s10-metasalmonpy-parity-replay.md)'s
open decision 2. **The sequencing is now fixed:**

1. metasalmon cuts a release of the tree containing the post-0.3.0 fixes.
2. metasalmonpy's terminal bump claims **that same number**, as a parity claim on
   a metasalmon release that actually exists.

metasalmonpy therefore **skips 0.3.0** on the Python side. The version lockstep
the mirror contract describes is preserved, because both numbers name the same
released behaviour — which is the property the ruling's own words turn on.

**FULLY DISCHARGED 2026-08-24 — both steps executed, in the ruled order, on the
day of the ruling.** Step 1: metasalmon **0.4.0**, tagged `v0.4.0` (`4e2bbb6`)
and released by a separate agent concurrently with the pass that recorded this
answer. Step 2: metasalmonpy claimed **0.4.0**, tagged `v0.4.0` (`3b587e6`) with
its GitHub Release published, skipping 0.3.0. **Both version claims are now
literally true, which is the exact property the ruling's own words asked for**
— and the second one was earned rather than declared: all 25 entries of
metasalmon 0.4.0's `NEWS.md` were audited against the Python tree before the
number moved, the two genuinely absent (`knb_environment`, the
`statistical_modifier` `role_boost`) were ported for the release, five
differences were registered with retirement conditions, and both dependency legs
ran green. This entry was deliberately written to state the *rule* rather than a
forecast, and the rule produced a number within hours and a released mirror the
same day.

**Three copies of that number were in play** (the `AGENTS.md` mirror contract
says so, and had already been wrong about it once, for three days): the catch-up
window in **both** repositories' `AGENTS.md`, and the release index in
[roadmap](roadmap.md). **All three now read 0.4.0 with no window open** —
metasalmonpy's `AGENTS.md` moved with the bump, metasalmon's and the release
index in the change that recorded this discharge. The copies-must-agree rule is
what survives Q7; the number in it will move again.

**What the ruling did not settle, and what therefore outlives it:** Q7 answered
*which number*, never *what the number must contain*. Backlog **#87** / register
row 32 — the ranking-profile gap — is open, owned by no milestone, and **not**
claimed by 0.4.0; the release entry names it rather than letting the number
imply otherwise. Backlog **#113** (one shared ownership sentinel — **Q14** below) and register
row 53 likewise outlived the stream.

**Recorded in:** the [S10 execplan](plans/2026-08-15-s10-metasalmonpy-parity-replay.md)
open decision 2 (now decided), the [S10 card](sequences/s10-metasalmonpy-parity.md),
and the metasalmonpy row of the [roadmap](roadmap.md)'s release index.

### Q8 — Where do PFMA subareas and a species reference get minted? — ANSWERED 2026-08-24 (Brett)

**Ruling:** *"I agree with your recommendation PFMA Sub areas go to gcdfo."*

The recommendation was a **split**, and both halves are accepted:

- **PFMA subareas → `gcdfo`.** It already owns
  `gcdfo:PacificFisheryManagementAreaScheme` and Schedule 2's 48 Areas, and
  splitting one regulatory vocabulary across repositories to suit a temporary
  priority ordering fractures it permanently.
- **Species → an external taxonomy.** smn deliberately withdrew its species
  scheme in PR #27, and species concepts are never minted in `gcdfo` (Brett,
  2026-08-17), so there is no internal home to point at and none is being
  created.

**Recorded in:** the PFMA/A1 section of the
[S9 card](sequences/s9-ontology-alignment.md) — the gcdfo-facing item — and
[S12](sequences/s12-fraser-coho-gold-standard.md)'s two-gap section. It is also
the content of Q5's carve-out.

### Q10 — Which membership test governs the hub, and is the workshop the eighth member? — ANSWERED 2026-08-24 (Brett)

**Ruling:** *"sounds good I will take your suggestions."* — which is
[OD-1](roadmap.md#od-1--which-membership-test-governs-and-is-salmon-data-standards-workshop-the-eighth-member)
option **B**, in all three of its parts:

1. The **domain card's** test governs: *membership follows from this hub
   sequencing that repository's work.* The roadmap's *input* test loses and has
   been **deleted**, as OD-1's retirement condition required — leaving both
   alive is how the contradiction regrew last time.
2. **`salmon-data-standards-workshop` is the eighth member.** The allowlist is
   now eight rows, and its release-index section is a member row rather than a
   courtesy record.
3. **`psc-data-transformations` stays a typed external edge** —
   requirements-driving consumer — with its substance in
   [S13](sequences/s13-fraser-recruits-case-study.md). Its pin on metasalmon
   0.1.8 is a constraint this package should know about, not an obligation on it.

**Applied, not merely recorded:** the allowlist table, the roadmap's *Domain
allowlist* rule, and every ecosystem "seven" count in the bundle
([roadmap](roadmap.md) frontmatter and body, the
[domain card](domains/salmon-data-ecosystem.md), the
[hub-coordination context](contexts/hub-coordination.md), the
[S6 card](sequences/s6-ecosystem.md)) now read eight. OD-1 is resolved in both
places; its heading is kept **verbatim** so every existing link to it still
resolves.

**One consequence worth naming, because it is the weakest link in this ruling.**
`salmon-knowledge-commons` was admitted 2026-08-17 under the *input* test that
has now been deleted. It stays a member under the sequencing test — this hub
sequences work that lands in it: S12's two ontology gaps, S9's term-request
routing, and gcdfo PR #87's routing of durable salmon knowledge there are all
hub-sequenced work whose output is a commons card. Its admission is therefore
**restated in sequencing terms**, exactly as option B said it would have to be,
rather than re-opened. If that restatement is wrong, this is the place to
re-examine.

### Q11 — Do `metadata/semantic/**` files belong in the SDP specification? — ANSWERED 2026-08-24 (Brett)

**Ruling:** *"Yes."* — i.e. adopt them into `smn-data-pkg`, per the
recommendation. The status quo quietly makes metasalmon the de facto
specification for a whole directory of package content, which is the failure the
hub exists to prevent.

**The next concrete step is now stated in the owning backlog item
([#114](backlog.md)):** file a `smn-data-pkg` issue carrying the inventory of
what metasalmon writes there today — the `*.sssom.tsv` mapping sets and their
`metadata/semantic/mapping-sets.json` manifest, and
`metadata/semantic/measurement-decompositions.csv` with its `.json` binding
(plus the adjacent `metadata/semantic_vocabulary.csv` the EML mapping pins) —
proposing a `SPECIFICATION.md` section and the profile/schema entries that go
with it. The spec repo owns the layout **before** metasalmonpy mirrors it, or
the mirror inherits metasalmon's shape and the adoption becomes a rename.

**Recorded in:** [backlog #114](backlog.md) (smn-data-pkg section).

### Q14 — Two ownership sentinels: which side gives way? — ANSWERED 2026-08-24 (Brett)

**Ruling:** *"I want one share sentinel name. Nobody uses this yet so dont worry
about breaking changes."* (reading "share" as *shared*.)

Option **(1)**: **one shared sentinel name**, recognised and written by both
implementations, because the honest answer to "who owns this directory" is *the
SDP tooling*, not one language's copy of it. Option (2) — each writer removing
the other's file — stays ruled out.

**The compatibility break is explicitly accepted.** The recommendation had
proposed a read-both/write-shared transition with the old names retired a
release later; the second sentence of the ruling makes that transition
**optional rather than required**. Both implementations may write the shared
name and stop recognising the per-language ones, and no migration is owed to
existing packages. The ownership test already falls back to the SDP-CSV check on
both sides, so nothing refuses a package written by the other implementation
either way.

**Filed, not done here.** Choosing the name and landing it in both repositories
is follow-up work: **[backlog #113](backlog.md)** in this repo, with the ruling
attached, and the twin text for metasalmonpy's `PARITY.md` row **51**.
[parity-deviations](parity-deviations.md) row 51's retirement condition now names
the ruling instead of the open question. This pass renames nothing.

### Q15 — Writing into an existing *empty* directory: which order is right? — ANSWERED 2026-08-24 (Brett)

**Ruling:** *"Go with the python implementation."*

So **metasalmon moved**: `.ms_check_package_write_dir()` now tests emptiness
**before** the `overwrite` gate, matching `package_io._check_package_write_dir()`,
and an existing directory with nothing in it is written into without
`overwrite = TRUE`. `create_sdp()`'s own earlier copy of the gate moved with it,
or the coarser guard would have silently won.

**The ruling settled the direction; the measurement settled what it means.**
Both sides already computed the *identical* notion of "empty" —
`.ms_dir_entries()` is `list.files(all.files = TRUE, no.. = TRUE)`, Python's is
`list(target.iterdir())`, so dot-files count on both — and only the predicate's
**position** relative to the `overwrite` gate differed. Driving five directory
shapes through both implementations found exactly one divergent cell (a truly
empty directory) and agreement on the other four: a dot-file, a stale
`.metasalmon-package` sentinel, an empty `data/` subdirectory and a non-empty
directory all abort on both sides. So **emptiness is literal and never
recursive**, and a near-empty directory still requires `overwrite`.

**Done, not filed.** Both suites now pin the empty-directory write and each of
the three near misses — the case the question said neither side tested.
[parity-deviations](parity-deviations.md) row 54 is retired as converged, in
both registers, recording that R moved and why.

### Q16 — Does `create_sdp()` deterministically prefill constraint and statistical modifier? — ANSWERED 2026-08-24 (Brett)

**Ruling:** *"Yeah lets go the R way."*

So **metasalmonpy moved**: `_auto_apply_package_suggestions()` drops the
four-role restriction on the deterministic path, letting the evidence gates in
`_measurement_suggestion_is_compatible()` decide, and **marks** the two
qualifier slots `REVIEW:` alongside the four core ones. The marking is not a
detail of the port — review-visibility is what the question turned on, so a
port that filled the same slots without marking them would have taken the
behaviour and dropped its justification.

**Two things the port found that the question did not describe.** First,
metasalmon's "no role restriction" is true of its **deterministic path only**:
its LLM path restricts to the same four roles, so porting `roles = NULL`
unconditionally would have widened the mirror *past* R and re-opened the
divergence in the other direction. Second, **neither side pinned the positive
case** — both suites already asserted the two slots stay *empty* when the gate
rejects, and nothing asserted they ever fill, which is precisely how the
divergence survived two green suites. Both now pin the written dictionary, each
with an unqualified-column twin proving the gate still holds.

**Done, not filed**, including the prose: the mirror's `guides/faq.qmd` and
`guides/parity.qmd` carried the "never auto-filled" sentence that was true for
Python and is now false, corrected in the same change.
[parity-deviations](parity-deviations.md) row 57 is retired as converged in both
registers. The differential also turned up one thing the ruling deliberately
does **not** cover — the two sides spell the `REVIEW:` marker differently — now
row 60 and [Q18](#q18--review--or-review--does-the-markers-exact-spelling-matter).

---

**Q19 to Q37 arrive from a plan rather than from this file.** They were drafted,
put to Brett, and ruled inside the
[Foundry plan](plans/2026-09-04-salmon-science-foundry-concrete-plan.md): Q19 to
Q30 on 2026-09-05, Q31 to Q37 on 2026-09-09. Until 2026-09-09 they lived only
there, which is the failure this file exists to prevent, because a decision only
Brett can make is worth nothing to the next agent if it is filed inside the
document that asked for it. Every entry below is an index card: the full text,
with its reasoning, is Appendix A of that plan, and each entry names its
appendix question so the two cannot drift apart silently. **Four of the nineteen
are withdrawn or moot rather than ruled** (Q31, Q32, Q33, Q36), because Brett
took the PSC ontology out of the hub on 2026-09-09 and the questions it had
raised stopped existing. They keep their numbers and headings under this file's
never-delete convention: a withdrawn question is a different thing from a
decided one, and these four are the record of why this hub contains no PSC
ontology.

### Q19 — Is the Foundry the ninth member of the hub? — ANSWERED 2026-09-05 (Brett)

**Ruling: yes.** `salmon-science-foundry` is a hub member and the hub sequences
its work as S14.

**The paste was then held, and the hold was lifted four days later.** On
2026-09-05 the mechanics (the domain-card row, the release-index section, and
the member count where it is restated) were deliberately deferred until the
coordination change landed, on the grounds that the count was about to become
derivable and pasting nine more copies of a number days before deleting them is
the duplication that change exists to remove. **On 2026-09-09 Brett ruled that
the integration be completed rather than held**, so the hold is over and the
paste lands with the coordination change instead of behind it. The four-day gap
is recorded here rather than smoothed over: a membership that is ruled but
invisible in the bundle reads as an unruled question to every agent except the
one who held the paste.

**Full text:** Appendix A Q19, and the drafts in the
[S14 hub-integration kit](plans/2026-09-04-s14-hub-integration-kit.md).
**Owner:** the S14 card (`sequences/s14-salmon-science-foundry.md`).

### Q20 — Do `sdp-example-data` and `salmon-ontology-hub` join the hub? — ANSWERED 2026-09-05 (Brett)

**Ruling: neither joins.** Brett: *"The Salmon Ontology hub is mainly for
updating the RDA community on what the Salmon Ontology Development Group is up
to. That can be done separately."* The Hub site is a communications surface for
the RDA working group, not hub-sequenced work, so it gets no stream, no
release-index section, and no milestone ladder; `sdp-example-data` gets no
hub-sequenced work either, and the three 2020 to 2021 prototypes are archived
after the credential audit.

**Full text:** Appendix A Q20. **Owner:** the
[domain card](domains/salmon-data-ecosystem.md).

### Q21 — Does the commercial boundary belong in this public bundle? — ANSWERED 2026-09-05 (Brett)

**Ruling: the consultancy's products stay out of public documentation
anywhere.** The boundary rules stay in the plan in anonymous form, the
graph-design companion is not added to this bundle, and no product or company
name appears in any public repository.

Brett asked whether a hook could enforce it, and one is installed: a `PreToolUse`
guard reading a denylist that lives outside every repository, so the terms it
protects are never themselves committed. **Its retirement condition and its
known blind spots are stated with it** in the plan's coordination section, which
is where a guard's limits belong.

**Full text:** Appendix A Q21. **Owner:** the plan; the guard is a
machine-level control rather than a bundle rule.

### Q22 — Which runtime tier does the Foundry start on? — ANSWERED 2026-09-05 (Brett)

**Ruling: Tier 0, recorded as ADR-0001.** A content-addressed store, receipts,
`approvals.jsonl`, and an idempotent driver. Tier 1 and Tier 2 are recorded with
their entry triggers and are not funded in Stage A, so the runtime question is
answered by a measured condition rather than by a preference.

**Full text:** Appendix A Q22. **Owner:** the S14 card
(`sequences/s14-salmon-science-foundry.md`).

### Q23 — What is SalmonBench's scope? — ANSWERED 2026-09-05 (Brett)

**Ruling: a 25-task pilot in Stage A and a 60-task v0.1 in Stage B**, with 75
and 150 tasks as six- and twelve-month targets. The three Theme A captures
finish as the pilot's regression anchor.

**Full text:** Appendix A Q23. **Owner:** the S14 card
(`sequences/s14-salmon-science-foundry.md`), with the captures under
the [Theme A record](plans/2026-07-28-theme-a-semantic-review.md).

### Q24 — May a subset of the private commons be published? — ANSWERED 2026-09-05 (Brett)

**Ruling: not in Stage A or Stage B, and "stable" has a bar.** A card is stable
when it carries a named human `verified` entry and passes its citation ledger.
Publication of a subset that meets that bar, with a licence, is a separate
ruling for the commons repository rather than something this plan can grant.

**Full text:** Appendix A Q24. **Owner:** the S14 card
(`sequences/s14-salmon-science-foundry.md`) for the compiler;
`salmon-knowledge-commons` for publication.

### Q25 — Does the 173-row gold standard move, copy, or get referenced? — ANSWERED 2026-09-05 (Brett)

**Ruling: reference, never copy.** The Foundry's source receipt records the Open
Government record, the derivation, and the SHA-256 at a metasalmon tag;
consumers fetch by checksum; one derivation script, and it lives in metasalmon.
That also settles the half of parity row 46 that asked which repository owns the
derivation.

**Full text:** Appendix A Q25. **Owner:**
[S12](sequences/s12-fraser-coho-gold-standard.md) and
[parity row 46](parity-deviations.md).

### Q26 — Which repositories live under the institute now? — ANSWERED 2026-09-05 (Brett)

**Ruling: two, the Foundry repository and SalmonBench.** Nothing else moves:
`smn-sci-plgn` stays a personal repository and is repointed at metasalmon 0.5.0
in place, and the eight existing hub members stay where they are. Naming
SalmonBench as an institute repository from the start reverses the review's
"keep it in `bench/` until extraction criteria are met", so the extraction
happens at creation time and the plan records that cost.

**Full text:** Appendix A Q26. **Owner:** the plan and the
[domain card](domains/salmon-data-ecosystem.md).

### Q27 — Where do the `salmon` data-access verbs live? — ANSWERED 2026-09-05 (Brett)

**Ruling: inside metasalmon and metasalmonpy**, under the mirror rule, with the
receipt schema shared. A sibling package pair only if a measured dependency or
file-size cost appears, which makes the split a triggered decision rather than
an open one.

**Full text:** Appendix A Q27. **Owner:** the plan, and the mirror rule in
`AGENTS.md` if it is extended.

### Q28 — Licence and contributor terms? — ANSWERED 2026-09-05 (Brett)

**Ruling: MIT for code, CC BY 4.0 for benchmark tasks and documentation,**
per-asset licences for fixtures in the register, and a developer certificate of
origin rather than a contributor licence agreement until counsel says otherwise.
Incorporation-dependent choices still need professional review.

**Full text:** Appendix A Q28. **Owner:** the institute; the plan records the
choice.

### Q29 — Backlog #95: fix `infer_column_role()` or the code-row seeder? — ANSWERED 2026-09-05 (Brett)

**Ruling: fix role inference.** A column that has a code list is `categorical`
by the specification's own definition, and the seeder is downstream of that
decision. Pinned with a fixture on both sides, so the mirror obligation is
discharged with the fix rather than after it.

**Full text:** Appendix A Q29. **Owner:**
[S12](sequences/s12-fraser-coho-gold-standard.md) and
[S1](sequences/s1-validation-authority.md), with the defect in
[backlog #95](backlog.md).

### Q30 — Which OKF profile does the Foundry's bundle use? — ANSWERED 2026-09-05 (Brett)

**Ruling: whichever is the better long-term design, and Brett is not tied to the
PSC profile.** The answer taken is **upstream OKF v0.2** with the commons'
strict closed schema and its `okf-check.py`: the PSC v0.4 profile rejects
exactly the provenance fields the Foundry's claim contract needs, validating an
institute bundle with a PSC-owned tool from a sibling checkout is the
cross-boundary dependency the plan forbids everywhere else, and the commons'
checker is already stricter than the profile check.

**The cost is named rather than hidden:** the hub's own bundle still uses the
PSC profile, so the ecosystem carries two validators until the hub migrates.
That migration is Q34, deliberately kept separate because it is bundle-wide and
follows the coordination change.

**Full text:** Appendix A Q30. **Owner:** the S14 card
(`sequences/s14-salmon-science-foundry.md`).

### Q31 — Repository name and namespace for the PSC core model — WITHDRAWN 2026-09-09 (Brett)

**Withdrawn, not decided.** Brett: *"I don't think I want the PSC Ontology as
part of this hub anymore."* No repository is created by this plan, so it needs
no name and no namespace, and the question has no answer because it no longer
has a subject. The recommendation on the table when it was withdrawn stands as a
starting point if the work is ever revived, and it belongs in a PSC record
rather than in this bundle.

**Full text:** Appendix A Q31. **Owner:** none; withdrawn with the PSC
workstream.

### Q32 — Does the Domain Vision Statement come before the first flagged term? — MOOT 2026-09-09 (Brett)

**Moot, not decided.** Brett: *"irrelevant now."* It went with the PSC
workstream. The underlying principle is worth keeping wherever that work lands:
build the context map before the model, and mint no class that does not answer a
numbered competency question.

**Full text:** Appendix A Q32. **Owner:** none.

### Q33 — Which PSC bounded contexts register first? — WITHDRAWN 2026-09-09 (Brett)

**Withdrawn, not decided.** Brett: *"Let's leave PSC out for now."* None
register. Fraser Recruits returns to out-of-scope, which restores the 2026-09-04
position rather than creating a new one, and
[S13](sequences/s13-fraser-recruits-case-study.md)'s three metasalmon-side
requirements are unaffected: they are this package's compatibility obligations
to a consumer that already exists, and were never PSC work.

**Full text:** Appendix A Q33. **Owner:** none.

### Q34 — Does the hub's own bundle migrate to upstream OKF v0.2? — ANSWERED 2026-09-09 (Brett)

**Ruling: yes, and the withdrawal of the PSC work strengthens the case rather
than weakening it.** Brett asked whether the migration still made sense once the
PSC ontology left. It makes more sense: the argument was that a public,
institute-adjacent bundle should not validate itself with a PSC-owned tool from
a sibling checkout, and with no PSC work anywhere in this programme that
dependency has nothing on the other end of it. `psc-salmon-vocabularies` keeps
the PSC profile in its own repository, because profile follows ownership.

**Sequenced after the coordination change, not before**, because the documented
validation command is repeated in several cards and moving it is itself an
instance of the duplication that change is fixing.

**Full text:** Appendix A Q34. **Owner:** this bundle.

### Q35 — The institute's GitHub organization slug — ANSWERED 2026-09-09 (Brett)

**Ruling: the institute is renamed to Symecology Institute**, and the plan
assumes the slug `Symecology-Institute`, which is still unconfirmed. No GitHub
organization exists under this name or the previous two.

**The name has moved twice in five days, which is why the organization is not
created yet:** a rename redirects repository links but returns 404 for the
organization profile and for old-name API calls, and it releases the old name
for anyone to claim. So the organization is created when a repository needs it,
in Stage A week 3, and nothing in Stage 0 depends on it.

**Full text:** Appendix A Q35. **Owner:** Brett.

### Q36 — Amend the membership test so a PSC-owned repository can be a member? — WITHDRAWN 2026-09-09 (Brett)

**Withdrawn rather than adjudicated, and the distinction is the point.** No
amendment was made and none was needed: with the PSC ontology out of the hub,
nothing was asking the test to stretch, so the tension that produced the
question disappeared instead of being resolved in either direction. The test
ruled in [Q10](#q10--which-membership-test-governs-the-hub-and-is-the-workshop-the-eighth-member--answered-2026-08-24-brett)
stands unamended: *a repository is a member when this hub sequences that
repository's work.* The eight members are unchanged and the Foundry's admission
under Q19 is the ninth.

**Full text:** Appendix A Q36. **Owner:** the
[domain card](domains/salmon-data-ecosystem.md); no change.

### Q37 — Which authorization paragraphs does Brett grant? — ANSWERED 2026-09-09 (Brett)

**Ruling: paragraph 1 only**, meaning git pushes to claim refs and `agent/`
branches.
Paragraph 2, the generated Project view and its sync, no longer exists because
Brett dropped the GitHub Project the same day. Paragraph 3, one draft pull
request per handed-back item, is **declined**: an agent pushes its branch,
prints the compare URL, and stops, and Brett opens every pull request himself.

So the standing authorization for the whole coordination system is a single
paragraph covering two `git push` targets, with a closed exclusion list and a
self-suspending clause. **The operative copy lives in `HUB.md` and nowhere
else**, because the one text whose stale copy causes an unauthorized write is
the last text that should be duplicated.

**Full text:** Appendix A Q37. **Owner:** Brett's global instructions, with
`HUB.md` as the operative copy.
