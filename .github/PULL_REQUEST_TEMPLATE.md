<!--
Delete any section that does not apply. This template exists to ask two
questions that review has repeatedly failed to ask on its own, not to add
ceremony to a one-line fix.
-->

## What changed, and why

## Did this pull request choose an ontology term?

<!--
Answer this even when the pull request is about something else. It is here
because of a measured failure mode: a semantic commitment made as a by-product
of a code change, inside a pull request whose stated subject was something
else, and justified by nothing except that validation then passed. A survey of
164 merged pull requests across the ecosystem in 2026 found this is the one
class of mistake that code review structurally cannot catch, because the diff
looks correct and the tests go green.

If a term, property, entity, unit, constraint, or method IRI was chosen,
changed, or removed here, say which, and say what justified it other than the
validator accepting it. A source, a commons card, a competency question, or a
prior ruling all count. "It was the IRI that made strict validation pass" is an
honest answer and means the choice still needs appraisal, so say that and open
a queue item rather than letting it merge unexamined.
-->

- [ ] No ontology term was chosen or changed here.
- [ ] A term was chosen or changed, and the justification is:

## Guards

<!--
Every suppression, exclusion, allowlist entry, skip, or workaround records the
condition under which it stops being needed. A guard that outlives its cause
conceals the failure it was never written for.
-->

- [ ] No guard was added.
- [ ] A guard was added and each one states what would retire it.

## Mirror

<!--
metasalmonpy mirrors this package. The mirror is behavioural rather than
literal, and a behavioural change here is presumed to need the same change
there. Three outcomes satisfy the contract, and they are not interchangeable:

  1. It lands in metasalmonpy in the same stream.
  2. It is a difference the ecosystem wants. A deliberate difference is
     recorded as a register row in BOTH `knowledge/parity-deviations.md` here
     and `PARITY.md` there, in this pull request. An undocumented difference is
     a contract violation even when the difference itself is fine.
  3. It is a port that is owed: ordinary "R shipped first" lag rather than a
     chosen difference. The reason it is deferred is logged in the roadmap
     card, and the port is tracked in the port section of
     `knowledge/parity-deviations.md` and in the roadmap's release index,
     deliberately not as a new register row.

Recording a port as a deviation is the failure this section exists to prevent.
It tells the next reader the difference was wanted, so nobody goes looking for
the missing work and the mirror quietly stops being one. Recording a deviation
as a port is the same mistake backwards: it leaves a standing choice sitting in
a catch-up window that will never close it.

Name the pull request, the row, or the card. A tick with nothing after it is
not an answer to any of these three.
-->

- [ ] Not a behavioural change.
- [ ] Mirrored in metasalmonpy in this stream. The pull request there:
- [ ] A deliberate difference, with the register row added to
      `knowledge/parity-deviations.md` and `PARITY.md` here. Row number:
- [ ] A port that is owed, not a deliberate difference. The roadmap card
      logging why it is deferred:
