---
type: Artifact
title: "Taxonomic assignment in the salmon ontologies — evidence briefing"
description: "Evidence briefing for a ruling on how taxonomic assignment should be modelled across smn (salmon-domain-ontology) and gcdfo (dfo-salmon-ontology): what the two ontologies assert today, what Darwin Core and its ratified Conceptual Model, ENVO/NCBITaxon, OBOE, BODC and ICES converge on, seven candidate patterns compared, a recommendation, and the effect on hub Q-06 decisions 1, 2, 4 and 8, queue item B-108, and the separability of the taxonomy question. Written 2026-09-14; a briefing awaiting Brett's ruling, operative in nothing."
status: draft
tags: [ontology, taxonomy, briefing, evidence, s9, q-06, b-108]
psc:
  id: metasalmon:plan:2026-09-14-taxonomic-assignment-briefing
  contexts: [metasalmon:context:hub-coordination]
---

# How taxonomic assignment should be modelled in the salmon ontologies

**This is a briefing, not a card that claims verification.** Every claim that
rests on a source carries the source, and every identifier asserted below was
resolved during the pass with its HTTP status recorded in the
[source register](#8-source-register). Claims that could not be checked are marked
**not verified** in place. Nothing here asserts independent review.

**What this is and what it is not.** Prepared by an agent on 2026-09-14 for
Brett to rule on the taxonomy half of hub question **Q-06**: the modelling
pattern itself, plus Q-06 decisions 1 and 2, which [§7](#7-separability-from-the-rest-of-q-06)
argues are the same question asked from two sides. The effect on decisions 4
and 8 and on queue item **B-108** is assessed in
[§6](#6-refactoring-assessment). The decision is Brett's and nothing here is
operative until he makes it. The owning stream is
[S9 — ontology conventions and alignment pass](../sequences/s9-ontology-alignment.md);
the review that re-posed Q-06 as a possible split ruling — rule decision 1 now
because B-108 hangs on it, rule the rest after the source amendments — is
§4.2 of the [queue promotion review of 2026-09-12](2026-09-12-queue-promotion-review.md),
and this briefing is the evidence that ruling would rest on.

---

## 1. The modelling problem, in one paragraph

Salmon data arriving from DFO carries species as an administrative code on a
group — `SEL` on a Conservation Unit, `Sockeye` in a Wild Salmon Policy output
column — never as a taxonomic determination of an individual fish, and Brett has
already ruled that life-history assertion happens "at Conservation Unit,
population, or stock level, never for an individual fish" (2026-08-17, quoted in
the `smn:LifeHistoryTypeScheme` scope note on the PR #27 branch). The two
ontologies currently answer "which species is this about?" in three mutually
inconsistent ways at once: gcdfo carries a `gcdfo:Species` SKOS concept that is
a *column name*, whose scope note asks consumers to "use taxonomic IRIs (for
example DwC/GBIF/ITIS) where available" while admitting the approved outputs
hold common-name strings; smn's shared observation module carries two object
properties whose `rdfs:range` is a single NCBI taxon class, plus an
smn-namespace "proxy class" mirroring one species; and PR #27 attaches
`dwc:scientificName` and a WoRMS `dwc:scientificNameID` as bare literals to SKOS
concepts that are life-history types rather than taxa. The question Brett asked
is whether the established standards say any of that is the right shape. They
do not agree with any of the three, they *do* agree with each other, and the
pattern they converge on is cheap to adopt because both repositories already
declare most of the terms it needs.

---

## 2. What the two ontologies assert today (measured 2026-09-14)

### 2.1 smn — `ontology/modules/02-observation-measurement.ttl`, `main`

Retrieved over HTTPS from the repository's `main` branch (HTTP 200, 14 948
bytes). Verbatim, lines 200–208 and 256–267:

```turtle
# MIREOT-style mirror of the upstream NCBITaxon hierarchy (Oncorhynchus
# keta under Salmonidae); byte-faithful to the source, not an smn claim.
obo:NCBITaxon_8018 rdfs:subClassOf obo:NCBITaxon_8015 .

smn:NCBITaxon_8018 a owl:Class ;
  rdfs:label "Oncorhynchus keta proxy class"@en ;
  rdfs:subClassOf obo:NCBITaxon_8018 ;
  rdfs:isDefinedBy <https://w3id.org/smn> .

smn:observedTaxonFamily a owl:ObjectProperty ;
  rdfs:label "observed taxon family"@en ;
  rdfs:domain sosa:Observation ;
  rdfs:range obo:NCBITaxon_8015 ;
  rdfs:isDefinedBy <https://w3id.org/smn> .

smn:observedTaxonSpecies a owl:ObjectProperty ;
  rdfs:label "observed taxon species"@en ;
  rdfs:domain sosa:Observation ;
  rdfs:range obo:NCBITaxon_8018 ;
  rdfs:isDefinedBy <https://w3id.org/smn> .
```

Three separable defects live in that block, and B-108 as filed names only the
first. They are analysed in [§6.5](#65-b-108).

### 2.2 smn — PR #27 branch `feat/spsr-shared-life-history-schemes`

Retrieved from `ontology/modules/07-controlled-vocabularies.ttl` on that branch
(HTTP 200, 67 032 bytes). Each of the three sockeye life-history concepts
carries, verbatim:

```turtle
  dwc:scientificName "Oncorhynchus nerka" ;
  dwc:scientificNameID "urn:lsid:marinespecies.org:taxname:254569" ;
  rdfs:seeAlso <https://www.marinespecies.org/aphia.php?p=taxdetails&id=254569> ;
```

The module header states the policy: *"Species is carried as a
`dwc:scientificName` literal plus a WoRMS `dwc:scientificNameID`, never as an
`smn:` concept or class (Brett Johnson, 2026-08-24)."* The scheme scope note
adds that *"no `smn:` species concept or class exists to point at."*

**The identifier is correct.** AphiaID 254569 resolves to *Oncorhynchus nerka*
(Walbaum, 1792), `status: accepted`, `valid_AphiaID: 254569`, `rank: Species`,
and WoRMS itself reports the LSID as `urn:lsid:marinespecies.org:taxname:254569`
(HTTP 200). The PR did not guess.

### 2.3 gcdfo — checked-out working copy

- **No `dwc:scientificName` assertion exists anywhere in gcdfo.** Zero matches
  for `scientificName`, `NCBITaxon`, `WoRMS`, `aphia`, `taxonID` or
  `taxonConcept` across `ontology/`, `mappings/` and `draft/` (`*.ttl`, `*.md`,
  `*.csv`, `*.tsv`, `*.owl`), excluding the frozen `docs/releases/` snapshots.
  So the shape decision 1 poses as the test of the boundary ruling **does not
  exist in gcdfo yet**; it is hypothetical.
- `gcdfo:Species` (`ontology/dfo-salmon.ttl:2380`) is a `skos:Concept` in
  `gcdfo:WSPOutputVariableScheme`, defined "Species identity field used in
  canonical WSP outputs", with the scope note: *"Use taxonomic IRIs (for example
  DwC/GBIF/ITIS) where available; canonical approved outputs currently use
  common-name strings such as Chinook, Sockeye, Coho, Chum, and Pink."* It is a
  column, not a taxon.
- `mappings/gcdfo-to-smn.sssom.tsv` (49 lines) contains **no** species or taxon
  row.
- gcdfo already declares the scaffolding the recommendation needs:
  `dwc:Identification a owl:Class` with definition *"A taxonomic determination
  (e.g., the assignment to a `dwc:Taxon`)"* (`ontology/dfo-salmon.ttl:345-348`),
  `dwc:Organism a owl:Class` (`:316`), and **`smn:Deme` / `smn:Population`**
  both `rdfs:subClassOf dwc:Organism` (`:1798`, `:1806`). The `dwc:` and
  `dwciri:` prefixes are bound (`:15`, `:16`); `dwciri:` is never used as a
  predicate.
  *(Namespace corrected on 2026-09-14 when this card landed in the bundle: the
  draft read `gcdfo:Deme` / `gcdfo:Population`, and gcdfo's file declares no
  such classes. Re-read at merge commit `26d7c38`, the two classes are
  `smn:Deme` (`:1795`) and `smn:Population` (`:1802`), each carrying
  `rdfs:isDefinedBy <https://w3id.org/smn>` and declared inside gcdfo's own
  `ontology/dfo-salmon.ttl`, `smn:Population` with a `rdfs:comment` DFO profile
  note saying gcdfo applies it in Wild Salmon Policy / Conservation Unit
  contexts. The cited line numbers were right; the prefix was not. The
  correction strengthens rather than weakens the argument it feeds — gcdfo is
  already reusing shared `smn:` classes with a Darwin Core parent — but
  [§7](#7-separability-from-the-rest-of-q-06) carries the one inference that
  rested on the wrong prefix, now hedged there.)*
- gcdfo's own conventions already list `dwc:Taxon` as the class for
  "*Oncorhynchus nerka*" in its Darwin Core class table
  (`docs/CONVENTIONS.md:979`).

---

## 3. What the established standards say

### 3.1 Darwin Core — names, identifiers and the literal/IRI split

Definitions below are quoted from the machine-readable term record
`vocabulary/term_versions.csv` in the `tdwg/dwc` repository (HTTP 200, 961 934
bytes), filtered to `status = recommended`. The human-readable list is version
**2026-05-26**.

| Term | IRI | Issued | Definition (verbatim) |
|---|---|---|---|
| `dwc:scientificName` | `http://rs.tdwg.org/dwc/terms/scientificName` | 2026-05-26 | "The full scientific name, with authorship and date information if known. When forming part of a `dwc:Identification`, this should be the name in lowest level taxonomic rank that can be determined." |
| `dwc:taxonID` | `.../taxonID` | 2026-05-26 | "An identifier for a `dwc:Taxon`." Examples include `https://www.gbif.org/species/212` |
| `dwc:scientificNameID` | `.../scientificNameID` | 2017-10-06 | "An identifier for the nomenclatural (not taxonomic) details of a scientific name." Example: `urn:lsid:ipni.org:names:37829-1:1.3` |
| `dwc:taxonConceptID` | `.../taxonConceptID` | 2023-06-28 | "An identifier for the taxonomic concept to which the record refers - not for the nomenclatural details of a `dwc:Taxon`." |
| `dwc:acceptedNameUsageID` | `.../acceptedNameUsageID` | 2023-06-28 | "An identifier for the name usage (documented meaning of the name according to a source) of the currently valid (zoological) or accepted (botanical) taxon." Examples: `tsn:41107` (ITIS), `2704179` (GBIF), `6W3C4` (COL) |
| `dwc:taxonRank` | `.../taxonRank` | 2026-05-26 | "The taxonomic rank of the most specific name in the `dwc:scientificName`." |
| `dwc:vernacularName` | `.../vernacularName` | 2026-05-26 | "A common or vernacular name." Examples include `rainbow trout` |
| `dwc:Taxon` | `.../Taxon` | 2023-09-18 | "A group of organisms (sensu `http://purl.obolibrary.org/obo/OBI_0100026`) considered by taxonomists to form a homogeneous unit." |
| `dwc:Identification` | `.../Identification` | 2026-05-26 | "A classification of a resource according to a classification scheme." |
| `dwc:Organism` | `.../Organism` | 2026-05-26 | "A particular organism or **defined group of organisms** considered to be taxonomically homogeneous." |
| `dwc:organismScope` | `.../organismScope` | 2023-06-28 | "A description of the kind of `dwc:Organism` instance. Can be used to indicate whether the `dwc:Organism` instance represents a discrete organism or if it represents a particular type of aggregation." |
| `dwciri:toTaxon` | `http://rs.tdwg.org/dwc/iri/toTaxon` | 2015-03-27 | "Use to link a `dwc:Identification` instance subject to a taxonomic entity such as a taxon, taxon concept, or taxon name use." |

Three facts from that table matter more than the rest.

**(a) Which field carries an authority is settled per-authority, not in the
abstract.** `scientificNameID` is for *nomenclature*; `taxonID` is for a taxon;
`taxonConceptID` is for a concept; `acceptedNameUsageID` is for a name usage.
Its examples show which registries TDWG expects in which slot: an IPNI *name*
LSID for `scientificNameID`, an ITIS TSN / GBIF key / COL id for
`acceptedNameUsageID`, a GBIF species URL for `taxonID`.

**(b) Darwin Core declares no domains or ranges at all.** The Darwin Core RDF
Guide (ratified 2021-07-15, version IRI
`http://rs.tdwg.org/dwc/terms/guides/rdf/2021-07-15`) states: *"No terms defined
within the Darwin Core namespace have range or domain declarations."* This is
why PR #27's `dwc:scientificName` on a SKOS life-history concept is not *broken*
in the reasoner sense — and also why nothing will ever tell you it is wrong.

**(c) The `dwciri:` set exists for exactly the job smn is doing badly.** The RDF
Guide's rationale: *"it would be advantageous to provide an alternative set of
DwC terms intended for use in RDF with IRI-referenced objects, while continuing
to use the general DwC terms for literal objects."* `dwc:` takes literals;
`dwciri:` takes IRIs; a `dwciri:` term *"is defined to have the same meaning as
its `dwc:` namespace term analogue."* The guide's worked Example 22 uses
`dwciri:toTaxon` "to relate the `dwc:Identification` instance to a taxon
instance."

### 3.2 The Darwin Core Conceptual Model — the ratified answer to "what is the subject?"

The **Darwin Core Conceptual Model was ratified 2026-05-26**, version IRI
`http://rs.tdwg.org/dwc/doc/cm/2026-05-26`, published at `https://dwc.tdwg.org/cm/`
alongside the Data Package Guide at `https://dwc.tdwg.org/dp/`. TDWG's
announcement: *"The Conceptual Model provides the semantics of the relationships
between Darwin Core classes, a critical piece that has been missing from the
standard since its inception."*

Its §2.5 states that an *"Identification expresses an opinion by an Agent (human
or otherwise) that an Organism or other Material Entity (whether observed or
inferred) was a member of a class within a classification scheme"*, and for
organisms specifically *"A taxonomic determination (i.e., the assignment of a
`dwc:Taxon` to a `dwc:Organism`)."* It permits collapsing the node where
appropriate: *"Depending on the intended context of Identification and Taxon
data, it may simplify data sharing models to subsume Taxon information within
Identifications."*

So the ratified answer to Brett's pattern question is: **Organism →
Identification → Taxon**, with the assertion reified as an opinion rather than
stated as a type, and the Taxon carrying the authority identifiers. The Model
does not itself discuss names versus concepts or name specific registries.

### 3.3 Taxon name versus taxon concept

The distinction is old, live, and the reason a bare name string is not an
identifier.

- **Berendsohn 1995**, "The concept of 'potential taxa' in databases", *TAXON*
  44:207–212, DOI `10.2307/1222443` (CrossRef, HTTP 200), introduced the
  potential taxon: a name individuated by the publication that circumscribed it.
- **Franz & Peet 2009**, "Perspectives: Towards a language for mapping
  relationships among taxonomic concepts", *Systematics and Biodiversity*
  7(1):5–20, DOI `10.1017/S147720000800282X` (CrossRef, HTTP 200), gives the
  articulation language for comparing concepts across independently published
  hierarchies. The framing that matters here: taxonomic names are imperfect
  identifiers of meanings that change across revisions, and the "name *sec.*
  reference" convention restores the missing context.
- **TCS** (Taxon Concept Schema) was ratified 2005-09-16 as an XML standard,
  permanent IRI `http://www.tdwg.org/standards/117`. **TCS 2** went to public
  review **2025-04-04**: *"a vocabulary standard, expressed in RDF rather than
  XML schema, and covers terms for both taxonomic concepts and taxonomic
  nomenclature"*, term list at
  `https://github.com/tdwg/tcs2/blob/master/docs/tcs-terms`. **Whether TCS 2 has
  since been ratified is not verified** — the announcement page records only the
  review opening.
- TDWG's own draft **"Describing Taxon Concepts as RDF"** (Steve Baskauf, RDF/OWL
  Task Group, created 2013-04-27, last modified 2014-11-13; a Type 3 document,
  **not a ratified standard**) says the quiet part: *"The class `dwc:Taxon` is
  defined to be a category that includes information about both names and taxon
  concepts. The ambiguity in this definition reflects a general lack of
  clarity"*. Its recommendation is to model taxon concepts as **individuals**,
  not classes, and to link records with an object property rather than
  `rdf:type`.

