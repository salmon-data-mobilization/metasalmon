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
metasalmonpy mirrors this package. A behavioural change here is presumed to
need the same change there, in the same stream, or a recorded reason why not.
-->

- [ ] Not a behavioural change.
- [ ] Mirrored, or the deviation is recorded in `knowledge/parity-deviations.md`
      and `PARITY.md`.
