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

### Q15 — Writing into an existing *empty* directory: which order is right?
**Unblocks:** parity row 54, and a test on both sides that nothing currently pins.
metasalmon refuses it without `overwrite = TRUE`; metasalmonpy writes into it.
Pre-0.1.6 debt found by metasalmonpy's 0.4.0 audit, carried faithfully and
silently since before the parity claim, and **pinned by neither suite** — R's
test uses a non-empty directory, the mirror does not test the case. **Only you
can rule it**, because it is user-visible whichever way it goes (refusing a
write that used to succeed, or permitting one that used to abort) and the
2026-08-17 amendment says a divergence opens the question rather than settling
it. **It turns on which failure is worse:** R's order is the safer default — an
existing directory is a signal the caller may not have meant this path — while
metasalmonpy's is friendlier to `mkdir -p && write`, where an empty directory
has no data to destroy and demanding `overwrite` for it trains callers to pass
`overwrite` habitually, which is the flag's whole value gone.
**Recommendation:** none offered; the two grounds are genuinely opposed and a
recommendation here would be the invented ruling row 54 exists to avoid.
**Owner:** [parity row 54](parity-deviations.md).

### Q16 — Does `create_sdp()` deterministically prefill constraint and statistical modifier?
**Unblocks:** parity row 57, and the same sentence of prose on both sides.
metasalmon applies every role the evidence gates allow; metasalmonpy restricts
the deterministic path to `variable`, `property`, `entity`, `unit`. Each side's
docs matched its own code while the code diverged, so no reader was positioned
to catch it — metasalmon 0.4.0 corrected its quickstart's "never auto-filled"
claim as wrong for R, and the identical sentence is still true for Python.
**It turns on what a marked prefill is worth against an unreviewed IRI in a slot
the user did not ask about:** R's gates already demand the evidence come from
the column's own text and the path marks what it filled, so the wider behaviour
is review-visible rather than silent — but constraint and statistical modifier
are the two roles that change what a variable *is*, and a wrong one is harder
for a reviewer to notice than a missing one.
**Recommendation:** none offered, for the same reason as Q15.
**Owner:** [parity row 57](parity-deviations.md).

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