**Consequence for the salmon case, stated plainly:** no registry in scope mints
concept identifiers of the `sec.`-reference kind. NCBI, WoRMS, GBIF, ITIS and COL
all publish *taxon records* and *name records*. So `dwc:taxonConceptID` is not
populatable from any authority the salmon ecosystem uses, and the strongest
available assertion is a name-or-taxon identifier from a named authority plus
the authority's version. Claiming more than that would be fiction.

### 3.4 The authority registries, resolved

All five Pacific salmon plus *O. mykiss*, *Oncorhynchus* and Salmonidae, resolved
during this pass. Every row is a live lookup, not a recollection.

| Taxon | NCBI taxid (HTTP 200 via E-utilities) | OBO IRI | WoRMS AphiaID (HTTP 200) | WoRMS LSID | GBIF usageKey (HTTP 200, EXACT/ACCEPTED) | ITIS TSN (HTTP 200) | COL id (HTTP 200) |
|---|---|---|---|---|---|---|---|
| *Oncorhynchus nerka* (sockeye) | 8023, rank species | `http://purl.obolibrary.org/obo/NCBITaxon_8023` | 254569 | `urn:lsid:marinespecies.org:taxname:254569` | 5204039 | 161979 | 49JFH |
| *Oncorhynchus kisutch* (coho) | 8019, rank species | `.../NCBITaxon_8019` | 127184 | `urn:lsid:marinespecies.org:taxname:127184` | 5204034 | 161977 | 49JF8 |
| *Oncorhynchus tshawytscha* (chinook) | 74940, rank species | `.../NCBITaxon_74940` | 158075 | `urn:lsid:marinespecies.org:taxname:158075` | 5204024 | 161980 | 49JFR |
| *Oncorhynchus keta* (chum) | 8018, rank species | `.../NCBITaxon_8018` | 127183 | `urn:lsid:marinespecies.org:taxname:127183` | 5204014 | 161976 | 49JF6 |
| *Oncorhynchus gorbuscha* (pink) | 8017, rank species | `.../NCBITaxon_8017` | 127182 | `urn:lsid:marinespecies.org:taxname:127182` | 5204037 | 161975 | 74N5S |
| *Oncorhynchus mykiss* | 8022, rank species | `.../NCBITaxon_8022` | 127185 | `urn:lsid:marinespecies.org:taxname:127185` | not queried | 161989 | not queried |
| *Oncorhynchus* (genus) | 8016, rank genus | `.../NCBITaxon_8016` | — | — | — | — | — |
| Salmonidae (family) | 8015, rank family | `.../NCBITaxon_8015` | 125587 (rank Family) | `urn:lsid:marinespecies.org:taxname:125587` | — | — | — |

LSIDs other than sockeye's and Salmonidae's are constructed from the resolved
AphiaID by the documented pattern; only 254569's LSID was read back from the
WoRMS record field itself.

