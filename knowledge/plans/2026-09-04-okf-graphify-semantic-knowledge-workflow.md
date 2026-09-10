---
type: Artifact
title: "OKF-centred agentic semantic knowledge architecture"
description: "Design note: OKF bundles as the curated authoring layer, SSSOM-aligned mapping cards with a lifecycle, a deterministic OKF-to-RDF compiler gated by SHACL, an optional Graphify discovery layer, and federated bundles with one-way public-to-private knowledge flow. Design input to the Foundry plan's semantics layer; not a sequencing authority."
status: draft
tags: [design, okf, semantics, sssom, graph, foundry]
psc:
  id: metasalmon:plan:2026-09-04-okf-graphify-semantic-knowledge-workflow
  contexts: [metasalmon:context:hub-coordination]
---

> **Status and authority.** Design input, added to this bundle on 2026-09-04
> at Brett's direction. It is not a sequencing authority and activates no
> task. Where it is adopted, the owning card is the
> [Foundry plan](2026-09-04-salmon-science-foundry-concrete-plan.md)'s
> semantics section and, for the commons itself, `salmon-knowledge-commons`'s
> own bundle.
>
> **Provenance.** Imported verbatim from Brett's
> `okf-graphify-semantic-knowledge-workflow.md`, the consolidation of a
> parallel architecture discussion. Only this note and the frontmatter were
> added; the body below is preserved unchanged.
>
> **Three things to read the body with, recorded here rather than edited in:**
>
> - **REVIEW 1 — prefixes.** The examples use `sdo:` for the Salmon Domain
>   Ontology. In this ecosystem the shared ontology's prefix is **`smn:`**
>   (`https://w3id.org/smn/`) and the agency ontology's is **`gcdfo:`**; `sdo:`
>   is widely read as schema.org. Treat `sdo:` below as `smn:`.
> - **REVIEW 2 — what already exists.** Phases 1–2 of §20 are partly built:
>   `salmon-knowledge-commons` already carries gap cards with an enforced
>   `open / proposed / rejected / minted` state machine (its schema requires
>   `rejected_because` and `evidence_needed` on rejection), and
>   `salmon-domain-ontology` and `dfo-salmon-ontology` already publish SSSOM
>   1.1 mapping sets that metasalmon reads strictly. The mapping-card and
>   gap-card shapes here should extend those, not sit beside them.
> - **REVIEW 3 — store choice.** §11 names Fuseki; the Foundry plan's §3.8
>   starts with an embedded, disposable `pyoxigraph` index and moves to Fuseki
>   only when an external consumer needs a persistent endpoint. The two
>   documents agree on the load-bearing rule — the RDF store is a *derived
>   query index rebuilt from the curated bundles, never a second authority* —
>   and differ only on when a server is justified.

# OKF-Centred Agentic Semantic Knowledge Architecture

## Purpose

This consolidates the architecture we discussed for using **Open Knowledge Format (OKF) bundles** as the human/agent authoring layer, optionally using **Graphify** for discovery, and compiling curated knowledge into an **RDF knowledge graph / triplestore** such as Apache Jena Fuseki.

> **Author simply, curate explicitly, compile deterministically, query formally when useful.**

Markdown and Git remain the collaboration surface. Formal semantic infrastructure is a derived representation rather than a second place where humans manually maintain knowledge.

## 1. Architecture at a glance

```text
Human + agent workspace
        |
        v
+---------------------+
|     OKF bundles     |  <-- curated source of truth
| Markdown + YAML/Git |
+----------+----------+
           |
     +-----+---------------------+
     |                           |
     v                           v
Optional Graphify          Deterministic build
(discovery layer)          YAML/Markdown -> RDF
     |                           |
 candidate edges                 v
     |                    SHACL validation
     v                           |
human/agent review               v
     |                    Fuseki / triplestore
     +----> accepted              |
            relations            v
                           SPARQL / reasoning
                                  |
                                  v
                            Agent tool layer
```

