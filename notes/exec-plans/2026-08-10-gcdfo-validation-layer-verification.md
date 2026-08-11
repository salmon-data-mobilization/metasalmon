# Verification: is the GC DFO Salmon Ontology validation layer inert?

Date: 2026-08-10. Read-only verification of P0-9 from
`2026-08-10-comprehensive-ecosystem-review.md`. No files in
`dfo-salmon-ontology` were modified.

The comprehensive review flagged this as **finder-only, unverified** — the
adversarial pass died on a spend limit. This is that missing verification.

**Verdict: all three claims confirmed, two of them more sharply than reported.**
One claim needs an important nuance added before anyone acts on it.

Method: `rdflib` 7.6.0 and `pyshacl` 0.40.1 in a throwaway venv (the repo's own
`venv/bin/python3.14` symlink is broken — it points at
`/usr/local/opt/python@3.14/bin/python3.14`, which does not exist, so `make`
targets depending on it cannot run either). `robot` is not installed, so the
ROBOT finding is verified statically.

---

## 1. SHACL shapes are inert — CONFIRMED, and the cause is precise

The ontology declares 161 subjects in `https://w3id.org/gcdfo/salmon#`
(`ontology/dfo-salmon.ttl`, 1506 triples).

`ontology/shapes/dfo-salmon-shapes.ttl` binds its **default prefix `:` to
`https://w3id.org/dfo/salmon#`** — note: no `gcdfo`. That namespace appears
nowhere in the ontology. Consequently:

- both `sh:targetClass` values (`…#EscapementMeasurement`,
  `…#EscapementSurveyEvent`) resolve to IRIs absent from the ontology;
- **all 11** `sh:path` IRIs are absent: `aboutStock`, `countUnitIRI`,
  `countValue`, `measuredObserverEfficiency`, `measuredReachCoverage`,
  `measuredVisibility`, `measuredVisits`, `observedDuring`, `percentRiverSwam`,
  `usesEnumerationMethod`, `usesEstimateMethod`.

Demonstrated consequence — deliberately invalid data (an
`EscapementMeasurement` with no `countValue`, no `aboutStock`, no
`observedDuring`):

| data namespace | `conforms` | violations |
|---|---|---|
| `https://w3id.org/gcdfo/salmon#` (the real one) | **True** | 0 |
| `https://w3id.org/dfo/salmon#` (what the shapes target) | False | 6 |

So the shapes are not broken — they work fine against a namespace nobody uses.
Anyone running `pyshacl` over real gcdfo data gets a vacuous pass.

`ontology/examples/sample-survey-data.ttl` has the same default-prefix binding,
so the shipped example data is also outside the ontology's namespace.

## 2. Competency-question SPARQL cannot run — CONFIRMED, worse than reported

`ontology/sparql/example-competency-questions.rq` (1064 bytes) contains **three
`SELECT` queries in one `.rq` file**. A `.rq` file is a single SPARQL request,
so the file does not parse as-is:

```
ParseException: Expected end of text, found 'PREFIX' (at char 485, line 15)
```

Splitting it into its three blocks and running each against
`ontology/dfo-salmon.ttl` + `ontology/examples/sample-survey-data.ttl`
(1596 triples combined) does not help — every block fails:

```
Unknown namespace prefix : dfo
```

The queries use a `dfo:` prefix that their own `PREFIX` headers never declare.
So it is not merely that the queries return zero rows; **none of the three has
ever been executed**. `docs/ADR.md` (ADR-009) presents SPARQL competency-question
testing as a quality gate.

## 3. The ROBOT quality gate is a no-op — CONFIRMED, with a nuance

`robot-profile.yaml` is two lines:

```
INFO	missing_label
INFO	missing_definition
```

`scripts/robot-quality-check.sh:61` passes it as `--profile "$PROFILE_FILE"`.
ROBOT's `--profile` **replaces** the default profile rather than amending it, so
the quality check runs exactly two checks, both at `INFO` — a severity that
cannot fail a build.

`report_profile.txt` in the repo root is the full 31-check default profile,
including **17 `ERROR`-level checks**. Nothing references it: it is an orphan
(`grep -rn report_profile` over scripts, Makefile, and CI returns nothing
outside `docs/`).

**The nuance that must not be lost.** Running the default profile would report
**124 of 161** gcdfo subjects for `missing_label`, which is `ERROR`. But **all
161 have `skos:prefLabel`** — zero subjects lack both. This is a deliberate
hybrid OWL+SKOS design, and ROBOT's `missing_label` assumes OBO-style
`rdfs:label`. So downgrading *that specific check* is defensible. What is not
defensible is achieving it by replacing the whole profile, which silently drops
the other 16 `ERROR` checks — `duplicate_label`,
`illegal_use_of_built_in_vocabulary`, `deprecated_class_reference`,
`label_whitespace`, and so on.

I verified that three of the ERROR checks the profile drops would in fact
**pass** today: the ontology has `dcterms:license`
(`https://creativecommons.org/licenses/by/4.0/`), `dcterms:title`, and
`dcterms:description`. So "124 uncaught violations" is accurate as a count but
is dominated by one defensible check. The real exposure is the 16 checks nobody
is running, not the 124 labels.

Incidentally confirmed while reading: `owl:versionIRI` is
`https://w3id.org/gcdfo/salmon/0.0.999` — the rolling sentinel the review
flagged separately.

---

## Recommended fix order (for the separate ontology plan)

1. **Rebind the namespace** in `ontology/shapes/dfo-salmon-shapes.ttl` and
   `ontology/examples/sample-survey-data.ttl` from
   `https://w3id.org/dfo/salmon#` to `https://w3id.org/gcdfo/salmon#`. This is a
   one-line change per file and immediately makes the shapes real — expect the
   example data to start failing, which is the point.
2. **Then** mint the ~11 missing survey/measurement properties, or delete the
   shape properties that reference them. Decide per property; do not
   bulk-create.
3. **Split** `example-competency-questions.rq` into one file per query under
   `ontology/sparql/`, and declare the `dfo:`/`gcdfo:` prefix each one uses.
   Add a `make` target that runs them and fails on a parse error.
4. **Fix the ROBOT gate** by starting from `report_profile.txt` and downgrading
   only `missing_label` (with a comment explaining the SKOS labelling
   convention), rather than replacing the profile. Delete `robot-profile.yaml`
   or make it the amended copy.
5. **Repair the venv** — `venv/bin/python3.14` is a dangling symlink, so any
   `make` target that shells into it fails before it starts.

Steps 1 and 4 are the ones that convert two placebo gates into real ones; do
them first and let them tell you what else is wrong.