Two findings from this table bear directly on the decisions.

**The OBO PURLs resolve, but not to an ontology page.** `http://purl.obolibrary.org/obo/NCBITaxon_8015`,
`_8018` and `_8023` each redirect (HTTP 200 final) to
`https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=<taxid>`. The OWL
term record is reachable through OLS4 instead, which returns for
`NCBITaxon_8023`: `label: "Oncorhynchus nerka"`, synonyms `"Salmo nerka"` and
`"sockeye salmon"`, `has_rank → TAXRANK_0000006`, `is_defining_ontology: true`.

**Steelhead is representable, and the S9 card understates how.** S9 records that
steelhead "has no taxonomic identifier in ITIS, WoRMS, NCBI, GBIF or Catalogue
of Life — it is a vernacular for anadromous *O. mykiss* in all five." That is
right about the taxon and incomplete about the record: ITIS returns `steelhead`
as an English **common name attached to TSN 161989** (*O. mykiss*), and WoRMS
returns `Steelhead` and `steelhead trout` among the English vernaculars of
AphiaID 127185 — both HTTP 200. ITIS also carries *Oncorhynchus mykiss
gairdnerii* as TSN 553418, a subspecies. So steelhead is not a hole in the
authorities; it is a `dwc:vernacularName` on a species record, which is a slot
Darwin Core already defines and whose example list literally includes `rainbow
trout`. The part the salmon data cares about — anadromy — is a life-history
axis, which is precisely what PR #27 built. **Steelhead is an argument for
separating taxon reference from life history, not against taxon reference.**

### 3.5 How ENVO does it — the example Brett named

ENVO is registered at OBO Foundry with PURL
`http://purl.obolibrary.org/obo/envo.owl`, domain "environment", and **ncbitaxon
among its eight declared dependencies** (chebi, foodon, go, ncbitaxon, pco, po,
ro, uberon).

Its practice, read from the repository rather than inferred:

1. **A declared seed list.** `src/envo/imports/ncbitaxon_terms.txt` (HTTP 200) is
   a hand-curated list of canonical OBO IRIs with human comments, e.g.
   `http://purl.obolibrary.org/obo/NCBITaxon_6548 # Mytilus`,
   `http://purl.obolibrary.org/obo/NCBITaxon_2836 # Bacillariophyta (diatoms)`.
2. **A generated extract module.** `src/envo/imports/ncbitaxon_import.owl`
   (HTTP 200, 79 082 bytes) holds **578 `NCBITaxon_` references** and **zero
   `ENVO_` classes**. Sample entry, verbatim:
   ```xml
   <owl:Class rdf:about="http://purl.obolibrary.org/obo/NCBITaxon_6548">
       <rdfs:subClassOf rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_301959"/>
       <rdfs:label>Mytilus</rdfs:label>
   </owl:Class>
   ```
   Canonical IRI, upstream parent, label. Nothing minted.
3. **Generated by `robot extract`, from the official slim.** ENVO's
   `src/envo/Makefile` (HTTP 200) lists `ncbitaxon` among `IMPORTS` and builds
   each module with `$(ROBOT) extract -i $< -T imports/$*_combined_seed.tsv -m BOT`,
   mirroring from `http://purl.obolibrary.org/obo/ncbitaxon/subsets/taxslim.owl`.
4. **Taxa appear only inside class expressions with RO object properties, never
   as a bare range pin.** From `src/envo/envo-edit.owl` (HTTP 200, 6 029 640
   bytes; 63 `NCBITaxon_` occurrences), each one sits inside a
   `SubClassOf`/`EquivalentClasses` axiom with an RO property. Resolved RO labels
   (OLS4, HTTP 200): `RO_0002507` *determined by*, `RO_0002473` *composed
   primarily of*, `RO_0000057` *has participant*, `RO_0002303` *has habitat*,
   `RO_0002608` *process has causal agent*, `RO_0001015` *location of*,
   `RO_0002233` *has input*. Example, verbatim:
   ```
   EquivalentClasses(<.../ENVO_01001001>
     ObjectIntersectionOf(<.../ENVO_01000254>
       ObjectSomeValuesFrom(<.../RO_0002507> <.../NCBITaxon_33090>)))
   ```

**ENVO's policy, as revealed by its build rather than by a policy document:**
reference upstream taxa at their canonical IRIs, never mint a local proxy, pull
them in through a reproducible extract keyed to a reviewed seed list, and relate
them with a named relation rather than by pinning a property's range. The ENVO
2016 paper (Buttigieg, Pafilis, Lewis, Schildhauer, Walls & Mungall, *Journal of
Biomedical Semantics* 7:57, DOI `10.1186/s13326-016-0097-6`) records the mapping
practice on the data side — habitat data filtered to *"taxa which we could
readily map to a widely-used taxonomy which is integrated with genomic data"*,
via NCBI — but **does not state a taxon-minting policy in prose**; the policy
above is read off the repository, which is why the repository files are cited
rather than the paper.

### 3.6 NCBITaxon's own semantics, and the fact that makes B-108 urgent

OBO Foundry's NCBITaxon entry: PURL `http://purl.obolibrary.org/obo/ncbitaxon.owl`,
CC0 1.0, *"An ontology representation of the NCBI organismal taxonomy"*, and the
load-bearing sentence — **"The conversion treats each taxon as an OWL class
whose instances would typically be individual organisms."** Its stated primary
application is *"defining taxon constraints in multi-species ontologies to detect
inconsistencies"*, the technique formalised by Deegan, Dimmer & Mungall,
"Formalization of taxon-based constraints to detect inconsistencies in annotation
and ontology development", *BMC Bioinformatics* 11:530, DOI
`10.1186/1471-2105-11-530` (CrossRef, HTTP 200).

`ncbitaxon` **taxslim 2026-07-12** was downloaded in full for this pass
(`http://purl.obolibrary.org/obo/ncbitaxon/subsets/taxslim.owl`, HTTP 200,
40 617 427 bytes, `owl:versionIRI` `.../releases/2026-07-12/subsets/taxslim.owl`).
Two measurements from it:

- **All eight salmonid taxa are present.** `NCBITaxon_8015`, `_8016`, `_8017`,
  `_8018`, `_8019`, `_8022`, `_8023` and `_74940` all occur as declared classes.
  So an smn NCBITaxon import module is buildable today with no new terms and no
  proxy.
- **taxslim asserts zero disjointness.** `grep -c "DisjointClasses\|disjointWith"`
  returns **0**. No reasoner will ever flag "this coho is also a chum" as an
  inconsistency. Whatever B-108's range axiom corrupts, it corrupts silently.

The real lineage, read from taxslim: `NCBITaxon_8018` (chum) → `NCBITaxon_8016`
(*Oncorhynchus*, genus) → `NCBITaxon_504568` (Salmoninae, subfamily, exact
synonym "trouts, salmons & chars") → `NCBITaxon_8015` (Salmonidae, family) →
`NCBITaxon_8006`. **The direct triple `8018 rdfs:subClassOf 8015` that smn
asserts does not occur in taxslim**; chum's only asserted parent is the genus.

### 3.7 SOSA/SSN, I-ADOPT, OBOE, and two fisheries vocabularies

- **SOSA/SSN** (W3C Recommendation, 19 October 2017): `sosa:FeatureOfInterest`
  is *"The thing whose property is being estimated or calculated in the course of
  an Observation to arrive at a Result"*; `sosa:hasFeatureOfInterest` is *"A
  relation between an Observation and the entity whose quality was observed"*.
  The spec is silent on whether the observed entity is a class or an individual —
  it says "the thing" and "the entity". So SOSA does not license smn's current
  shape; it simply does not speak to it.
- **I-ADOPT** (version 1.1.0, released 2025-05-28, `https://w3id.org/iadopt/ont/`):
  `iop:Entity` is *"An object or process that has a role in an observation. An
  Entity may play one of the following roles: ObjectOfInterest, ContextObject, or
  Matrix"*; `iop:Constraint` *"limits the scope of the observation and confines
  the context to a particular state."* **I-ADOPT says nothing about taxa** — no
  mention of taxonomic identifiers as object of interest or constraint. So
  "species" is not an I-ADOPT slot; it is whatever the object of interest *is*
  (here: a population of a named taxon), which is consistent with gcdfo already
  writing `gcdfo:iadoptEntity gcdfo:ConservationUnit` on `gcdfo:Species`.
- **OBOE** (`oboe-core.owl`, HTTP 200, 69 407 bytes): an `Observation` is *"an
  assertion that an entity (e.g., biological organisms, geographic locations, or
  environmental features…) was observed"*, and taxon is captured as a
  characteristic of that entity through a `Measurement` — the comment on
  `Measurement` says explicitly *"the name of a location and a taxon can be
  captured through measurements."* OBOE also has an `IdentifyingCharacteristic`
  class for precisely this. **OBOE agrees with DwC-CM and disagrees with
  `rdf:type`-on-observation:** taxon is an asserted characteristic of the
  observed entity, not the type of the observation.
- **BODC / NERC Vocabulary Server**: collection **S25**, "BODC parameter semantic
  model biological entity names", 197 concepts, is the biological-entity axis of
  BODC's compound parameter model. Its concepts carry **both** ITIS and WoRMS
  identifiers — e.g. `http://vocab.nerc.ac.uk/collection/S25/current/BE000005/`
  with `skos:prefLabel` `"Abra (ITIS: 81301: WoRMS 138474)"`. **The pattern is
  authority cross-reference from a local vocabulary concept; the encoding is
  identifiers inside a label string, which is not machine-actionable.** Cite S25
  for the *pattern* and as a warning about the *encoding*.
