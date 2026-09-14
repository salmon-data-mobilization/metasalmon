---
type: Artifact
title: "What verified means on a commons card — a proposal"
description: "A scheme for what verification requires on a salmon-knowledge-commons card, who may assert it, and which parts a continuous-integration check can enforce. Separates agreement among checkers from agreement among sources, because conflating the two is the failure this exists to prevent. Written 2026-09-14 in answer to Q39 on Brett's instruction to come up with a plan; it is a proposal and nothing in it is operative until he rules."
status: draft
tags: [commons, verification, provenance, governance, proposal]
psc:
  id: metasalmon:plan:2026-09-14-commons-verification-scheme
  contexts: [metasalmon:context:hub-coordination]
---

# What verified means on a commons card — a proposal

**Status: proposal.** Q39 asks what a `verified` entry on a
`salmon-knowledge-commons` card requires and whether an agent may ever write
one. Brett's instruction of 2026-09-14 was to be really clear about what
verified means, and he offered two starting points: that several agents
independently finding the same thing, with several sources in agreement, might
count; and that for humans a card is verified once more than one person has
reviewed and confirmed it. This is the refined scheme. **On a ruling it moves
to the commons repository as that repository's governance document**, because
that is where the rule has to live to be enforced; it is drafted here because
Q39 lives in this queue. It refines the two-tier sketch in §4.3 of the
[queue promotion review of 2026-09-12](2026-09-12-queue-promotion-review.md),
which is where this question was re-posed and renumbered; where the two
disagree, this card is the later draft and that record is the history of how
it got here. Nothing in either is operative until Brett rules.

## 1. The state it has to fix

From the Q39 item: 26 cards carry 250 sources and 623 citations, and not one
card has ever been verified, in any commit on any branch. The rule that a
writer cannot be their own checker is prose; `generated` and `verified` share
one schema pattern, so a self-verifying card validates cleanly; and the
repository has no continuous integration at all, so nothing would catch it.
Q24 (2026-09-05) already ruled the publication bar: a card is *stable* when it
carries a named human `verified` entry and passes its citation ledger.

Two observations that shape everything below.

**The 2026-09-02 source pass found two attributions that failed a passage
check.** Not two disputed interpretations: two claims whose cited source did
not say what the card said it said. That is the commonest defect and it is
mechanically detectable.

**Gilbert 1913 supports both readings of the sockeye question** (B-122). Where
a source genuinely holds two readings, a scheme that resolves checker
disagreement by majority vote destroys exactly the signal worth keeping.

## 2. The distinction the scheme turns on

**Agreement among checkers and agreement among sources are different
properties, and neither implies the other.**

- Three checkers agreeing tells you the *reading is reproducible*. If all
  three read one source, it says nothing about whether the claim is true.
- Three sources agreeing tells you the claim is *corroborated* — but only if
  the sources are independent. In this literature they frequently are not:
  three papers citing one earlier observation are one source wearing three
  hats, and that is precisely the shape of the Gilbert 1913 problem.

So the scheme records them separately and never lets one stand in for the
other. It also separates a third thing from both: whether each citation
resolves and actually contains the passage, which is a claim about documents
rather than about salmon, and is the part a machine can settle outright.

## 3. What agents are and are not good for here

**Own it outright:** resolution and location. Does the identifier resolve, is
the work the one named, does the cited page carry the sentence? The local
`citation-ledger` procedure already implements exactly this — resolve, locate,
log the negatives — and produces a ledger a reader can re-run. An agent is
better at this than a tired human and it is checkable after the fact.

**Do not let it stand alone:** interpretation. Whether a hedged sentence in a
1913 monograph asserts a taxonomy, whether a paper's framing supports the
claim a card makes of it. Redundancy helps less here than it looks: several
sessions of the same model share their systematic reading habits, so their
agreement measures variance, not independence. Different *models* buy more
than more sessions of one model. Where only one model is available, two runs
of it are reproducibility and the scheme counts them as one checker.

That asymmetry, rather than any general claim about agents, is what decides
which tier an agent may write.