The crucial boundary is that **OKF remains the curated source of truth**. Graphify output and the RDF store are derived representations.

## 2. OKF as a lightweight graph

An OKF bundle is already graph-like: concept/document cards are nodes, Markdown links are edges, YAML front matter supplies structured metadata, and Git supplies provenance, history and review.

A normal Markdown link is excellent for humans and agents:

```markdown
Smolt abundance is estimated from [juvenile monitoring](../concepts/juvenile-monitoring.md).
```

But it says only that two things are related; the relationship itself is not formally typed. My preferred pattern is therefore to retain **natural Markdown links** while adding **machine-readable typed relationships** in YAML:

```yaml
id: salmon-smolt-abundance
title: Salmon smolt abundance
type: concept

relations:
  - predicate: skos:related
    object: juvenile-monitoring
  - predicate: sdo:measuredBy
    object: smolt-trap-survey
  - predicate: prov:wasDerivedFrom
    object: camp-juvenile-dataset
```

That gives the bundle the ingredients of a lightweight labelled semantic graph without sacrificing readable Markdown.

## 3. Ontology bindings

A card can bind a local working concept to persistent ontology identifiers:

```yaml
semantic_bindings:
  - iri: https://example.org/salmon-ontology#SmoltAbundance
    predicate: skos:exactMatch
    status: approved
```

The OKF card does not have to _be_ the OWL ontology term. It can remain a rich working object containing definitions, examples, implementation notes, evidence, discussions, links to datasets/code and mappings. The ontology supplies formal identity and axioms where greater rigour is useful.

This separates **knowledge for humans and agents** from **formal symbolic semantics** without disconnecting them.

## 4. Make mappings first-class records

Important mappings should not be hidden as miscellaneous metadata. Treat them as first-class curation objects:

```yaml
id: mapping-000184
type: mapping
subject_id: psc:escapement-estimate
predicate_id: skos:closeMatch
object_id: sdo:SpawnerAbundanceEstimate
mapping_justification: SemanticSimilarityThresholdMatching
confidence: 0.91
status: proposed
creator: agent:semantic-mapper-v2
created: 2026-09-04
reviewer: null
```

The Markdown body can explain rationale, ambiguity, evidence and reviewer discussion.

## 5. SSSOM as the mapping interchange model

**SSSOM (Simple Standard for Sharing Ontological Mappings)** fits this architecture very well. Rather than inventing a private mapping vocabulary, align mapping-card fields with concepts such as:

- `subject_id`
- `predicate_id`
- `object_id`
- `mapping_justification`
- `mapping_tool`
- `confidence`
- provenance and authorship

The combination is powerful:

> **SSSOM provides structured mapping semantics; OKF provides the complete human/agent curation record.**

The build system can export SSSOM-compatible mapping sets independently of the RDF graph.

## 6. Mapping lifecycle

Use an explicit lifecycle:

```text
unmapped
   |
agent candidate
   |
proposed
   +------> rejected
   +------> needs ontology work
   +------> needs domain review
   +------> approved
                 |
              published
```

Keep rejected mappings. A rejected mapping records that a plausible correspondence was considered and explains why it was rejected, preventing agents and humans from repeatedly rediscovering the same bad mapping.

## 7. Agentic semantic-gap detection

This is one of the strongest uses of the system. An agent can continuously inspect the bundle for:

- concepts without ontology mappings;
- weak mappings where better terms may exist;
- stale or unresolved IRIs;
- apparently synonymous local concepts lacking explicit relations;
- local concepts absent from target ontologies;
- mappings that conflict with ontology axioms;
- concepts lacking enough definition/evidence to map confidently.

For each unmapped concept, the agent searches approved ontology/vocabulary sources, proposes candidate terms and predicates, records evidence and confidence, and opens a reviewable mapping proposal. If no adequate term exists, it creates a semantic-gap record and can recommend an extension to the Salmon Domain Ontology.

