---
type: InformationObject
title: "B-58 — Add selective R condition handling"
description: "Bounded condition hierarchy, preserved messages/subclasses and source coverage guard; draft release treatment and Python companion."
status: draft
tags: [review, api]
psc:
  id: metasalmon:plan:b58-condition-classes
  contexts: [metasalmon:context:hub-coordination]
---

# B-58 — Add selective R condition handling

The existing S5 review plan asks for a small class hierarchy. Add package
`metasalmon_error` and `metasalmon_warning` bases beneath
`metasalmon_condition`, with validation, LLM, publication and retrieval
subclasses where the emitting module supplies that domain. Other modules use
the package base. These describe the emitting subsystem, not every possible
cause of a failure. Preserve existing specialized classes first in the class
vector, including packet-ingest codes and the LLM deprecation warning.

Every package-authored `cli_abort`, `cli_warn` and `rlang::abort` call receives
the common class builder directly. Messages, argument interpolation, call
frames, parent conditions, external-text escaping, retry logic and public
signatures remain unchanged. Dependency conditions and `stop(condition)`
rethrows retain their original identity. The help topic states this boundary.
Do not claim the historical inventory still describes the current tree.
The two authored base warnings use classed `warningCondition` objects while
preserving `simpleWarning`, their exact messages, null calls and muffling.

First demonstrate RED selective catches on existing package paths and RED
source coverage on unclassed call sites. Then add classes, document all four
families, and exercise at least one real path per family with selective
`tryCatch`/calling handlers. A syntax-tree comparison removes only the added
class-builder calls and must recover the original source tree; this verifies
that the mechanical edit did not rewrite messages or control flow. A source
guard detects future unclassed emissions and rejects incorrect severity.
It checks legal family names rather than assigning an exact family by filename;
the same-stream R/Python module review checks that mapping.

This is draft implementation, not a release action. B-58's major-release
treatment remains for Brett's review; no version/tag/release is made here.
The Python companion must permit equivalent package/domain catches while
preserving builtin exception/category catches and existing custom types.
Each mirror's implementation is reviewed in its own PR; no invented queue ID
or silent parity exemption replaces that obligation.

The same-stream Python implementation is
[metasalmonpy PR 84](https://github.com/salmon-data-mobilization/metasalmonpy/pull/84).
Python retains builtin exception and warning-category catches using concrete
subclasses; R adds the package/family classes to existing condition vectors.
These are language-native implementations of the same selective-catch surface.

The source guard retires when the emitting APIs move to a single checked
constructor or the package stops emitting these conditions. Adding a domain
requires help and selective-handler evidence, not another workflow layer.