## 4. The fields

Replacing one overloaded `verified` with four, so no card can claim more than
it earned. Names are proposals; the shapes are the point.

| Field | Who may write it | What it asserts |
|---|---|---|
| `generated` | agent or human | who wrote the card |
| `citations_checked` | agent or human | every citation resolved and its passage located, with a ledger |
| `corroboration` | agent or human | how many *independent* sources support the claim, with the provenance chains |
| `verified` | **a named human, evidenced** — a resolving ORCID plus the commit attribution in §9 check 2, not a name-shaped string | the substantive claim has been independently affirmed |

**"Human only" is a rule, and a schema cannot enforce it by shape.** A name and
an optional identifier are both just strings, so any automated writer using a
person-like label satisfies a shape test. What the schema can require is an
identifier that *resolves to a public record about a person* and a commit that
is *attributable to that person*, which is what the `verified` row asks for and
what §9 check 2 enforces. The difference between that and "human only" is the
difference between making a false entry impossible and making it visible, and
only the second is on offer; §9 says so where the check is defined, and names
the residual it leaves.

`status` then takes one of `draft`, `checked`, `verified`, `stable`,
`disputed`, and is derived from the fields rather than typed by hand.
`stable` stays Q24's publication bar.

## 5. Claim classes, because one bar cannot fit all three

A uniform bar either freezes a commons with one active human or under-protects
the cards that ontology changes cite. So the required evidence is selected by
a declared `claim_class` on each card.

**Class A — bibliographic.** "Gilbert 1913 page 16 says X." The claim is about
a document both checkers can open.
*Verification:* agent-sufficient. Two `citations_checked` entries from
distinct sessions, different models where more than one is available, each
locating the passage and agreeing on the quoted text, plus a passing ledger
with zero unresolved rows. This is the one place where an agent's check is not
a lesser substitute for a human's: the evidence is the document, and it is
equally available to both.

**Class B — interpretive.** "River-type is a special case of sea-type." A
claim about the world that needs judgement.
*Verification:* the agent tier yields `checked` plus a corroboration count. A
`verified` entry needs **one human who is not the generator**, who read the
located passages rather than the card's summary. `stable` needs **two**.

**Class C — ruling-bearing or term-defining.** The card fixes what a term
means, supports minting, retargeting or deleting a term, or is cited by an
ontology annotation.
*Verification:* **two humans who did not generate it**, and the ontology
change cites the card's commit. Three independent humans is the right bar in
principle for a card that will be read as a fact by every downstream
consumer; the commons has one active human today, so the honest arrangement is
to make two operative, record three as the aspiration, and say plainly that a
Class C card is at the two-human bar rather than pretending otherwise.

## 6. Independence, defined so it can be checked

**Checkers (agents).** A different session, recorded by token; a different
model where one is available, recorded by identifier; and the second checker
works blind — it reads the sources and the located passages, not the card's
argument and not the first ledger. Both ledgers are kept so a reader can
compare them rather than trust a summary.

**Checkers (humans).** Not the generator. For a two-human bar, also not an
author of the source under examination, where that is knowable.

**Sources.** Two sources are independent for a claim only if neither cites the
other *and* they do not share a common cited ancestor for that claim. The
ledger records, per source, the chain back to the primary observation. Where
three nominal sources reduce to one primary observation, the corroboration
count is **1**, and the card says so. This is the rule that would have caught
the Gilbert 1913 shape before it became a dispute.

## 7. Disagreement is a finding, not a tie to break

If checkers disagree, the card moves to `disputed` and records both readings
with their passages. It does not take the majority and it does not average.
Where the source itself holds both readings, `disputed` is the true state and
a card that resolves it is less accurate than one that does not. A `disputed`
card may still be cited, as a dispute.

## 8. Verification decays

Every card carries `stale_after`. A `verified` entry whose `stale_after` has
passed reverts the card to `checked` until someone re-affirms it. A
date-stamped verification that never expires is the same defect class this
ecosystem's own rule names for a guard with no retirement condition: it
outlives its evidence and then conceals what it was never written for.