The agent proposes; it does not silently establish semantic truth.

## 8. Gap cards

Important missing semantics can themselves become knowledge objects:

```yaml
id: semantic-gap-0042
type: semantic-gap
concept: terminal-run-reconstruction
status: open
searched_resources:
  - Salmon Domain Ontology
  - AGROVOC
  - NERC Vocabulary Server
reason: >
  No term found that distinguishes reconstructed terminal run abundance
  from observed spawning escapement.
recommended_action: ontology_extension
```

This turns ontology development into a **continuous knowledge-engineering feedback loop** rather than an occasional standalone exercise.

## 9. Where Graphify fits

Once OKF contains typed relations, **Graphify is optional**. You do not need it merely to obtain a graph.

Its useful role is automated discovery across code, documentation and implementation artifacts: imports, calls, dataset dependencies, schema references, concept mentions, probable correspondences, and other relationships nobody has curated yet.

```text
code/docs/artifacts
       |
       v
generated Graphify graph
       |
 candidate relationships
       v
agent + human review
       |
accepted high-value relationships
       v
curated OKF
```

The distinction is:

> **Graphify can suggest what might be connected. OKF records what we believe the connection means.**

Generated implementation edges can remain a disposable derived graph rather than polluting the curated semantic layer.

## 10. Compile OKF to RDF

A deterministic build process converts approved structured relationships into RDF. For example:

```yaml
subject: salmon:EscapementEstimate
predicate: skos:closeMatch
object: sdo:SpawnerAbundanceEstimate
status: approved
```

can become:

```turtle
salmon:EscapementEstimate
    skos:closeMatch sdo:SpawnerAbundanceEstimate .
```

The compiler can emit Turtle, JSON-LD or another RDF serialization and include provenance/mapping metadata.

**Do not maintain the RDF graph manually as a second source of truth.** Rebuild it reproducibly from OKF.

## 11. Fuseki / triplestore layer

Apache Jena Fuseki is a sensible formal backend because it provides persistent RDF storage, SPARQL, named graphs and standards-based integration with RDF/OWL tooling.

Possible named graphs include:

```text
/graph/ontology
/graph/approved-knowledge
/graph/approved-mappings
/graph/provenance
```

A separate staging store or staging named graph can hold proposed material, although keeping unapproved assertions out of the production store entirely is cleaner where confidentiality or authority matters.

### Publish as authoritative

- approved concept identities;
- approved ontology bindings;
- approved SSSOM mappings;
- validated typed relationships;
- required provenance.

### Do not automatically publish as authoritative

- raw agent suggestions;
- low-confidence inferred edges;
- rejected mappings;
- unresolved gaps;
- unreviewed Graphify edges.

Those remain valuable in OKF as knowledge about the curation process.

## 12. SHACL as the publication quality gate

SHACL can enforce requirements such as subject/object IRIs, allowed mapping predicates, provenance, justification, status, and a reviewer for approved assertions.

```text
OKF
 |
parse
 |
schema validation
 |
compile RDF
 |
SHACL validation
 +---- fail --> PR/build report
 |
 pass
 |
publish to Fuseki
```

This lets authoring remain approachable while the published semantic graph remains rigorous.

## 13. What OWL/formal reasoning adds

DuckDB, JSON and property graphs can store explicit edges perfectly well. RDF/OWL becomes valuable when **implicit knowledge must become queryable**.

Examples include subclass relationships, equivalent classes, inverse/transitive properties, domain/range, disjointness, restrictions and inference.

If the graph says:

```text
Lower Fraser Chinook escapement
    is-a salmon escapement
salmon escapement
    is-a population abundance observation
```

then a semantic query for population-abundance information can discover Lower Fraser Chinook escapement even if the exact phrase never appears in its card or dataset metadata.

> **An ordinary graph retrieves relationships you explicitly store. A formally modelled semantic graph can also retrieve relationships implied by the model.**

