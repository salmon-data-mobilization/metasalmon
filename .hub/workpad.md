# Workpad — B-146

## Queue item

**B-146** — "Write the iop-triple explainer for SDPs, a knowledge card with a
recommendation and no code" (repo metasalmon, stream S9, severity P4, venue
`claude-science`). Claimed by `a-037543610cf047ef` on 2026-09-14; work branch
`agent/B-146/a-037543610cf047ef`, worktree
`hub-worktrees/salmon-data-mobilization-metasalmon-B-146`.

This workpad replaces the B-49 copy that is tracked on `main`; each branch
carries its own.

Evidence read first, in this order: the **#78** entry in
`knowledge/backlog.md` (the source of the three questions), then
`queue/items/B-78.yaml` (the decision half), `knowledge/questions.md` **Q46**
(Brett's allowance) and **Q3** (descriptor I-ADOPT keys), and §4.6 of
`knowledge/plans/2026-09-12-queue-promotion-review.md`.

## What changed and where

Three files, all under `knowledge/`. **No code.** That restriction is the whole
point of the B-146 / B-78 split: an implementation would pre-empt the decision
Brett kept.

1. **`knowledge/plans/2026-09-14-iop-triple-explainer.md`** — new, the
   deliverable. Answers the three questions #78 asks, carries a recommendation,
   and marks the recommendation as a proposal awaiting B-78 in its own status
   block and again in §6.
2. **`knowledge/sequences/s9-ontology-alignment.md`** — two pointer edits. Step
   6 and the "remaining in S9" summary both read as though the explainer were
   still owed; both now point at the card and say the *ruling* is what remains.
   I deliberately did **not** rewrite the parked/deferral wording beyond that:
   whether an item is parked is queue state, which HUB.md says a card must not
   restate, and that pre-existing instance is neither mine to widen nor mine to
   fix under this claim.
3. **`knowledge/backlog.md`** — appended a pointer to #78 naming the card, the
   premise correction described below, and the two out-of-scope findings. #78's
   severity and state wording is untouched.

### Where the card goes, and why there rather than the commons

`AGENTS.md` draws the line: `knowledge/` is about **this repo**; durable
knowledge about **salmon** goes to `salmon-knowledge-commons`. This card is
about RDF emission from a data-package format — a design question about
metasalmon and the SDP, containing no claim about salmon biology, ecology or
management. It belongs here, and in `knowledge/plans/` specifically: the two
cards written the same day (`2026-09-14-commons-verification-scheme.md`,
`2026-09-14-taxonomic-assignment-briefing.md`) are exactly this shape — a dated
proposal or briefing awaiting a ruling — so the card matches its neighbours
rather than inventing a location. Nothing in it was a candidate for the
commons.

### The premise correction, which is the substantive finding

Backlog #78 and the B-146 scope both say metasalmon "never emits triples".
**That is not true, and the difference reshapes the question.** `R/eml-export.R`
writes EML 2.2 semantic annotations, which are RDF triples by the EML
specification's own account — its Semantic Annotation Primer says the annotated
parent element *is* the subject, and carries appendix sections titled *Semantic
triples* and *RDF Graphs*. The exporter emits exactly two per measurement
attribute from `.ms_eml_measurement_predicates`: `dcterms:subject` → `term_iri`
and `qudt:hasUnit` → `unit_iri`. Its own roxygen states the omission on purpose:
*"The exporter deliberately does not project incomplete I-ADOPT roles or
procedure annotations into EML."*

So there is already a triple surface, narrowed for a stated reason, and the
decomposition is precisely what it was narrowed to exclude. The card answers
that reason rather than stepping around it, and flags its answer as *my reading
of the exporter's intent, not a ruling recorded anywhere* — the point in the
card I would most want contradicted.

### The finding the recommendation turns on

`iop:Variable` is an `owl:equivalentClass` of two **exactly-1 qualified
cardinality** restrictions (one `hasObjectOfInterest` onto `Entity`, one
`hasProperty` onto `Property`), verified against the served turtle. Two
consequences:

- Because it is `equivalentClass` and not `subClassOf`, emitting the component
  triples already types the subject as a Variable by entailment. An explicit
  `rdf:type` triple is redundant to a reasoner and necessary for every consumer
  that does not reason — which is nearly all of them.
- Because the cardinality is exactly 1, a plural emission is a **false
  assertion rather than an error**: a reasoner concludes the two entities are
  the same individual, and the file is well-formed RDF either way. **The SDP can
  already produce that input** —
  `.ms_sdp_decomposition_validate_order_and_uniqueness()` rejects only *exact*
  duplicate components, so two **distinct** `entity` rows for one measurement
  are valid today. That is why refusing this case is generator rule 1 in the
  card rather than a footnote.

One further trap recorded in the card: I-ADOPT's term IRIs are **slash-form**
(`https://w3id.org/iadopt/ont/Variable`). The turtle declares
`@prefix : <https://w3id.org/iadopt/ont#>` and uses that hash namespace for no
term at all, so expanding `iop:` to the hash form yields IRIs that resolve to
nothing and join no graph — with nothing about the output looking wrong.

## Commands run and results

Failing-before / passing-after does not apply: B-146 is a writing item, not a
defect with a reproduction. What is verifiable is that the card is valid in the
bundle's shape and that the shipped package is unchanged.

```
$ python3 scripts/hub_queue.py lint
97 item(s) in queue/items.
Defects with no `retires_when`: 0 (baseline 0 ...)
OK

$ python3 scripts/hub_queue.py check
OK: every generated block matches the hub queue.

$ git diff --check
(clean)

$ git status --porcelain | grep -E '(^|/)(R|tests|inst|man|vignettes)/|NAMESPACE|DESCRIPTION|NEWS'
none - knowledge/ only

$ git diff HEAD --stat -- R/ tests/ inst/ man/ vignettes/ NAMESPACE DESCRIPTION NEWS.md
(empty)
```

**Why I did not run `devtools::test()` or `rcmdcheck()`.** That last command is
the evidence: the diff touches `knowledge/` and nothing else, so the shipped
package is byte-identical to `main` and a suite run would re-measure `main`
rather than this change. `knowledge/` is `.Rbuildignore`d (`^knowledge$`, line
11), so it is not in the tarball at all. Stating this rather than pasting a
green run that proves nothing about the change.

**Bundle validation could not be run, and this is not a silent skip.** The
documented command needs a sibling `psc-data-systems` checkout:

```
$ ls -d ../psc-data-systems /home/user/psc-data-systems
ls: cannot access '../psc-data-systems': No such file or directory
ls: cannot access '/home/user/psc-data-systems': No such file or directory

$ uv run --project ../psc-data-systems psc-okf check knowledge --tier capture
error: Failed to spawn: `psc-okf`
  Caused by: No such file or directory (os error 2)
```

`uv` is installed; the checkout and the `psc-okf` entry point are not, anywhere
on this machine. So I did the documented fallback and then some:

- **Front matter matched by parse, not by eye.** Parsed the YAML of all 22
  cards in `knowledge/plans/`. The directory holds exactly **one**
  front-matter shape — keys `description, psc, status, tags, title, type`, with
  `psc` carrying `contexts, id` — and the new card is in it: `type: Artifact`,
  `status: draft`, `psc.id:
  metasalmon:plan:2026-09-14-iop-triple-explainer`, `contexts:
  [metasalmon:context:hub-coordination]`.
- **No absolute filesystem paths** in any of the three files (0 matches for
  `/home`, `/Users`, `/tmp`, `/var`, `/root`, `/mnt`).
- **Every link resolves.** The four relative targets (`../backlog.md`,
  `../questions.md`, `../parity-deviations.md`,
  `../sequences/s9-ontology-alignment.md`) exist; all nine in-page anchors match
  a real heading slug.
- One anchor was renderer-dependent, because an em-dash in a heading yields a
  double hyphen under GitHub's slugger and a single one elsewhere. Rather than
  bet on a renderer I replaced the em-dash with a colon, so the slug is
  unambiguous in both.

## Citations: resolved with tools, not asserted

Ran the `citation-ledger` procedure: seven sources resolved, four negatives
logged. The ledger (`ledger.csv` / `ledger.json`) is in this session's
scratchpad and is **not committed** — it is working evidence, and the card's §9
carries the part a reader needs.

**The procedure earned its keep immediately.** The DOI I recalled as the I-ADOPT
framework paper, `10.1038/s41597-022-01602-0`, resolved via CrossRef to *"Nine
out of ten samples were mistakenly switched by The Orang-utan Genome
Consortium"* — an unrelated article. It is cited nowhere. No peer-reviewed
I-ADOPT *journal* article surfaced across four CrossRef query formulations, only
EGU conference abstracts, so the card cites the ontology itself (turtle fetched,
200, `text/turtle`, 21645 bytes) and the RDA WG output (`10.15497/RDA00071`,
resolved via DataCite — **metadata only, full text not read**, and §9 says so,
so no claim rests on its contents).

Also logged: the guessable ontology turtle paths both 404 and the served copy is
at `.../ontology/ontology.ttl` — recorded because a card that tells an
implementer to fetch the vocabulary must name the path that works. And the Data
Package v2 claim is scoped honestly: it rests on string counts over the
retrieved page (`@context` 0, `json-ld` 0, `rdf` 0), which is weaker than a
normative statement, and the card says so in place.

**No verification is asserted anywhere.** The card says "tool-resolved, not
human-verified" and "nothing here has been independently checked".

On `generated:` — **the brief asked me to fill it and I deliberately did not**,
because in *this* bundle that field is invalid. metasalmon's `knowledge/` uses
the **PSC profile**, which per Appendix A of the Foundry plan (quoted in
`knowledge/plans/2026-09-04-s14-hub-integration-kit.md`) "rejects exactly the
provenance fields (`sources`, `generated`, `verified`, `stale_after`,
`resource`)" that upstream OKF v0.2 carries. `generated`/`verified` are the
**commons'** convention, not this bundle's, and none of the 21 neighbouring
cards has either field — adding one would fail the lint. So authorship is
recorded the way the neighbours record it, in the `description` and in the
status block ("Written by an agent", dated), which meets the brief's intent —
say who wrote it, never claim to have checked it — in the shape this bundle
accepts. Flagged here because it is a deliberate deviation from an instruction,
not an oversight.

## What I did not do, and why

- **No implementation, no code, and no `NEWS.md` entry.** The absent NEWS entry
  is deliberate and grounded rather than an oversight: `knowledge/` is excluded
  from `R CMD build` and nothing observable changes.
- **Did not decide the question.** §6 is marked a proposal awaiting B-78, and
  states the condition that would change it — whether DataONE's production index
  would actually query the extra predicates. I could not check that, and the
  card names it as the load-bearing uncertainty rather than assuming it
  favourably.
- **Did not touch metasalmonpy.** The card states the mirror obligation and
  costs it into the recommendation, but parity work follows a ruling and is its
  own item.
- **Did not add the card to `knowledge/index.md`.** Neither 2026-09-14
  neighbour is indexed there; matching the neighbours beat inventing a
  convention. Raised below as a possible bundle-wide issue instead.
- **Did not run the bundle check** — impossible here, evidenced above.

## Belongs to another item

- **B-78** — the decision on what this card recommends. Untouched by design;
  that is the split.
- **B-108 / Q-06** — the taxonomy briefing written the same day overlaps on
  `smn`/`gcdfo` modelling but not on triple emission. No interaction found.

## Candidate new items (evidence, not absorbed)

1. **The SDP cannot distinguish `hasObjectOfInterest` from
   `hasContextObject`/`hasMatrix`.** I-ADOPT separates the entity whose property
   is observed from a background-context entity and from the containing matrix
   (`hasMatrix rdfs:subPropertyOf hasContextObject`). The SDP has one
   `entity_iri`; the decomposition artifact has one `entity` role. An emitter
   must map everything to `hasObjectOfInterest` or refuse to guess.
   `smn-data-pkg` shape question; affects both mirrors.
2. **The SDP cannot express I-ADOPT's `constrains`.** `constrains` has domain
   `Constraint` and range `unionOf(Entity, Property, StatisticalModifier)` — it
   names *which component* a constraint confines. `constraint_iri` is a flat
   semicolon bag. `measurement-decompositions.csv` does have
   `component_relation` / `related_component_order`, but its only permitted
   value is `value_of_dimension`, which joins two `constraint` rows and is not
   `constrains`. Adjacent to (1); probably one item with it.
3. **`datapackage.json` declares Frictionless v1 `profile`, not v2 `$schema`.**
   `smn-data-pkg` SPECIFICATION.md line 77 requires setting `profile`; the
   retrieved Data Package v2 standard lists `$schema` among descriptor
   properties and no `profile`. Found while checking whether a `@context` could
   live in the descriptor. Out of scope for B-146 and not investigated further —
   it may be a deliberate v1 pin.
4. **Dated proposal cards in `knowledge/plans/` are reachable from nothing.**
   Both 2026-09-14 neighbours are linked from no file but themselves. Possibly
   fine, possibly a discoverability defect in the bundle. Named, not fixed.

## Ontology gaps

**None to file, and that is a finding rather than a blank.** AGENTS.md defines
an ontology gap as a concept with no term in `smn`, `gcdfo` or the PSC CV.
Writing the card surfaced no such concept: every predicate the recommendation
needs already exists in I-ADOPT 1.1, and every component term comes from
vocabularies already in the retrieval path. The two gaps found (candidates 1 and
2) are **SDP format-expressivity gaps against I-ADOPT** — nothing needs minting
— so filing them as term requests would be wrong. The card says this in §8 so
they do not die in a transcript.

## Retirement condition of any guard, suppression, skip or workaround added

**None added.** No code, no tests, no CI changes, no allowlist entries, nothing
silenced — so there is nothing here that needs a retirement condition.

For completeness, the card *recommends* two future guards and states the
retirement condition of each up front, so a later implementer inherits them
already formed: the plural-component refusal (retires when the decomposition
validator itself enforces the exactly-1 cardinality, at which point the emitter
can trust its input) and a `SURFACE 8` section in
`tests/testthat/test-role-contract-guard.R` if a role-to-predicate map is
introduced (retires only with the map). Recommendations, not additions —
nothing on this branch implements either.

The one skip in this run is the bundle check, and it is an environment
limitation rather than a guard: it retires the moment a sibling
`psc-data-systems` checkout exists on the machine, at which point the documented
command should be run against this card unchanged.

## Retirement condition of the item

B-146's `retires_when` is satisfied: the card lands and covers (a) who the
consumers are and what they concretely cannot do today, (b) where the triples
live, what generates them, and how they version, and (c) whether emission should
be a general SDP capability and what that costs in implementation, maintenance
and format commitment — carrying a recommendation marked as awaiting B-78, and
no implementation.