- **ICES Vocabulary Server** publishes a code type **`SpecWoRMS`** mapping ICES
  species codes to WoRMS AphiaIDs (e.g. `126436` for *Gadus morhua*), plus
  `SpecHelcom`. Same pattern again: an agency code list that points at WoRMS
  rather than redefining taxonomy.

**The convergence is the finding.** Five independent communities — TDWG,
OBO/ENVO, OBOE, BODC, ICES — all put the taxon in an *external authority* and
reach it from local terms by *reference*. None mints local taxa. None uses a
range pin. Three of the five (TDWG, OBOE, and implicitly ENVO's `RO_0002507`
*determined by* usage) reify the assignment as an assertion rather than stating
it as a type.

### 3.8 The OWL-DL consequences, precisely

- **Punning is legal and semantically inert.** OWL 2 New Features and Rationale,
  §2.4.1 "F12: Punning", permits one IRI to be used as both a class name and an
  individual name in OWL 2 DL, and states: *"The OWL 2 Direct Semantics treats
  the different uses of the same name as completely separate, as is required in
  DL reasoners."* OWL 2 Structural Specification §5.8.1 "Typing Constraints of
  OWL 2 DL" forbids only class/datatype collision and mixed property types.
  **So writing `:obs smn:observedTaxonSpecies obo:NCBITaxon_8023` is valid OWL 2
  DL and says nothing whatever about the sockeye class.** The intended meaning is
  not merely under-expressed; it is not expressed.
- **A range axiom is an entailment, not a check.** `rdfs:range C` on property `p`
  means every object of `p` is inferred to be an instance of `C`. It does not
  reject a wrong value; it relabels it. The OWL 2 Structural Specification
  defers semantics to the Direct Semantics document and does not state this in
  those words, so it is cited here as the standard reading of
  `ObjectPropertyRange` rather than as a quotation.