## 14. Agents do not eliminate SPARQL

They largely change **who writes it**.

A scientist asks:

> Find every dataset containing abundance information for Fraser Chinook, including datasets mapped to narrower concepts in external vocabularies, and explain why each qualifies.

The agent can inspect the ontology, generate SPARQL, execute it, follow graph paths, retrieve supporting OKF cards, and return a cited explanation.

SPARQL therefore becomes infrastructure behind the natural-language interface rather than something every user must know.

## 15. Why context windows do not replace databases

Direct Markdown traversal is excellent at small scale, but eventually you encounter millions of documents/edges, repeated parsing costs, context limits, expensive multi-hop traversal, concurrency, exact filtering/aggregation, permissions and reproducibility requirements.

The scalable pattern is:

```text
Markdown = authoring representation
RDF/graph index = query representation
LLM context = temporary working set
```

The agent should retrieve the **small relevant subgraph** rather than ingest the whole knowledge base.

## 16. Federation and confidentiality routing

Do not create one giant universal OKF bundle. Maintain bundles according to natural project/governance boundaries, for example:

```text
personal/
psc-private/
ctc-chinook/
salmon-domain-ontology/
salmon-knowledge-commons/
metasalmon/
public-research/
```

Give each bundle policy metadata such as visibility, allowed readers/writers, export policy and allowed downstream destinations.

A policy-aware agent/router determines which bundles may participate in a task. This supports private knowledge reading public knowledge while preventing private assertions from leaking into public outputs.

### One-way knowledge flow

```text
PUBLIC -----------------------> PRIVATE
   ^                              |
   |                              |
   +---- reviewed promotion <-----+
```

Private projects may consume public knowledge freely. Movement from private to public requires an explicit review/promotion operation.

This is safer than relying on prompting alone to keep confidential material out of responses.

## 17. User experience

Most users should never interact directly with Fuseki or SPARQL.

### Human editing surface

GitHub/GitLab + Markdown:

- edit concept cards;
- review agent PRs;
- approve/reject mappings;
- discuss ontology gaps;
- version releases.

### Semantic review surface

A lightweight dashboard could show unmapped concepts, proposed mappings, confidence/evidence, rejected mappings, ontology gaps, SHACL failures and graph neighbourhoods.

The main actions could simply be **Approve**, **Reject**, **Needs work**, and **Create ontology issue**.

### Agent surface

Natural-language tasks such as:

- “What do we mean by escapement across these projects?”
- “Find concepts without ontology mappings.”
- “Suggest SSSOM mappings for these 20 cards.”
- “Why was this mapping rejected?”
- “What datasets measure juvenile abundance?”
- “What semantic gaps block integration of CAMP and RAD?”
- “Show the evidence path behind this answer.”

The agent decides whether the best tool is Markdown retrieval, graph traversal, SPARQL, ontology reasoning, Graphify-derived discovery, or a combination.

## 18. Competency questions as architectural tests

Before adding ontology complexity, write down questions the system must answer. For a salmon science/data system these might include:

1.  Which datasets contain observations relevant to Chinook abundance?
2.  Which local PSC concepts map to the same external ecological concept?
3.  Which datasets use measurements that are narrower forms of escapement estimation?
4.  What concepts cannot currently be mapped to the Salmon Domain Ontology?
5.  What evidence supports a particular mapping?
6.  Which mapping decisions changed between releases?
7.  Which public concepts can safely be imported into a confidential project?

Turn these into automated tests. Ontology sophistication is then justified by demonstrated query needs rather than by a desire to model everything formally.

## 19. Information hierarchy

### Layer 1 — Markdown prose

Human explanation, scientific reasoning, examples, context, decisions and evidence narrative.

### Layer 2 — YAML metadata

Stable IDs, card types, status, typed relations, ontology IRIs, provenance and access/publishing policy.

### Layer 3 — SSSOM mappings

Explicit semantic correspondences, mapping predicates, justification, confidence and review state.