## 9. What continuous integration enforces (this is B-123)

Nine checks, each mechanical:

1. `verified.by` is never equal to `generated.by`.
2. `verified` carries a **resolving ORCID, required rather than optional**, and
   the entry is rejected unless that ORCID resolves to a public record whose
   name matches the entry's. Alongside it, the commit that introduced the entry
   must be attributable to the same identity: authored by it, and carrying no
   agent co-author or agent session trailer. Where the commons enables commit
   signature verification, a signature the forge reports as verified for that
   account is the stronger form of the same evidence and should be preferred;
   where it does not, author attribution is what is actually enforceable and
   the check says so rather than assuming more. An agent identity in `verified`
   is a schema error; agent identities are valid only in `citations_checked`.

   **What this check buys is auditability, not impossibility, and the earlier
   draft of it overclaimed.** It read "a human-shaped identity (a name, and an
   ORCID where available)" and called itself *"the check that makes the whole
   scheme real"*. A schema cannot tell a human from an agent using a
   name-shaped string and an optional identifier, so an automated writer with a
   person-like label would have passed the check described as making the scheme
   real — a guard whose claimed scope exceeds its real scope, which is the
   failure this ecosystem's own contract names. What the corrected check does is
   make self-verification and casual agent-verification **visible and
   auditable**: every `verified` entry resolves to a person who can be asked
   what they read, and every one is tied to a commit with an author. The
   schema split still matters and is still load-bearing — `generated` and
   `verified` sharing one pattern is why a self-verifying card validates
   cleanly today — but splitting them is what makes check 1 expressible, not
   what makes the scheme real.
3. Every `citations_checked` entry names a ledger that exists and whose rows
   all resolve, with zero unresolved rows.
4. Two `citations_checked` entries carry distinct session identifiers, and
   distinct model identifiers where the card claims different models.
5. `corroboration.independent_sources` is an integer, and any value above 1
   carries a provenance note per source.
6. `claim_class` is present, and the rule applied to `verified` is selected by
   it.
7. `stale_after` is present, and a verified card past it is reported as
   `checked`.
8. `status` is derived, and a hand-typed value that disagrees with the fields
   fails.
9. A `disputed` card carries at least two readings, each with a passage.

**What none of these checks can stop.** A person's own tooling, running on
their machine, under their git identity and their own ORCID, can write a
`verified` entry that no check above will refuse — and it will be refusing
nothing, because every one of them passes correctly: the identity is real, it
resolves, and the commit is attributable to the person who is accountable for
what it says. This residual is stated on its own rather than folded into check
2, because it is what the scheme carries rather than a gap someone should try
to close by tightening a shape test. The answer it offers is accountability,
not prevention: a `verified` entry names someone who can be asked what they
read and who owns the answer. *Retires when:* the commons adopts an attestation
a person signs separately from the commit — a per-card signature over the
located passages, rather than a signature over a diff — which narrows the
residual to a deliberate act rather than a default one, and still does not
close it.

The repository has no continuous integration today, so B-123 is one workflow
plus a schema split, and the schema split is the load-bearing half.

## 10. What this makes possible, and what it costs

Unblocks B-123 (the checks above), Q-40 (the cost measurement becomes the
human step net of agent preparation, which is the number worth knowing),
B-122 and B-121 (overruling a cross-checked card stops being undefined), and
any published subset under Q24.

The cost it adds is real and worth stating: every Class B or C card needs a
human reading, and there is one active human. The scheme's answer is that
agents do all the mechanical work first, so the human minute is spent on
judgement and nothing else, and that `checked` is an honest, useful,
machine-guaranteed state that a card can sit in indefinitely without claiming
to be verified.

***Retires when*** Brett rules, at which point this becomes the commons
repository's governance document and the operative copy moves there; a summary
stays with Q39's entry in the questions file. *Superseded if:* the commons
adopts an external provenance standard that already carries these
distinctions, in which case this is rewritten to map onto it rather than left
to disagree with it.