- **`rdfs:range` on a class versus a datatype.** Pinning a range to a taxon
  class commits the property to object values that are organisms (per
  NCBITaxon's own semantics). Pinning it to `xsd:string` commits to literals and
  forfeits linkage. The third option — no range axiom, with the intent recorded
  in the definition and enforced (if at all) by SHACL — is the only one that
  neither corrupts data nor blocks linkage. gcdfo already ships
  `ontology/shapes/dfo-salmon-shapes.ttl`, so the enforcement venue exists.

---

## 4. Comparison of the candidate patterns

Subject `X` below is whatever needs the species: a life-history SKOS concept, a
Conservation Unit, a population, or an observation.

| # | Pattern | What it asserts | Endorsed by | OWL profile consequence | What a consumer can do | Failure mode |
|---|---|---|---|---|---|---|
| **P1** | Bare name literal — `X dwc:scientificName "Oncorhynchus nerka"` | A string is associated with X. Nothing about what X is, or which revision of the name | Darwin Core term (no domain/range); DwC-DP tables carry `scientificName` on Occurrence | None. Annotation-like; safe in OWL 2 DL and in SKOS | String match, and display. No join to any registry without a name-matching service | Homonyms and revisions. The string does not say *sec.* whom, so two datasets using the same string may mean different circumscriptions and nothing detects it (Berendsohn 1995; Franz & Peet 2009). Also, on a non-taxon subject it asserts something false: a life-history concept does not *have* a scientific name |
| **P2** | P1 + name-identifier literal — `+ dwc:scientificNameID "urn:lsid:marinespecies.org:taxname:254569"` **(what PR #27 does)** | A string plus an authority's identifier for the name, as a literal | Darwin Core; the `scientificNameID` example is an IPNI *name* LSID, and WoRMS describes its LSIDs as identifying "each available name in the database", so the slot is defensible | None. Still a literal; no graph edge | Exact join **after** string parsing. Provenance to WoRMS. Cannot be followed by a graph traversal or SPARQL `?x a ?taxon` | The identifier is invisible to RDF: a literal is not a link. No `owl:sameAs`, no federated query, no ancestor closure. And the subject problem of P1 persists |
| **P3** | Identifier as IRI object — `X smn:taxonScope <…aphia.php?id=254569>` (or an `obo:NCBITaxon_8023` IRI as a *reference*, not a type) | X is scoped to the taxon that IRI denotes | `dwciri:` rationale ("intended for use in RDF with IRI-referenced objects"); BODC S25 and ICES `SpecWoRMS` in spirit; ENVO in practice | Safe, **provided no `rdfs:range` pins it to a taxon class**. If the object is an `obo:` class IRI this is punning — legal, inert, and the reason the property must be documented as "a reference to", not "an instance of" | Follow the link. Federate to WoRMS/OBO. Group by taxon | Under-specified without a rank and an authority version: "which WoRMS?" is a real question when AphiaIDs are merged. Mitigated by also carrying `dwc:taxonRank` and the authority release |
| **P4** | Concept identifier — `X dwc:taxonConceptID "…"` | X is scoped to a named circumscription, *sec.* a reference | Darwin Core `taxonConceptID`; TCS 2005 and TCS 2 (public review 2025-04-04); Franz & Peet 2009 | Safe (literal) or safe as IRI | Compare circumscriptions across revisions; the only pattern that survives a taxonomic revision without ambiguity | **Not populatable.** No registry in scope (NCBI, WoRMS, GBIF, ITIS, COL) issues `sec.`-reference concept identifiers for these species. Adopting P4 means minting them, which is a research programme, not a modelling choice |
| **P5** | Taxon class as `rdf:type` of an organism individual — `:fish-1 a obo:NCBITaxon_8023 . :obs-1 sosa:hasFeatureOfInterest :fish-1 .` | There exists an organism that is a sockeye, and the observation is about it | NCBITaxon's own semantics ("each taxon as an OWL class whose instances would typically be individual organisms"); ENVO's axiom style; OBO taxon constraints (Deegan et al. 2010) | Fully DL-clean. Reasoner-usable: ancestor closure via `rdfs:subClassOf`, and taxon constraints become possible | Everything: subsumption queries, "all Salmonidae observations", constraint checking | **The salmon data has no individual fish.** A spawner count is about a CU/population in a year, and Brett has ruled assertion happens at CU/population/stock level, "never for an individual fish" (2026-08-17). P5 alone therefore requires minting fictitious organism individuals, and it provides no slot for the determiner or the authority identifier |
| **P6** | Class-as-value with a pinned range — `smn:observedTaxonSpecies rdfs:range obo:NCBITaxon_8018` **(what smn `main` does)** | Intended: "this observation is of a species". Actual: every value of the property is a chum salmon | Nothing | Legal OWL 2 DL. Punning per §2.4.1 F12 means a class-IRI value carries no class-level meaning; an organism-individual value is **entailed to be *O. keta*** | Nothing safely. Consumers that reason get wrong answers; consumers that do not, get no answers | Silent data corruption. taxslim asserts **zero** disjointness, so no reasoner reports the contradiction. The diff is small, the tests go green, and the damage appears in someone else's federated query |
| **P7** | Identification node — `:pop-1 a dwc:Organism ; dwc:organismScope "population" . :id-1 a dwc:Identification ; dwciri:toTaxon :taxon-nerka ; dwc:identifiedBy … . :taxon-nerka a dwc:Taxon ; dwc:scientificName "Oncorhynchus nerka" ; dwc:taxonID "…254569" ; dwc:taxonRank "species" .` | An agent determined that this defined group of organisms is a member of this taxon, which this authority identifies thus | **Darwin Core Conceptual Model §2.5, ratified 2026-05-26**; `dwciri:toTaxon`; DwC RDF Guide Example 22; OBOE's identifying-characteristic pattern | Fully DL-clean: all individuals, no punning, no range pins. Composes with P5 when individuals exist, and with P3 as a shortcut | Follow to the authority; ask who determined it and when; revise the determination without rewriting the subject; aggregate by taxon | Verbose — three nodes where one triple felt sufficient. The Model itself offers the escape hatch: "it may simplify data sharing models to subsume Taxon information within Identifications" |

---

## 5. Recommendation

**Adopt P7 as the model and P3 as its serialisation shortcut, keep P2's literals
as annotations on a taxon node rather than on subjects that are not taxa, and
delete P6 outright.** Concretely, four moves:

**R1 — Mint one shared taxon-reference property in `smn:`, with no `rdfs:range`.**
One object property (name is Brett's; `smn:taxonScope` reads better than
`smn:appliesToTaxon` for a vocabulary concept, `smn:hasTaxonIdentification` for a
population). Its definition states that the value is a reference to a taxon in a
named external authority; its `rdfs:range` is **absent**, and the reason is
written into the term's comment so the next reader does not "fix" it by adding
one. Enforcement, if wanted, goes in SHACL — gcdfo already ships
`ontology/shapes/dfo-salmon-shapes.ttl`.

**R2 — Mint six `smn:` taxon-reference individuals, not classes.** One per
Pacific salmon species — sockeye, coho, chinook, chum, pink — **plus one for
*O. mykiss*, which makes six and not five**; an earlier draft of this heading
said five while the set named beneath it came to six, and the set the rest of
the card uses is §3.4's table minus its genus and family rows, which R3 supplies
as classes instead. So `smn:TaxonOncorhynchusNerka` and five siblings, each
`a dwc:Taxon`, each carrying `dwc:scientificName`, `dwc:taxonRank "species"`,
`dwc:vernacularName` (which is where **steelhead** lives, on the *O. mykiss*
node, exactly as ITIS and WoRMS already record it), `dwc:taxonID` with the WoRMS
AphiaID, and `dwc:scientificNameID` with the WoRMS LSID if the nomenclatural
reading is intended. Record the authority release each identifier was read
against.

**Link the OBO, GBIF, ITIS and COL IRIs of §3.4 with `rdfs:seeAlso`, or with a
locally minted `smn:` annotation property — never with `skos:exactMatch` or any
other SKOS mapping predicate.** An earlier draft of this paragraph offered
`skos:exactMatch` / `rdfs:seeAlso`, and the SKOS half would have committed the
very error this briefing warns about. Read off the normative SKOS RDF schema
(`https://www.w3.org/2009/08/skos-reference/skos.rdf`, fetched 2026-09-14, HTTP
200, 28 966 B): `skos:exactMatch` is a sub-property of `skos:closeMatch`, which
is a sub-property of `skos:mappingRelation`, which is a sub-property of
`skos:semanticRelation`, and `skos:semanticRelation` is the only one of the four
that carries `rdfs:domain` and `rdfs:range`, both `skos:Concept`. The targets in
§3.4 are `owl:Class` IRIs, so a `skos:exactMatch` to one entails that *both*
endpoints are `skos:Concept` — re-typing an upstream OBO class as an individual
and introducing precisely the class/concept punning R2 exists to avoid. It is
the same defect found in smn's own `alignment-main.ttl`, filed as queue item
`B-147`, so recommending it here would have shipped the error one repository
over. `rdfs:seeAlso` takes `rdfs:Resource` on both sides and imposes nothing; an
`owl:AnnotationProperty` minted for the job — say `smn:taxonAuthorityRecord` —
does the same while being typed and queryable, and is the same remedy the
alignment defect takes. This is also what the
[workshop curriculum and SDO guidance of 2026-09-08](../workshop-curriculum-and-sdo-guidance-2026-09-08.md)
already instructs, at its line 117: *"Do not encourage class/concept cross-role
SKOS mappings."*

**These are not species *concepts* and they are not classes** — they are
reference nodes, and with the linking corrected above they stay inside smn's own
`CONVENTIONS.md` §3 instance-typing rule, whose whole point is that "the IRI is
never both an `owl:Class` and a `skos:Concept`."

**They do, however, reopen Q8, and that goes to Brett with the bundle rather
than being argued away here.** An earlier draft claimed these nodes keep the
recommendation "inside the 2026-08-24 ruling ... rather than reopening it", on
the ground that pointing at an authority is not minting a taxonomy. That is a
real argument and it is not what the ruling says.
[Q8](../questions.md) (2026-08-24) ruled the species half in these words:
*"smn deliberately withdrew its species scheme in PR #27, and species concepts
are never minted in `gcdfo` (Brett, 2026-08-17), so there is **no internal home
to point at and none is being created**."* R2 creates six `smn:` IRIs typed
`dwc:Taxon`. Whether a reference node is an "internal home" is exactly the
question Q8 answered in the negative for the shape it had in view, and whether
that answer reaches this shape is Brett's call and not this card's. So: adopting
the recommendation **amends Q8**; rejecting this part of it leaves Q8 standing
and sends the authority identifiers onto the external IRIs directly, with no
`smn:` node in between, which costs the recommendation its single shared place
to hang a rank and an authority release and is otherwise workable. §6.1 is
corrected to match.

**R3 — Add an ENVO-style generated NCBITaxon import module.** A seed list of the
eight IRIs in §3.6 and a `robot extract -m BOT` step against `taxslim`, mirroring
ENVO's `src/envo/imports/` pattern byte for byte in shape. This gives smn the
canonical classes with their real lineage for the day an individual-organism
dataset arrives (P5), costs one Makefile target, and **deletes the need for
`smn:NCBITaxon_8018` and the hand-written MIREOT triple**. Retirement condition
for the module: it is regenerated on each upstream release, and the seed list is
the reviewed artifact.

**R4 — Use the `dwc:Identification` node where a determiner exists, and the
direct P3 link where one does not.** For a DFO code on a Conservation Unit there
is no determiner of an individual fish, so the honest shape is
`smn:Population` (which gcdfo already declares and applies, already
`rdfs:subClassOf dwc:Organism` — see [§2.3](#23-gcdfo--checked-out-working-copy)) with
`dwc:organismScope` naming the aggregation, linked by R1's property to R2's taxon
node. Where a program *did* make a determination — a genetic stock
identification, a scale reading — wrap it in `dwc:Identification` with
`dwc:identifiedBy`, which is the whole reason DwC-CM reifies it. gcdfo already
declares `dwc:Identification` with the right definition, so this costs no new
class on that side either.

### The alternative a reasonable person would choose, and why not

**Keep PR #27's P2 exactly as it is and change nothing.** It is honest, it names
a real authority, the AphiaID is correct, it commits to no ontology, it is three
lines per concept, and it ships today. This is the strongest alternative and it
came within an inch of being the recommendation.

It is rejected for one reason that survives every argument in its favour: **a
literal is not a link, so P2's identifier cannot be used by the machine it was
written for.** `dwc:scientificNameID "urn:lsid:marinespecies.org:taxname:254569"`
cannot be followed, cannot be `owl:sameAs`-reconciled, cannot be federated, and
cannot answer "give me everything about sockeye" without every consumer writing a
string parser first. The ecosystem's stated purpose is cross-organisation
integration; P2 defers the integration to each consumer, which is how five
consumers end up with five parsers and two of them disagree. The second reason is
smaller but not cosmetic: P2 attaches a *taxonomic* assertion to a subject that
is not a taxon, and because Darwin Core declares no domains, nothing will ever
tell anyone. The one-line fix — move the same three literals onto a taxon node
and point at it — costs one property and six nodes, and it is P7.

A second alternative, **P5 alone** (type an organism with the NCBITaxon class and
be done), is rejected because the data has no individual organisms to type and
Brett has already ruled that assertions sit at CU/population/stock level. R3
keeps P5 available for the day that changes without requiring it now.

---

## 6. Refactoring assessment

### 6.1 Decision 1 — does "species go in `smn`, never `gcdfo`" survive a `gcdfo` vocabulary carrying `dwc:scientificName` + a WoRMS `dwc:scientificNameID`?

**The recommendation changes the shape of the question rather than answering it
as put — and it reopens Q8, which has to be said before anything else in this
section.** An earlier draft of this paragraph read "the standing ruling survives
untouched", which assumed the answer to the question it should have raised.

**The half that reopens.** [Q8](../questions.md) (2026-08-24) ruled that *"there
is no internal home to point at and none is being created"* for species. R2 mints
six `smn:` IRIs typed `dwc:Taxon`. The argument that a reference node is not a
term is a real one and is made in R2; it is not what Q8 says. So adopting the
recommendation **amends Q8**, and this briefing puts that to Brett as part of
the bundle instead of settling it on his behalf.

**The half that holds either way.** The 2026-08-17 ruling forbids *minting*
species terms under `gcdfo:`, and nothing in the recommendation puts a taxon
term in `gcdfo:`. So the gcdfo-facing half of decision 1 is answered whichever
way Q8 goes: a gcdfo code vocabulary that carries a taxon *reference* is not a
species vocabulary and never becomes one. What Q8 decides is only what that
reference points at — an `smn:` node, or the external authority IRI directly.

Two changes follow. First, **the shape does not exist in gcdfo today** — zero
`scientificName` assertions anywhere in `ontology/`, `mappings/` or `draft/` —
so decision 1 is about a hypothetical, and ruling on it now is cheap.
Second, gcdfo should not duplicate the literals in either case. If Q8 is amended,
gcdfo references **R2's smn nodes**: `gcdfo:Species`'s scope note already asks
for exactly this ("Use taxonomic IRIs (for example DwC/GBIF/ITIS) where
available"), and pointing it at a shared node satisfies its own note, keeps one
copy of each AphiaID in the ecosystem, and gives
`mappings/gcdfo-to-smn.sssom.tsv` — which today has no taxon row — its first
one. If Q8 stands, gcdfo references the external authority IRIs directly, which
satisfies the scope note just as well and gives up only the shared place to
record a rank and an authority release.

### 6.2 Decision 2 — is a bare `dwc:scientificName` literal acceptable on a life-history concept?

**The recommendation changes this one materially: keep the literals, move the
subject.**

- The **identifier is right** and should not be touched. AphiaID 254569 verifies.
- The **slot is defensible**. `dwc:scientificNameID` is "an identifier for the
  nomenclatural (not taxonomic) details of a scientific name", its TDWG example
  is an IPNI *name* LSID, and WoRMS describes its own LSIDs as identifying "each
  available name in the database". PR #27 did not pick the wrong field. If the
  intent is the taxon rather than the name, `dwc:taxonID` ("An identifier for a
  `dwc:Taxon`", revised 2026-05-26) is the closer fit; carrying both is normal
  practice and costs nothing.
- The **subject is wrong**. `smn:SockeyeLakeTypeLifeHistory dwc:scientificName
  "Oncorhynchus nerka"` reads "this life-history concept has this scientific
  name", which is false. Because Darwin Core declares no domains, no validator
  will say so, and a consumer harvesting `dwc:scientificName` to build a taxon
  list will silently collect life-history concepts.
- **What replaces it:** the same two literals plus the `rdfs:seeAlso` move onto
  `smn:TaxonOncorhynchusNerka` (R2), and each life-history concept gains one
  triple — R1's property pointing at that node. Net change per concept: three
  literals out, one IRI-valued triple in. The scheme scope note's sentence "no
  `smn:` species concept or class exists to point at" becomes false and must be
  rewritten, and that rewrite is the substance of the decision: it is the
  sentence Brett is actually ruling on.
- **If Brett rejects the recommendation and keeps P2**, decision 2 should still
  change one thing: add `dwc:taxonRank "species"` so a consumer knows what rank
  the name is at without parsing the binomial. That is the minimum improvement
  that does not require the refactor.

### 6.3 Decision 4 — is `smn:SockeyeSeaTypeLifeHistory` wanted at all?

**The recommendation does not change whether to mint it. It changes one half of
its scope note.**

Whether the concept exists turns on the mint-from-source-vocabulary-versus-
observed-data policy and on the value of putting the homograph warning on a term
rather than in a document — neither of which is a taxonomy question. Mint it or
do not; the taxonomy answer is indifferent.

What *does* change: the concept's scope note carries a genuinely taxon-scoped
claim — that "a chinook ocean-type concept, if ever minted, must be a separate
species-scoped IRI and is not a synonym of this one", resting on Gilbert (1913)
coining "sea type" across several species and Healey (1991) renaming the chinook
form. Under the recommendation the species-scoping half of that warning becomes
machine-checkable: `smn:SockeyeSeaTypeLifeHistory` and a future chinook concept
would carry R1 links to *different* R2 nodes, so a tool merging them on the
string "Ocean Type" can be made to fail on the taxon mismatch instead of relying
on a human reading prose. **That is the strongest single argument in the whole
briefing for adopting the recommendation**: it converts a scope-note warning
about a homograph into a constraint a machine can enforce, and the homograph is
the exact hazard this concept was minted to flag.

One correction the refactor should carry, noted as prose and not a taxonomy
matter: S9 records that "Gilbert 1913 names *four* species for 'sea type', not
five", while the PR-branch `iao:0000119` and scope note as read on 2026-09-14
say "applied it across five species". **The count discrepancy is not resolved
here** — Gilbert 1913 was not read during this pass — and it is flagged so that
whoever edits the concept does not preserve a figure S9 already contradicts.
*(Settled 2026-09-25 by B-122: five. Gilbert uses "sea type" in all five
species sections, and S9's four was the count of one sentence on p. 8; see the
commons card `concepts/sea-type-terminology.md`.)*

### 6.4 Decision 8 — sockeye river-type peerhood

**The recommendation does not change this decision at all.** It is a question
about the `skos:broader` structure of three concepts within one species, decided
by what Wood et al. 2008, Beacham & Withler 2017, Gustafson et al. 1997, Pavey et
al. 2011 and the CSAS documents actually hold. No taxonomic-assignment pattern
bears on it: all three concepts scope to the same species, so under every
candidate pattern in §4 they carry the identical taxon reference and the
hierarchy question is untouched.

One second-order interaction, small and worth naming only because it affects
merge order: if R1/R2 land in the same change as a peerhood ruling, each of the
three concepts is edited twice in one file. That is a sequencing note, not a
dependency. **Decision 8 can be ruled before, after, or independently of the
taxonomy question with no loss.**

### 6.5 B-108

B-108 proposes pinning `smn:observedTaxonSpecies`'s range to
`obo:NCBITaxon_8015` and mentions the `smn:NCBITaxon_8018` proxy class. Its
`retires_when` reads: *"The range is `obo:NCBITaxon_8015` or the property is
dropped, and a competency query in that repository asserts that a coho
observation does not entail chum."*

**The recommendation says the proposed range is the wrong shape, the proxy class
should be deleted rather than kept, and the retirement condition needs one
addition. It also corrects the defect description.**

**(a) The backlog's description of the entailment is imprecise, and the
imprecision points at the wrong files.** `knowledge/backlog.md` says "annotating
a coho observation entails it is chum". `rdfs:range` constrains the *object*, so
what is entailed to be *O. keta* is **the value**, not the observation. If a
publisher writes `:fish-1 a obo:NCBITaxon_8019` (coho) and
`:obs-1 smn:observedTaxonSpecies :fish-1`, the reasoner entails
`:fish-1 a obo:NCBITaxon_8018` — the *coho* becomes a chum. Damage appears in the
organism and taxon nodes, not the observation nodes, which is where anyone
auditing for it should look.

**(b) The corruption is silent, and this is now measured rather than assumed.**
`ncbitaxon` taxslim 2026-07-12 contains **zero** `DisjointClasses`/
`owl:disjointWith` axioms. No reasoner will report an inconsistency. A dataset
can be wrong for years with every check green.

**(c) `rdfs:range obo:NCBITaxon_8015` is better but still wrong.** Family is the
right rank for the whole scope, including steelhead — that part of B-108 is a
genuine improvement, and if Brett wants a one-line fix today, this is the one to
take. But it keeps the defective *shape*: a range axiom turns every publisher's
value into an entailment target rather than checking it, so the property still
relabels bad data instead of rejecting it, and the class-as-value ambiguity in
(d) survives untouched. **What replaces it: delete the `rdfs:range` from both
`smn:observedTaxonSpecies` and `smn:observedTaxonFamily`**, state the intended
value in the definition, and put enforcement in SHACL if it is wanted.

**If a class-level commitment is genuinely needed it is an all-values-from
restriction, and an earlier draft of this paragraph named the wrong one.** It
offered `smn:Observation rdfs:subClassOf ObjectSomeValuesFrom(p,
obo:NCBITaxon_8015)`, which does not restrict what may be supplied through `p`
at all. Some-values-from says every observation has *at least one* `p`-filler
that is a Salmonidae, and under the open-world assumption it **entails** such a
filler into existence — possibly anonymous, and not necessarily the one the
publisher wrote — while saying nothing about any other filler. A wrong value
sits undisturbed beside the entailed one. The axiom that says "every value of
`p` on one of my observations is a Salmonidae" is
`ObjectAllValuesFrom(p, obo:NCBITaxon_8015)`.

**And even the right axiom is not a substitute for SHACL, which is why the
recommendation keeps both.** All-values-from still entails rather than checks:
OWL is open-world, so a coho supplied through `p` is *inferred* to be a
Salmonidae, not rejected, and with taxslim asserting zero disjointness — (b)
above — nothing contradicts and nothing is reported. SHACL evaluates the
asserted data graph under a closed-world reading and reports a violation on the
value that is actually there. So the division of labour is: all-values-from when
smn wants to state a commitment scoped to its own class, SHACL when smn wants a
publisher's file to fail. Neither instrument does the other's job, and choosing
between them is not a matter of taste.

*The ENVO comparison in §3.5 item 4 does not transfer here.* ENVO's
`ObjectSomeValuesFrom(RO_0002507, NCBITaxon_33090)` sits inside an
`EquivalentClasses` axiom doing **definitional** work — this environment is one
determined by at least one diatom — where some-values-from is exactly the right
operator. That is a class definition, not a range commitment, and it should not
be read as a model for one.

**(d) Both properties are salvageable and should be kept, renamed.** The general
idea — an object property from the observation to a taxon reference — is right,
and matches P3/P7. Two edits beyond dropping the range: document the value as a
*reference to* a taxon rather than an instance *of* one, so the punning in §3.8
is not mistaken for typing; and reconsider `observed*`, since under Brett's
2026-08-17 ruling the subject is usually a population, not an observed fish.
Collapsing the two into one property with an explicit `dwc:taxonRank` on the
target is worth considering, since a family-level and a species-level reference
differ only in what they point at.

**(e) `smn:NCBITaxon_8018` should be deleted, not corrected.** It is the thing
established practice most clearly forbids: ENVO holds 578 NCBITaxon class
references and **zero** ENVO-namespace taxon classes. It is also semantically
wrong on NCBITaxon's own terms — those classes have organisms as instances, so a
proper subclass of *O. keta* is a *kind of chum salmon* (a stock, a run), not a
re-labelling of the species. R3's generated import module supplies the canonical
classes and makes the proxy unnecessary.

**(f) The MIREOT comment is false and the false part is the guard.** The comment
claims the mirror is *"byte-faithful to the source"*. In taxslim 2026-07-12,
`NCBITaxon_8018`'s only asserted parent is `NCBITaxon_8016` (*Oncorhynchus*),
whose parent is `NCBITaxon_504568` (Salmoninae), whose parent is
`NCBITaxon_8015`. The asserted triple collapses two ranks. It is *entailed* by
the real hierarchy, so it is not false as a statement about the world — but the
comment asserting fidelity is false, and it is the only thing standing between a
reader and the assumption that the block matches upstream. A generated module
(R3) replaces the claim with a build step, which is the difference between a
comment and a check.

**(g) B-108's `retires_when` needs one clause.** As written, "the range is
`obo:NCBITaxon_8015` or the property is dropped, and a competency query … asserts
that a coho observation does not entail chum" would be satisfied by taking the
one-line fix in (c) while leaving the proxy class and the false comment in place
— and the competency query would pass, because at family rank a coho genuinely
does not entail chum. **Proposed addition:** *and `smn:NCBITaxon_8018` is deleted
or replaced by a generated import module.* Without it, the item retires while two
of its three defects survive, which is the failure mode the guard-retirement
contract exists to prevent.

---

## 7. Separability from the rest of Q-06

**Brett is right, with one qualification that changes what "separable" means and
two couplings worth knowing before sequencing.**

### The qualification: the bundle is {taxonomy, 1, 2}, not {taxonomy} alone

Decisions **1 and 2 are not separable from the taxonomy question — they *are* the
taxonomy question**, asked twice from different sides. Decision 1 asks where a
taxon assertion may live; decision 2 asks what form it takes. Neither can be
ruled without the answer, and neither adds anything to it. So separating the
taxonomy question out means lifting **those two decisions plus the pattern
ruling** into one pass, not lifting a ninth question away from eight existing
ones. Brett's instinct is correct and the count is the thing to get right: it is
**six independent decisions and one three-part bundle**, not eight independent
ones.

### Decisions that do not depend on it — 3, 4, 8

| Decision | Depends on the taxonomy answer? | Reason |
|---|---|---|
| **3** — two decomposition properties or one generic `smn:hasLifeHistoryAxisValue` | **No** | Entirely about axis-property granularity and query cost through `skos:inScheme`. No taxon content on either side |
| **4** — mint `smn:SockeyeSeaTypeLifeHistory` at all | **No** for the mint; **yes** for one half of its scope note | The mint turns on source-vocabulary policy and the homograph warning. The taxonomy answer only changes whether the *species-scoping* half of that warning is machine-checkable ([§6.3](#63-decision-4--is-smnsockeyeseatypelifehistory-wanted-at-all)) |
| **8** — river-type peerhood | **No** | A `skos:broader` question inside one species. All three concepts carry the same taxon reference under every candidate pattern |

### Decisions that inherit the answer without changing their own question — 6, 7

- **6, the "cycle line" rename.** No taxonomy content: it is about whether
  `smn:CycleLine` should carry issue #70's wording. But the cycle-line concepts
  are **species-scoped in exactly the same way the life-history types are** — the
  scheme's scope note turns on pink returning at age 2 invariantly while Fraser
  sockeye do not, which is a per-species fact. So whatever mechanism carries
  "this concept applies to *O. gorbuscha*" will apply to the cycle-line terms
  too. **Direction: taxonomy → 6, one-way, and it does not change 6's question.**
  Practical consequence: if the taxonomy pattern is adopted, the cycle-line terms
  gain R1 links even though decision 6 is about their labels. Do not let that
  make decision 6 look blocked; it is not.
- **7, shared `smn:` versus a `smn/profile/<program>/` bridge.** Brett's concern
  is that `CONVENTIONS.md` §8 criterion 1 is "expected multi-agency reuse" rather
  than demonstrated. The taxonomy answer **strengthens** the case for shared
  `smn:` on exactly one term and is silent on the rest: a taxon-reference
  property has demand that is *in writing* rather than expected, because
  `gcdfo:Species`'s scope note already asks for taxonomic IRIs and gcdfo's own
  file already declares and applies the shared `smn:Deme` / `smn:Population`
  as `rdfs:subClassOf dwc:Organism`. **Whether that is *two agencies'* demand
  is an inference, not a measurement** — this briefing's draft read those two
  classes as `gcdfo:`-namespaced, and they are smn's own
  ([§2.3](#23-gcdfo--checked-out-working-copy)), so what is measured is one DFO
  vocabulary asking for taxon IRIs and already reusing shared classes with a
  Darwin Core parent. That is still demonstrated demand for the term and it is
  still recorded before the term exists; it is one agency's record of it.
  **Direction: taxonomy → 7, one-way, and it makes 7 easier rather than
  harder.**

### The one coupling that is about order, not meaning — 5

**5, the prefix rewrite.** No semantic dependency. But the taxonomy refactor
touches `ontology/modules/02-observation-measurement.ttl` and
`ontology/modules/07-controlled-vocabularies.ttl`, and PR #27's rewrite
regenerates the published artifacts (`docs/`, the flattened TTL, JSON-LD, OWL).
Accepting 5 first and refactoring taxonomy second means regenerating those
artifacts twice and reviewing the enormous diff twice. **Recommendation on
sequencing only: rule the taxonomy bundle first, then let the prefix rewrite
regenerate once over the settled content.** This costs nothing and is reversible;
it is not an argument for or against either decision.

### The answer, in one line

**Yes — the taxonomy question is separable, and it should be separated: it is one
bundle of three (the pattern, plus decisions 1 and 2), nothing in 3, 4 or 8
depends on it, 6 and 7 inherit its answer without changing their own questions,
and 5 has a merge-order coupling only.** Ruling the bundle alone unblocks the
most and commits the least.

---

## 8. Source register

Every row was retrieved during this pass. "Status" is the HTTP status observed.

| Source | Locator | Status |
|---|---|---|
| Darwin Core List of Terms | `https://dwc.tdwg.org/list/` (version 2026-05-26) | 200 |
| Darwin Core term quick reference | `https://dwc.tdwg.org/terms/` | 200 |
| Darwin Core machine-readable term record | `https://raw.githubusercontent.com/tdwg/dwc/master/vocabulary/term_versions.csv` (961 934 B) | 200 |
| Darwin Core RDF Guide (ratified 2021-07-15) | `https://dwc.tdwg.org/rdf/` | 200 |
| Darwin Core Conceptual Model (ratified 2026-05-26, `http://rs.tdwg.org/dwc/doc/cm/2026-05-26`) | `https://dwc.tdwg.org/cm/` | 200 |
| Darwin Core Data Package Guide | `https://dwc.tdwg.org/dp/` | 200 |
| TDWG ratification announcement (2026-05-26) | `https://www.tdwg.org/news/2026/dwc-additions-ratified/` | 200 |
| `dwciri:toTaxon` term IRI | `http://rs.tdwg.org/dwc/iri/toTaxon` | 200 |
| TCS standard page (ratified 2005-09-16, `http://www.tdwg.org/standards/117`) | `https://www.tdwg.org/standards/tcs/` | 200 |
| TCS 2 public review announcement (2025-04-04) | `https://www.tdwg.org/news/2025/public-review-of-taxon-concept-schema-v2/` | 200 |
| TDWG "Describing Taxon Concepts as RDF" (Baskauf, draft, Type 3) | `https://raw.githubusercontent.com/tdwg/rdf/master/TaxonInRDF.md` | 200 |
| Berendsohn 1995, *TAXON* 44:207–212 | DOI `10.2307/1222443` (CrossRef metadata) | 200 |
| Franz & Peet 2009, *Systematics and Biodiversity* 7(1):5–20 | DOI `10.1017/S147720000800282X` (CrossRef metadata) | 200 |
| Deegan, Dimmer & Mungall 2010, *BMC Bioinformatics* 11:530 | DOI `10.1186/1471-2105-11-530` (CrossRef metadata) | 200 |
| Buttigieg et al. 2016, *J. Biomed. Semantics* 7:57 | DOI `10.1186/s13326-016-0097-6`; text read at `https://pmc.ncbi.nlm.nih.gov/articles/PMC5035502/` | 200 |
| OBO Foundry ENVO registry entry | `https://obofoundry.org/ontology/envo.html` | 200 |
| OBO Foundry NCBITaxon registry entry | `https://obofoundry.org/ontology/ncbitaxon.html` | 200 |
| ENVO NCBITaxon seed list | `https://raw.githubusercontent.com/EnvironmentOntology/envo/master/src/envo/imports/ncbitaxon_terms.txt` | 200 |
| ENVO NCBITaxon import module (578 refs, 0 ENVO classes) | `.../src/envo/imports/ncbitaxon_import.owl` (79 082 B) | 200 |
| ENVO Makefile (`robot extract … -m BOT`, taxslim mirror) | `.../src/envo/Makefile` | 200 |
| ENVO edit file (63 NCBITaxon refs, all in RO class expressions) | `.../src/envo/envo-edit.owl` (6 029 640 B) | 200 |
| NCBITaxon taxslim, `owl:versionInfo` 2026-07-12 | `http://purl.obolibrary.org/obo/ncbitaxon/subsets/taxslim.owl` (40 617 427 B) | 200 |
| OBO PURLs for `NCBITaxon_8015` / `_8018` / `_8023` | redirect to `https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=<taxid>` | 200 |
| OLS4 term record for `NCBITaxon_8023` | `https://www.ebi.ac.uk/ols4/api/ontologies/ncbitaxon/terms?iri=…NCBITaxon_8023` | 200 |
| OLS4 RO label lookups (7 properties) | `https://www.ebi.ac.uk/ols4/api/search?q=RO_…&ontology=ro` | 200 |
| NCBI Taxonomy E-utilities, 9 taxids | `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&id=<id>&retmode=xml` | 200 (8023 returned 429 on first attempt, 200 on retry) |
| WoRMS records by name, 7 taxa | `https://www.marinespecies.org/rest/AphiaRecordsByName/<name>?like=false&marine_only=false` | 200 |
| WoRMS record by AphiaID 254569 (LSID field read) | `https://www.marinespecies.org/rest/AphiaRecordByAphiaID/254569` | 200 |
| WoRMS vernaculars, AphiaID 127185 and 254569 | `https://www.marinespecies.org/rest/AphiaVernacularsByAphiaID/<id>` | 200 |
| WoRMS about page (LSIDs identify "each available name") | `https://www.marinespecies.org/about.php` | 200 |
| GBIF backbone matches, 5 species | `https://api.gbif.org/v1/species/match?name=<name>&strict=true` | 200 |
| ITIS scientific-name and common-name search | `https://www.itis.gov/ITISWebService/jsonservice/searchByScientificName` / `…searchByCommonName` | 200 |
| Catalogue of Life via ChecklistBank (dataset 3LR) | `https://api.checklistbank.org/dataset/3LR/nameusage/search?q=<name>` | 200 |
| SOSA/SSN (W3C Recommendation, 2017-10-19) | `https://www.w3.org/TR/vocab-ssn/` | 200 |
| I-ADOPT ontology 1.1.0 (2025-05-28) | `https://w3id.org/iadopt/ont/` → `https://i-adopt.github.io/ontology/index.html` | 303 → 200 |
| OBOE core ontology | `https://raw.githubusercontent.com/NCEAS/oboe/master/oboe-core.owl` (69 407 B) | 200 |
| NERC Vocabulary Server collection S25 (197 concepts) | `https://vocab.nerc.ac.uk/collection/S25/current/` | 200 |
| NERC Vocabulary Server SPARQL (collection titles) | `https://vocab.nerc.ac.uk/sparql/sparql` | 200 |
| ICES Vocabulary Server (`SpecWoRMS`, `SpecHelcom`) | `https://vocab.ices.dk/` | 200 |
| OWL 2 Structural Specification §5.8.1 Typing Constraints | `https://www.w3.org/TR/owl2-syntax/` | 200 |
| OWL 2 New Features and Rationale §2.4.1 F12 Punning | `https://www.w3.org/TR/owl2-new-features/` | 200 |
| SKOS RDF schema (normative), fetched 2026-09-14 in the review pass — the `exactMatch → closeMatch → mappingRelation → semanticRelation` chain and `semanticRelation`'s `skos:Concept` domain and range | `https://www.w3.org/2009/08/skos-reference/skos.rdf` (28 966 B) | 200 |
| metasalmon `knowledge/workshop-curriculum-and-sdo-guidance-2026-09-08.md` line 117, "Do not encourage class/concept cross-role SKOS mappings" | read locally | — |
| smn `02-observation-measurement.ttl`, `main` | `https://raw.githubusercontent.com/salmon-data-mobilization/salmon-domain-ontology/main/ontology/modules/02-observation-measurement.ttl` (14 948 B) | 200 |
| smn `07-controlled-vocabularies.ttl`, branch `feat/spsr-shared-life-history-schemes` | same host, that branch (67 032 B) | 200 |
| smn `01-entity-systematics.ttl`, same branch (no taxon content) | same host, that branch (9 958 B) | 200 |
| smn `CONVENTIONS.md`, `main` | same host, `main` (14 467 B) | 200 |
| smn `ontology/modules/README.md`, `main` | same host, `main` | 200 |
| `w3id.org/smn` resolution | → `https://salmon-data-mobilization.github.io/salmon-domain-ontology/` | 200 |
| `w3id.org/gcdfo/salmon` resolution | → `https://dfo-pacific-science.github.io/dfo-salmon-ontology/` | 200 |
| gcdfo working copy | `ontology/dfo-salmon.ttl`, `ontology/views/wsp-composite-escapement-view.ttl`, `mappings/gcdfo-to-smn.sssom.tsv`, `docs/CONVENTIONS.md` | read locally |
| metasalmon knowledge bundle | `knowledge/sequences/s9-ontology-alignment.md`, `knowledge/questions.md` (Q6, Q8, Q9), `knowledge/backlog.md` (#108), `queue/items/B-108.yaml` | read locally |

### Could not reach, or not verified

| Item | What happened | Effect on this briefing |
|---|---|---|
| **PR #27 diff** (`.../pull/27.diff`) | HTTP **403** through the outbound proxy; the GitHub MCP tool is scoped to three other repositories and returned "Access denied" | Worked around: the PR **branch files** were read directly from `raw.githubusercontent.com` (HTTP 200), which is primary evidence for what the PR asserts. The *diff* — what changed relative to `main` — was not read, so statements about what PR #27 *removes* rest on the S9 card, not on the diff |
| **smn repository tree listing** | GitHub API `git/trees` returned HTTP **403** via `curl`; no `gh` CLI in this environment | Worked around by probing candidate paths individually. **The smn file inventory is therefore incomplete** — `ontology/modules/03-…` through `07-…`, `ontology/imports/`, `docs/ADR.md` and `CHANGELOG.md` all 404'd at the guessed paths, which means the guesses were wrong, not that the files are absent |
| **ENVO FAQ / policy document** | `docs/faq.md` and `docs/policy.md` in the ENVO repository both HTTP **404** | ENVO's taxon policy is stated here as read off its build files and import module, not from a policy document. **No prose ENVO policy statement on taxon references was located** |
| **ENVO 2016 paper on taxon minting** | Read (PMC, HTTP 200) but **does not state a taxon-minting policy** | Cited only for the data-side NCBI mapping practice |
| **ENVO ODK config** | `src/envo/envo-odk.yaml` HTTP **404** | Import method read from the `Makefile` instead (`robot extract … -m BOT`), which is the operative source anyway |
| **TCS 2 ratification status** | The 2025-04-04 announcement records the review opening; **no ratification notice was located** | Stated as "not verified" in §3.3. Do not cite TCS 2 as a ratified standard |
| **Springer/Taylor & Francis full texts** | `link.springer.com` redirected to an auth IDP (HTTP 303); `tandfonline.com` HTTP **403** | Franz & Peet 2009 and the ENVO paper are cited from **CrossRef metadata** (authors, title, journal, volume, pages, year, DOI) plus, for ENVO, the PMC full text. **The Franz & Peet abstract was not read from the publisher**; its characterisation in §3.3 rests on CrossRef metadata and secondary summaries and should be treated as **not verified** at the sentence level |
| **NERC S25 concept data via SPARQL** | The endpoint answered collection-title queries (HTTP 200) but returned empty bindings for concept-level queries | S25 evidence comes from the HTML collection page (HTTP 200) instead. The `BE000005` label is quoted from that page; **the count of 197 concepts is as the page reports it and was not independently counted** |
| **Darwin Core term pages for `taxonID` / `scientificNameID` / `taxonConceptID` via the HTML quick reference** | The page is too large to reach the Taxon section through the fetch tool | Resolved: definitions and examples in §3.1 come from the **machine-readable `term_versions.csv`** (HTTP 200), which is the authoritative record |
| **Gilbert 1913 species count** | Not read | The four-versus-five discrepancy in §6.3 is flagged, **not resolved** (settled 2026-09-25 by B-122: five) |
| **Burgner 1991, Wood 1995** | Not attempted (S9 records them as lending-restricted) | No bearing on the taxonomy question |

---

## 9. The split: what here is this bundle's, and what belongs to the commons

**This card holds a modelling recommendation; it is not the register for the
species facts underneath it.** How `smn` and `gcdfo` should shape a taxonomic
assertion is this bundle's business and Q-06's ruling to make. The
species-level authority facts the recommendation rests on are durable knowledge
about salmon, and this repository's `AGENTS.md` sends that to
`salmon-knowledge-commons`, which already carries a card on **Pacific salmonid
taxonomic authorities** — the right home for them. That repository is private
and was not reachable from the session that wrote this briefing, so the
identifiers are restated here **only so that a maintainer who can reach it can
carry them over**, and nothing in this card asserts its own verification: each
row below was read from the named authority during the 2026-09-14 pass with its
HTTP status recorded in [§8](#8-source-register), no independent check of any of
it has happened, and if the commons card and this list ever disagree, the
commons card is the one to trust.

The identifiers this pass resolved, restated from
[§3.4](#34-the-authority-registries-resolved) with the hedges that travel with
them:

- *Oncorhynchus nerka* (sockeye) — NCBI 8023, WoRMS AphiaID 254569, GBIF 5204039, ITIS TSN 161979, COL 49JFH
- *Oncorhynchus kisutch* (coho) — NCBI 8019, WoRMS 127184, GBIF 5204034, ITIS 161977, COL 49JF8
- *Oncorhynchus tshawytscha* (chinook) — NCBI 74940, WoRMS 158075, GBIF 5204024, ITIS 161980, COL 49JFR
- *Oncorhynchus keta* (chum) — NCBI 8018, WoRMS 127183, GBIF 5204014, ITIS 161976, COL 49JF6
- *Oncorhynchus gorbuscha* (pink) — NCBI 8017, WoRMS 127182, GBIF 5204037, ITIS 161975, COL 74N5S
- *Oncorhynchus mykiss* — NCBI 8022, WoRMS 127185, ITIS 161989; **GBIF and COL not queried**
- *Oncorhynchus* (genus) NCBI 8016; Salmonidae (family) NCBI 8015, WoRMS 125587
- **Steelhead is a vernacular name on the *O. mykiss* record, not a missing
  taxon.** ITIS returns `steelhead` as an English common name on TSN 161989 and
  WoRMS returns `Steelhead` and `steelhead trout` among AphiaID 127185's English
  vernaculars (both HTTP 200). That placement is the commons card's to hold; the
  modelling consequence — it is a `dwc:vernacularName` slot, and an argument for
  separating taxon reference from life history — stays here.
- **Hedge carried with the list:** of the WoRMS LSIDs in
  [§3.4](#34-the-authority-registries-resolved), only sockeye's and Salmonidae's
  were read back from the WoRMS record field itself; the rest are constructed
  from the resolved AphiaID by the documented pattern.

---

## 10. What would retire this briefing

- Brett rules on the bundle {pattern, decision 1, decision 2}, and the ruling is
  recorded in `knowledge/questions.md` Q6 and the S9 decision table.
- **The ruling also disposes of Q8 explicitly, either way.** R2 mints six `smn:`
  IRIs typed `dwc:Taxon`, and Q8 (2026-08-24) ruled that no internal home for
  species is created or pointed at, so adopting R2 amends Q8 and rejecting it
  confirms Q8 — and a ruling that records neither leaves a settled question
  silently contradicted. See [§6.1](#61-decision-1--does-species-go-in-smn-never-gcdfo-survive-a-gcdfo-vocabulary-carrying-dwcscientificname--a-worms-dwcscientificnameid).
- If the recommendation is adopted: B-108's `retires_when` gains the clause in
  [§6.5(g)](#65-b-108), and a competency query in the smn repository asserts both
  that a coho reference does not entail chum **and** that no smn-namespace class
  mirrors an NCBITaxon class.
- If the recommendation is rejected in favour of P2: decision 2 still adds
  `dwc:taxonRank`, and this briefing is superseded by the ruling rather than
  retired by it.
- Independently: if TCS 2 is ratified and any authority in scope begins issuing
  `sec.`-reference concept identifiers for *Oncorhynchus*, pattern P4 becomes
  live and §5 should be re-argued.