### Layer 4 — Generated discovery graph

Graphify or equivalent high-volume inferred/extracted relationships. Useful but non-authoritative.

### Layer 5 — RDF/OWL graph

Approved machine-readable assertions and formal ontology semantics.

### Layer 6 — Query/reasoning services

SPARQL, SHACL, inference and graph APIs.

### Layer 7 — Agent interface

Natural-language planning, retrieval, graph querying, evidence synthesis, gap discovery and proposed changes.

The information does not necessarily become “more detailed” as it moves downward. It becomes **more explicit, normalized and computationally enforceable**.

## 20. Suggested implementation sequence

### Phase 1 — Define the OKF profile

Create a deliberately small profile covering card types, stable IDs, prefixes, typed relation syntax, ontology-binding syntax, mapping status and provenance.

### Phase 2 — SSSOM-compatible mapping cards

Implement proposed/approved/rejected mappings and retain mapping evidence and review history.

### Phase 3 — Semantic-curation agent

Have an agent identify unmapped concepts, search approved vocabularies, propose mappings, identify ontology gaps and create reviewable changes through Git.

### Phase 4 — RDF compiler

Build a deterministic OKF -\> RDF/JSON-LD/Turtle pipeline and test identifiers and provenance.

### Phase 5 — SHACL

Validate the RDF before publication.

### Phase 6 — Fuseki

Load only approved semantic assertions into the authoritative graph and expose SPARQL to agent tools rather than requiring users to query it directly.

### Phase 7 — Competency-question tests

Turn important scientific/data-integration questions into regression tests against the graph.

### Phase 8 — Optional Graphify integration

Add Graphify only where automated discovery over code/docs provides value. Keep generated edges explicitly separate from curated assertions and let agents propose promotion into OKF.

### Phase 9 — Federation/policy router

Introduce multiple OKF bundles with explicit visibility and read/write/export policies. Enforce confidentiality at retrieval/tool boundaries, not merely in prompts.

## 21. Overall pattern

```text
People + agents
      |
      v
OKF / Markdown / Git  <-----------------------+
(canonical working knowledge)                 |
      |                                       |
      +--> typed edges                        |
      +--> SSSOM mappings                     |
      +--> ontology IRIs                      |
      |                                       |
      v                                       |
human review / approval                       |
      |                                       |
      v                                       |
deterministic RDF build                       |
      |                                       |
      v                                       |
SHACL validation                              |
      |                                       |
      v                                       |
Fuseki / RDF / OWL                            |
      |                                       |
      v                                       |
SPARQL + reasoning ---> agent tools ----------+
                          |
                          +--> answers + evidence
                          +--> semantic-gap detection
                          +--> proposed OKF changes

Graphify (optional):
code/docs -> generated graph -> candidate edges -> review -> OKF
```

## 22. Design principle

The architecture avoids choosing between the new Markdown/agent paradigm and traditional Semantic Web infrastructure.

Use each where it is strongest:

- **Markdown** for thinking and communication.
- **Git** for collaboration and governance.
- **OKF** for portable structured project knowledge.
- **SSSOM** for mapping interchange and provenance.
- **Graphify** for optional automated relationship discovery.
- **RDF** for normalized semantic representation.
- **OWL** for formal domain meaning and inference.
- **SHACL** for enforceable graph quality.
- **Fuseki** for scalable semantic storage/query.
- **SPARQL** for precise graph computation.
- **Agents** for orchestration, natural-language interaction, retrieval, synthesis and semantic curation.

The resulting system is best thought of as an **agentic semantic knowledge compiler**:

> Human- and agent-readable knowledge is authored in OKF, semantic claims are reviewed, approved knowledge is compiled into formal machine-readable representations, and agents move fluidly between those representations according to the task.

That preserves the simplicity that makes OKF attractive without giving up the semantic rigour, interoperability and scalable querying that become important as the Salmon Knowledge Commons and related systems grow.
