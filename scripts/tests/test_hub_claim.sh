#!/usr/bin/env bash
#
# test_hub_claim.sh - the two-terminal race test for the hub claim primitive.
#
# This is step 1 of the hub-coordination migration (section 9.7 of
# knowledge/plans/2026-09-04-salmon-science-foundry-concrete-plan.md) and it is
# the evidence the whole claim design rests on. Section 9.4 asserts that a claim
# is git's own compare-and-swap: an orphan commit can never fast-forward an
# existing ref, so a first claim succeeds if and only if nobody holds it, and
# every later record is a child of the tip you just read, so it succeeds if and
# only if nobody appended since you looked. This script is where that assertion
# stops being a claim about git and becomes a measurement.
#
# It runs entirely offline. It creates a bare repository in a temporary
# directory as a stand-in for the locks repository, clones it twice as a
# stand-in for two agents, and races them. No network, no GitHub repository, no
# API call, and no write of any kind to the repository this file lives in.
#
# WHAT IT PROVES
#
#   00 is a precondition rather than a proof: it says whether the fixture's own
#   queue configuration still carries every key the client requires, because a
#   fixture that has fallen behind turns the client assertions into SKIP lines
#   with a configuration message and a summary that reports nothing failed.
#
#   01 to 06 and 10 to 13 exercise plain git and need nothing but git. They are
#   the proof of the primitive and they are green before the client exists.
#
#   07 to 09, 14 to 15 and 16 to 20 exercise scripts/hub, because they are about
#   the client's behaviour rather than git's: whether its rejection vocabulary
#   recognises the output real git actually produced here, whether losing the
#   race and failing the call are different exit codes, whether a handoff
#   tip is refused for both a claim and a reclaim, and whether the four
#   protocol answers git cannot arbitrate are right. Those four are 16 (a
#   released claim ref is retryable work and must stay in `hub ready`), 17 and
#   18 (an expired self-claim is renewed against the ref, a live one is
#   idempotent), 19 (two claims by one agent cannot both pass a cap of one) and
#   20 (two first calls in one session agree about the agent's identity).
#
#   16 to 20 were added on 2026-09-10 from a review of the client, and each was
#   run RED against the client as it then stood before the fix that turns it
#   green.
#
#   22 and 23 came the same way, later the same day, from a review that read
#   the client against HUB.md's writes register: they are about what `hub done`
#   tells an agent to do next, which the client used to decide from the forge
#   and now decides from whether anyone but Brett has ever contributed to the
#   item's repository. Both were run RED first, 22 against the wording and 23
#   against the defect itself.
#
#   25 and 26 came from the third review round, on 2026-09-10, and each covers
#   something two documents already described as a control while nothing
#   measured it. 25 is the HUB_LOCKS_URL refusal: queue/config.yaml and HUB.md
#   both say the variable stops being an override once locks_repo is real, and
#   until this assertion existed the only evidence for that was the source. It
#   needs its own fixture, because every other queue here is aimed with that
#   variable and so depends on it being obeyed. 26 is the participation answer
#   at claim time, the pair to 22 and 23: those two check the same fact one
#   command later, after the branch is pushed, which in a shared repository is
#   after the breach.
#
#   24, the fingerprint of the repository under test, is numbered last because
#   it runs last, and it keeps its number rather than being renumbered each
#   time assertions are appended. It was 16 until 16 to 20 arrived and 21 until
#   22 and 23 did; renumbering it again would break every reference to it, so
#   from 2026-09-10 new assertions take the next free number and 24 stays where
#   it is. The numbers are labels, not an order.
#
#   Where the client is absent, those report SKIP with the reason rather than
#   FAIL, because migration step 1 comes before step 2.
#   *That tolerance retires when scripts/hub is committed*, at which point the
#   continuous-integration job sets HUB_TEST_REQUIRE_CLIENT=1 and a skip
#   becomes a failure. Left permanently tolerant, this file would be a guard
#   reporting success while checking five fewer things than it says it checks.
#   The client was committed and `.github/workflows/hub-queue.yml` sets that
#   variable as of 2026-09-09, so the tolerance is spent: a skip in continuous
#   integration is a failure there now.
#
#   Until 2026-09-09 nothing ran this file. The workflow ran pytest, which
#   collects `test_*.py`, so a bash script sat beside the Python tests and was
#   executed nowhere while the job reported success. That is worth keeping in
#   the header because it is the same failure the assertions below are about: a
#   green mark standing in for a measurement nobody took.
#
# THE ONE FINDING WORTH READING BEFORE THE CODE
#
#   A push that loses the race does not always say the same thing. Measured on
#   2026-09-09, git 2.50.1, against a local bare repository:
#
#     sequential loser  ! [rejected]        <sha> -> claim/B-53 (fetch first)
#     simultaneous      remote: error: cannot lock ref 'refs/heads/claim/B-53':
#     loser                    reference already exists
#                       ! [remote rejected] <sha> -> claim/B-53 (failed to
#                                                    update ref)
#
#   Same event, two vocabularies, and which one you get depends on whether the
#   winner's push landed before or after your client decided what to send. A
#   classifier that knows only "non-fast-forward" reports the second case as a
#   call failure, which is precisely the confusion section 9.4 says is the
#   difference between a stalled queue and a silent one. Assertion 07 therefore
#   runs the client's own is_race_output over the bytes this run captured,
#   rather than over bytes anybody wrote by hand.
#
# PORTABILITY
#
#   timeout(1) is not present on macOS by default and gtimeout needs coreutils,
#   so every git and client invocation goes through run_with_timeout, a
#   background-plus-watchdog function that needs nothing but the shell. A hung
#   git cannot wedge an unattended run.
#
#   Timestamp arithmetic is split the same way: BSD date takes -v+30H and GNU
#   date takes -d '+30 hours', and ts_shift tries both.
#
#   Written for bash 3.2, which is what a stock macOS ships: no associative
#   arrays, no mapfile, no ${var^^}.
#
#   git 2.32 or newer is required, for GIT_CONFIG_GLOBAL. The fixture
#   deliberately runs with no user or system git configuration, so a global
#   core.hooksPath or push default cannot change the result and the test
#   measures the same thing on a laptop and on a runner.
#
# USAGE
#
#   bash scripts/tests/test_hub_claim.sh
#   HUB_TEST_REQUIRE_CLIENT=1 bash scripts/tests/test_hub_claim.sh   # in CI
#
#   One PASS, FAIL or SKIP line per assertion, then one summary line. Exit 0
#   when nothing failed and nothing was skipped that this run required; 1
#   otherwise.
#
# ***Retires when:*** claims stop living on git refs. At that point the claim
# protocol, HUB.md's authorization register and this test are deleted together
# rather than adapted.

set -uo pipefail

# ---------------------------------------------------------------- settings --

TEST_TIMEOUT_SECONDS="${HUB_TEST_TIMEOUT_SECONDS:-30}"
GATE_WAIT_SECONDS="${HUB_TEST_GATE_WAIT_SECONDS:-10}"
REQUIRE_CLIENT="${HUB_TEST_REQUIRE_CLIENT:-0}"

RACE_ID="B-53"        # the raced item
HANDOFF_ID="B-54"     # claim tip is a handoff, lease long expired
EXPIRED_ID="B-55"     # claim tip is an ordinary claim, lease long expired
RELEASED_ID="B-56"    # claim ref exists and its tip is a release
SELF_ID="B-57"        # claim tip is this caller's own claim, lease long expired
ABANDONED_ID="B-58"   # claim tip is another agent's claim, lease and grace both elapsed

# The three hand-back items of assertions 22 and 23. Each one is held by this
# caller on a live lease, seeded straight into the locks repository rather than
# claimed through the client, so the hand-back assertions do not spend the
# fixture's concurrent-claim cap and do not depend on the claim path passing.
# Their repositories differ on exactly one fact, which is the fact the hand-back
# instruction has to turn on: who else has ever contributed to that repository.
SOLO_ID="D-01"        # repo metasalmon: GitHub, and nobody but Brett works in it
SHARED_ID="D-02"      # repo salmon-data-standards-workshop: GitHub, and shared
OVERRIDE_ID="D-03"    # repo metasalmonpy: solo by the client's fallback list,
                      # marked shared by the fixture configuration, which wins

# The cap fixture is a second queue with max_concurrent_claims of 1, pointed at
# the same locks repository. It is separate because assertion 19 is the only
# thing that needs a cap of one, and lowering the main fixture's cap would
# change what every other client assertion measures.
CAP_ID_A="C-01"
CAP_ID_B="C-02"

# The refusal fixture of assertion 25. Its configuration names a real locks
# repository, which is the one condition under which HUB_LOCKS_URL stops being
# an override and becomes an error. It has to be its own queue: every other
# fixture here is aimed with that variable, so none of them can measure what
# happens when it is refused.
REFUSE_ID="E-01"

# The participation fixture of assertion 26, with its own agent token so its
# claims are counted against nobody else's concurrency cap. Two items in two
# repositories that differ on the one fact the instruction turns on.
PART_SOLO_ID="F-01"    # repo metasalmon: nobody but Brett works in it
PART_SHARED_ID="F-02"  # repo salmon-data-standards-workshop: shared
PART_TOKEN="parttest-caller"

n_pass=0
n_fail=0
n_skip=0

# ------------------------------------------------------------- reporting ----

say()  { printf '%s\n' "$*"; }
note() { printf '        %s\n' "$*"; }

pass() { n_pass=$((n_pass + 1)); printf 'PASS  %s  %s\n' "$1" "$2"; }
fail() { n_fail=$((n_fail + 1)); printf 'FAIL  %s  %s\n' "$1" "$2"; }
skip() { n_skip=$((n_skip + 1)); printf 'SKIP  %s  %s\n' "$1" "$2"; }

# assert ID DESCRIPTION STATUS   (STATUS 0 is a pass, in shell's own sense)
assert() {
  if [ "$3" = "0" ]; then pass "$1" "$2"; else fail "$1" "$2"; fi
}

die() { printf 'FATAL  %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------- timeouts -----

# run_with_timeout SECONDS COMMAND...
# Returns the command's own status, or 124 when the watchdog killed it. 124 is
# borrowed from timeout(1) so a reader who knows that tool reads this the same
# way. Redirections belong on the call site and are inherited by the command.
run_with_timeout() {
  local secs="$1"; shift
  "$@" &
  local pid=$!
  ( sleep "$secs"; kill -9 "$pid" >/dev/null 2>&1 ) &
  local watchdog=$!
  local rc=0
  wait "$pid"; rc=$?
  kill "$watchdog" >/dev/null 2>&1
  wait "$watchdog" >/dev/null 2>&1
  # A process killed by a signal reports 128 plus the signal. SIGKILL from the
  # watchdog is 137 and there is no other kill in this script, so 137 is the
  # timeout and anything else is the command's own answer.
  if [ "$rc" -eq 137 ]; then return 124; fi
  return "$rc"
}

g() { run_with_timeout "$TEST_TIMEOUT_SECONDS" "$@"; }

# ------------------------------------------------------------ git helpers ---

# claim_record ID AGENT ACTION LEASE_UNTIL
# The client writes exactly these five keys, in this order, into claim.yaml.
# The fixture writes the same shape so the client can read a tip this test
# built, and so a reader comparing the two files is comparing like with like.
# If the client's write_claim_commit changes its keys, this changes with it or
# assertions 08 and 14 quietly stop testing what they name.
claim_record() {
  printf 'id: %s\nagent: %s\naction: %s\nlease_until: %s\nattempt: 1\n' "$1" "$2" "$3" "$4"
}

# mk_commit CLONE MESSAGE BODY [PARENT...]
# Built out of plumbing so nothing needs a checked-out worktree. With no PARENT
# the result is an orphan, which is the property the first claim depends on.
mk_commit() {
  local clone="$1" message="$2" body="$3"; shift 3
  local blob tree parents="" p
  blob=$(printf '%s' "$body" | git -C "$clone" hash-object -w --stdin) || return 1
  tree=$(printf '100644 blob %s\tclaim.yaml\n' "$blob" | git -C "$clone" mktree) || return 1
  for p in "$@"; do parents="$parents -p $p"; done
  # shellcheck disable=SC2086
  git -C "$clone" commit-tree "$tree" $parents -m "$message"
}

# ts_shift OFFSET_HOURS - an ISO-8601 UTC instant, offset from now. BSD date
# first, GNU date second, and a fixed literal last so the run still completes
# on a date(1) that is neither, with the assertions that depend on the offset
# failing honestly rather than the whole script dying.
ts_shift() {
  local h="$1" sign="+"
  case "$h" in -*) sign="-"; h=${h#-} ;; +*) h=${h#+} ;; esac
  date -u -v"${sign}${h}H" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  date -u -d "${sign}${h} hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  printf '2000-01-01T00:00:00Z\n'
}

# push_ref CLONE COMMIT REF OUTFILE -> git's exit status
push_ref() { g git -C "$1" push origin "$2:$3" >"$4" 2>&1; }

# is_ref_rejection FILE
# True when git refused to move the ref, as opposed to failing to reach the
# remote at all. The vocabulary mirrors the client's is_race_output; assertion
# 07 is what keeps the two honest, by running the client's copy over the same
# bytes. Change one and assertion 07 tells you about the other.
is_ref_rejection() {
  grep -Eq '\[rejected\]|\[remote rejected\]' "$1" || return 1
  grep -Eq 'non-fast-forward|fetch first|stale info|cannot lock ref|failed to update ref' "$1"
}

# tip_value REF KEY - one field from the claim.yaml at a ref in the locks
# repository, read the way the client reads it. Assertions 17 and 18 are about
# what the client wrote, so they read the record rather than the client's own
# report of it.
tip_value() {
  git -C "$LOCKS" show "$1:claim.yaml" 2>/dev/null | awk -v k="$2" '
    index($0, k ":") == 1 {
      v = substr($0, length(k) + 2); sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v); print v; exit
    }'
}

# handback_output ID LEASE_UNTIL - the client's own hand-back report, on stdout.
#
# Seeds a live claim held by this caller straight into the locks repository and
# then hands it back. Seeded rather than claimed through the client so that
# assertions 22 and 23 measure only the report: three claims through `hub claim`
# would spend the fixture's concurrent-claim cap, and a cap refusal would look
# like a hand-back that printed nothing.
handback_output() {
  local id="$1" lease="$2" ref="refs/heads/claim/$1" seed
  seed=$(mk_commit "$CLONE_A" "claim $id by $HUB_AGENT_TOKEN" \
          "$(claim_record "$id" "$HUB_AGENT_TOKEN" claim "$lease")")
  push_ref "$CLONE_A" "$seed" "$ref" "$TMPROOT/handback.$id.push"
  hub done "$id" --branch "agent/$id/$HUB_AGENT_TOKEN" >"$TMPROOT/handback.$id.out" 2>&1
  cat "$TMPROOT/handback.$id.out"
}

is_transport_failure() {
  grep -Eq 'does not appear to be a git repository|Could not read from remote|Authentication failed|repository .* not found|unable to access' "$1"
}

# --------------------------------------------------------------- fixture ----

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd) || die "cannot locate the repository root"
SOURCE_CLIENT="${HUB_CLIENT:-$REPO_ROOT/scripts/hub}"

TMPROOT=""
LOCKS=""
CLONE_A=""
CLONE_B=""
FIXTURE_REPO=""
CLIENT=""
CAP_REPO=""
CAP_CLIENT=""
CAP_CACHE=""
REFUSE_REPO=""
REFUSE_CLIENT=""
REFUSE_CACHE=""
PART_REPO=""
PART_CLIENT=""
PART_CACHE=""
CLIENT_PRESENT=0
CLIENT_USABLE=0
CLIENT_SKIP_REASON="scripts/hub does not exist yet (migration step 2)"
EX_RACE=4
EX_FAIL=3

REPO_HEAD_BEFORE=""
REPO_STATUS_BEFORE=""
REPO_REFS_BEFORE=""

fingerprint_repo() {
  # Three read-only facts about the real repository: where HEAD points, what
  # the working tree looks like, and every ref. Compared again at the end, they
  # are the evidence that this test wrote nothing here, rather than the
  # intention that it would not.
  REPO_HEAD_BEFORE=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)
  REPO_STATUS_BEFORE=$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)
  REPO_REFS_BEFORE=$(git -C "$REPO_ROOT" for-each-ref --format='%(refname) %(objectname)' 2>/dev/null)
}

cleanup() {
  local stray
  stray=$(jobs -p 2>/dev/null)
  if [ -n "$stray" ]; then kill $stray >/dev/null 2>&1; fi
  if [ -n "$TMPROOT" ] && [ -d "$TMPROOT" ]; then
    case "$TMPROOT" in
      "$REPO_ROOT"|"$REPO_ROOT"/*)
        printf 'FATAL  refusing to remove %s: it is inside the repository\n' "$TMPROOT" >&2 ;;
      *)
        rm -rf "$TMPROOT" ;;
    esac
  fi
}
trap cleanup EXIT INT TERM

require_git_version() {
  local v major minor
  v=$(git --version 2>/dev/null | awk '{print $3}')
  major=$(printf '%s' "$v" | cut -d. -f1)
  minor=$(printf '%s' "$v" | cut -d. -f2)
  case "$major$minor" in ''|*[!0-9]*) die "cannot parse the git version from '$v'" ;; esac
  if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 32 ]; }; then
    die "git 2.32 or newer is required for GIT_CONFIG_GLOBAL; found $v"
  fi
}

write_fixture_queue() {
  # The client derives its queue directory from its own location, so the
  # fixture gets its own copy of the client beside its own queue. The test
  # therefore never depends on the real queue's contents, which other work
  # changes daily, and never writes into it.
  local items="$FIXTURE_REPO/queue/items"
  mkdir -p "$items" "$FIXTURE_REPO/scripts"
  cp -p "$SOURCE_CLIENT" "$CLIENT" 2>/dev/null || cp "$SOURCE_CLIENT" "$CLIENT"

  cat >"$FIXTURE_REPO/queue/config.yaml" <<'YAML'
# Fixture configuration for the hub claim race test. Not the real queue.
# locks_repo is deliberately a placeholder: the test passes HUB_LOCKS_URL,
# which the client documents as the override for exactly this run, and a
# fixture that carried a plausible remote could send a stray push somewhere
# real if the override were ever dropped.
#
# Every operating constant the client reads has to be here. A key the client
# requires and the fixture omits makes `hub doctor` fail against the fixture,
# which turns every client assertion into a SKIP with a configuration message
# rather than a measurement -- and a skipped assertion is a thing this file
# claims to check and does not. Measured 2026-09-09: the client grew
# `max_reclaims_per_item_per_day`, this fixture did not, and assertions 08, 09,
# 14 and 15 went quiet. `assert_fixture_config_is_complete` below is what turns
# the next one into a failure instead.
locks_repo: PLACEHOLDER-race-test-fixture
claim_ref_prefix: refs/heads/claim/
lease_hours_interactive: 4
lease_hours_batch: 12
heartbeat_minutes: 30
reclaim_grace_minutes: 60
max_concurrent_claims: 2
max_reclaims_per_item_per_day: 1
# Three members, because assertions 22 and 23 are about how the hand-back
# instruction differs between them. metasalmon and salmon-data-standards-workshop
# carry no `solo:` key on purpose: that is the real queue's shape today, so the
# two assertions measure the answer the client gives against the configuration
# that actually exists. metasalmonpy carries one, and carries the value that
# contradicts the client's fallback list, so assertion 23 also measures which of
# the two sources wins.
# RETIRES WHEN: queue/config.yaml carries `solo:` on every member. Then the two
# unkeyed entries here gain the key as well, and the fallback list they exercise
# is deleted from the client.
members:
  - repo: metasalmon
    org: salmon-data-mobilization
    forge: github
  - repo: salmon-data-standards-workshop
    org: salmon-data-mobilization
    forge: github
  - repo: metasalmonpy
    org: salmon-data-mobilization
    forge: github
    solo: false
YAML

  local id
  for id in "$RACE_ID" "$HANDOFF_ID" "$EXPIRED_ID" "$RELEASED_ID" "$SELF_ID" \
            "$ABANDONED_ID"; do
    cat >"$items/$id.yaml" <<YAML
id: $id
kind: defect
title: Fixture item for the hub claim race test
state: ready
claimable: true
repo: metasalmon
blocked_by: []
legacy: '#${id#B-}'
evidence: backlog.md
retires_when: The race test stops needing a fixture item, which is when claims stop living on git refs.
YAML
  done

  # The hand-back items. One per repository, because the repository is the
  # whole variable under test.
  write_fixture_item "$items" "$SOLO_ID" metasalmon
  write_fixture_item "$items" "$SHARED_ID" salmon-data-standards-workshop
  write_fixture_item "$items" "$OVERRIDE_ID" metasalmonpy
}

# write_fixture_item ITEMS_DIR ID REPO
write_fixture_item() {
  cat >"$1/$2.yaml" <<YAML
id: $2
kind: defect
title: Fixture item for the hand-back instruction assertions
state: ready
claimable: true
repo: $3
blocked_by: []
evidence: backlog.md
retires_when: The hand-back instruction stops depending on who else works in the item's repository.
YAML
}

# The second queue, for assertion 19 only. Same client, same locks repository,
# its own configuration with a cap of one and its own two items, so the cap can
# be raced without changing what any other assertion measures.
#
# RETIRES WHEN: the cap stops being a local precheck, which is when it moves
# into the locks repository as a ref a claim has to fast-forward. Then git
# arbitrates it and 19 is replaced by a ref assertion rather than kept.
write_cap_fixture() {
  local items="$CAP_REPO/queue/items" id
  mkdir -p "$items" "$CAP_REPO/scripts"
  cp -p "$SOURCE_CLIENT" "$CAP_CLIENT" 2>/dev/null || cp "$SOURCE_CLIENT" "$CAP_CLIENT"

  cat >"$CAP_REPO/queue/config.yaml" <<'YAML'
# Fixture configuration for the concurrent-claim cap assertion. Not the real
# queue. locks_repo is a placeholder for the same reason it is in the main
# fixture: the test passes HUB_LOCKS_URL and a plausible remote here could send
# a stray push somewhere real if the override were ever dropped.
locks_repo: PLACEHOLDER-cap-test-fixture
claim_ref_prefix: refs/heads/claim/
lease_hours_interactive: 4
lease_hours_batch: 12
heartbeat_minutes: 30
reclaim_grace_minutes: 60
max_concurrent_claims: 1
max_reclaims_per_item_per_day: 1
members:
  - repo: metasalmon
    org: salmon-data-mobilization
    forge: github
YAML

  for id in "$CAP_ID_A" "$CAP_ID_B"; do
    cat >"$items/$id.yaml" <<YAML
id: $id
kind: defect
title: Fixture item for the concurrent-claim cap assertion
state: ready
claimable: true
repo: metasalmon
blocked_by: []
evidence: backlog.md
retires_when: The cap stops being checked by this client.
YAML
  done
}

# The refusal fixture, for assertion 25 only.
#
# Its locks_repo is a REAL org/repo pair rather than a placeholder, and that is
# the whole point: HUB_LOCKS_URL is honoured only while locks_repo is still a
# placeholder, and this is the only queue here that is past that line. The
# value is the real hub locks repository, spelled as `org/repo` so the client
# never resolves it to anything it could reach even if the refusal failed --
# and the assertion checks the throwaway locks repository afterwards to prove
# nothing was written anywhere at all.
#
# RETIRES WHEN: the placeholder branch is deleted from resolve_locks_url, which
# is when HUB_LOCKS_URL stops existing. Then this fixture and assertion 25 go
# with it, because there is no longer an override to refuse.
write_refuse_fixture() {
  local items="$REFUSE_REPO/queue/items"
  mkdir -p "$items" "$REFUSE_REPO/scripts"
  cp -p "$SOURCE_CLIENT" "$REFUSE_CLIENT" 2>/dev/null || cp "$SOURCE_CLIENT" "$REFUSE_CLIENT"

  cat >"$REFUSE_REPO/queue/config.yaml" <<'YAML'
# Fixture configuration for the HUB_LOCKS_URL refusal assertion. Not the real
# queue, but locks_repo is deliberately the real value: the refusal only fires
# once locks_repo is no longer a placeholder, so a placeholder here would test
# nothing.
locks_repo: salmon-data-mobilization/hub-locks
claim_ref_prefix: refs/heads/claim/
lease_hours_interactive: 4
lease_hours_batch: 12
heartbeat_minutes: 30
reclaim_grace_minutes: 60
max_concurrent_claims: 2
max_reclaims_per_item_per_day: 1
members:
  - repo: metasalmon
    org: salmon-data-mobilization
    forge: github
YAML

  cat >"$items/$REFUSE_ID.yaml" <<YAML
id: $REFUSE_ID
kind: defect
title: Fixture item for the HUB_LOCKS_URL refusal assertion
state: ready
claimable: true
repo: metasalmon
blocked_by: []
evidence: backlog.md
retires_when: HUB_LOCKS_URL stops being read by this client.
YAML
}

# The participation fixture, for assertion 26 only.
#
# Its own queue and its own agent token, because the assertion claims two items
# for real and every other fixture's concurrent-claim accounting is already
# spoken for by assertions 19, 22 and 23. Two items, in two repositories that
# differ on exactly one fact: who else has ever contributed to them.
#
# RETIRES WHEN: the grant stops being scoped by participation, which is the
# same condition that retires member_solo_for_repo in the client.
write_participation_fixture() {
  local items="$PART_REPO/queue/items"
  mkdir -p "$items" "$PART_REPO/scripts"
  cp -p "$SOURCE_CLIENT" "$PART_CLIENT" 2>/dev/null || cp "$SOURCE_CLIENT" "$PART_CLIENT"

  cat >"$PART_REPO/queue/config.yaml" <<'YAML'
# Fixture configuration for the claim-time participation assertion. Not the
# real queue. locks_repo is a placeholder for the same reason as the main
# fixture: the test passes HUB_LOCKS_URL, and a plausible remote here could
# send a stray push somewhere real if the override were ever dropped.
#
# Neither member states `solo:`, on purpose: that is the shape the real queue
# had when this assertion was written, so it measures the answer the client
# actually gives rather than one the fixture arranged.
locks_repo: PLACEHOLDER-participation-test-fixture
claim_ref_prefix: refs/heads/claim/
lease_hours_interactive: 4
lease_hours_batch: 12
heartbeat_minutes: 30
reclaim_grace_minutes: 60
max_concurrent_claims: 2
max_reclaims_per_item_per_day: 1
members:
  - repo: metasalmon
    org: salmon-data-mobilization
    forge: github
  - repo: salmon-data-standards-workshop
    org: salmon-data-mobilization
    forge: github
YAML

  write_fixture_item "$items" "$PART_SOLO_ID" metasalmon
  write_fixture_item "$items" "$PART_SHARED_ID" salmon-data-standards-workshop
}

setup() {
  require_git_version

  TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/hub-claim-test.XXXXXX") || die "mktemp failed"
  LOCKS="$TMPROOT/hub-locks.git"
  CLONE_A="$TMPROOT/agent-a"
  CLONE_B="$TMPROOT/agent-b"
  FIXTURE_REPO="$TMPROOT/fixture-repo"
  CLIENT="$FIXTURE_REPO/scripts/hub"
  CAP_REPO="$TMPROOT/cap-fixture-repo"
  CAP_CLIENT="$CAP_REPO/scripts/hub"
  CAP_CACHE="$TMPROOT/cap-cache"
  REFUSE_REPO="$TMPROOT/refuse-fixture-repo"
  REFUSE_CLIENT="$REFUSE_REPO/scripts/hub"
  REFUSE_CACHE="$TMPROOT/refuse-cache"
  PART_REPO="$TMPROOT/participation-fixture-repo"
  PART_CLIENT="$PART_REPO/scripts/hub"
  PART_CACHE="$TMPROOT/participation-cache"

  # No user, system or inherited git configuration reaches the fixture, and no
  # terminal prompt can block an unattended run.
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_SYSTEM=/dev/null
  export GIT_TERMINAL_PROMPT=0
  export GIT_ASKPASS=/bin/true
  export GIT_AUTHOR_NAME="hub claim test"
  export GIT_AUTHOR_EMAIL="hub-claim-test@invalid"
  export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
  export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE 2>/dev/null || true

  g git init --bare -q --initial-branch=main "$LOCKS" >/dev/null 2>&1 ||
    die "could not create the bare locks repository"
  # A real locks repository would protect its refs this way, so the fixture
  # proves the property server-side as well as client-side rather than relying
  # on the pusher choosing not to force.
  git -C "$LOCKS" config receive.denyNonFastForwards true
  git -C "$LOCKS" config receive.denyDeletes true

  g git clone -q "$LOCKS" "$CLONE_A" >/dev/null 2>&1 || die "clone A failed"
  g git clone -q "$LOCKS" "$CLONE_B" >/dev/null 2>&1 || die "clone B failed"

  if [ -f "$SOURCE_CLIENT" ]; then
    CLIENT_PRESENT=1
    write_fixture_queue
    write_cap_fixture
    write_refuse_fixture
    write_participation_fixture
    # The client names its own exit codes; read them from it rather than
    # keeping a second copy of two numbers here.
    local v
    v=$(grep -Eo '^EX_RACE=[0-9]+' "$SOURCE_CLIENT" | head -n 1 | grep -Eo '[0-9]+$')
    [ -n "$v" ] && EX_RACE="$v"
    v=$(grep -Eo '^EX_FAIL=[0-9]+' "$SOURCE_CLIENT" | head -n 1 | grep -Eo '[0-9]+$')
    [ -n "$v" ] && EX_FAIL="$v"
  fi
  EX_RACE="${HUB_EXIT_RACE_LOST:-$EX_RACE}"
  EX_FAIL="${HUB_EXIT_CALL_FAILED:-$EX_FAIL}"

  # Everything the client touches outside its own directory lives in the
  # fixture too, so a run leaves nothing behind in the user's cache.
  export HUB_LOCKS_URL="$LOCKS"
  export HUB_CACHE_DIR="$TMPROOT/client-cache"
  export HUB_AGENT_TOKEN="racetest-caller"
}

# hub ARGS... - executable if it is, bash if the mode bit is missing, so a
# checkout that lost it does not turn every client assertion into a failure
# about file permissions.
hub() {
  if [ -x "$CLIENT" ]; then g "$CLIENT" "$@"; else g bash "$CLIENT" "$@"; fi
}

# probe_client - decides whether the client assertions can say anything true.
# A client that exists but cannot be aimed at the fixture would answer every
# question with a call failure, and a refusal that is really a
# misconfiguration is not evidence of a refusal. `hub doctor` exits 0 only
# after it has read the locks repository and negotiated a dry-run push against
# it, so its own success is the probe.
probe_client() {
  [ "$CLIENT_PRESENT" = "1" ] || return 1
  local out="$TMPROOT/doctor.out" rc=0
  hub doctor >"$out" 2>&1; rc=$?
  if [ "$rc" = "0" ]; then CLIENT_USABLE=1; return 0; fi
  CLIENT_SKIP_REASON="hub doctor exited $rc against the fixture: $(grep -m1 '^FAIL' "$out" | tr -d '\n')"
  return 1
}

# ----------------------------------------------------------- the race gate --

GATE=""
RC_A=99
RC_B=99

# race_push CLONE COMMIT REF TAG - waits on the shared gate, then pushes.
race_push() {
  : >"$TMPROOT/ready.$4"
  local deadline=$((SECONDS + GATE_WAIT_SECONDS))
  while [ ! -e "$GATE" ] && [ "$SECONDS" -lt "$deadline" ]; do :; done
  push_ref "$1" "$2" "$3" "$TMPROOT/push.$4.out"
  printf '%s' "$?" >"$TMPROOT/push.$4.rc"
}

# run_race COMMIT_A COMMIT_B REF
# Two pushers started back to back and released together is as close to
# simultaneous as a shell gets, and closer than two people in two terminals,
# which is the scenario the migration step is named for.
run_race() {
  GATE="$TMPROOT/gate.$$.$SECONDS.$RANDOM"
  rm -f "$TMPROOT/ready.a" "$TMPROOT/ready.b" "$GATE"
  race_push "$CLONE_A" "$1" "$3" a & local pid_a=$!
  race_push "$CLONE_B" "$2" "$3" b & local pid_b=$!
  local deadline=$((SECONDS + GATE_WAIT_SECONDS))
  while { [ ! -e "$TMPROOT/ready.a" ] || [ ! -e "$TMPROOT/ready.b" ]; } &&
        [ "$SECONDS" -lt "$deadline" ]; do :; done
  : >"$GATE"
  wait "$pid_a" >/dev/null 2>&1
  wait "$pid_b" >/dev/null 2>&1
  RC_A=$(cat "$TMPROOT/push.a.rc" 2>/dev/null); RC_A=${RC_A:-99}
  RC_B=$(cat "$TMPROOT/push.b.rc" 2>/dev/null); RC_B=${RC_B:-99}
}

# The same gate, for two whole client invocations rather than two pushes.
# Assertions 19 and 20 are about what happens when one agent runs two hub
# processes at once, which is a thing an agent harness does and a thing no
# per-ref compare-and-swap can arbitrate, so the race has to be run rather
# than argued about.
#
# race_client TAG COMMAND... - waits on the gate, runs the command, records the
# exit status in $TMPROOT/client.TAG.rc and the output in client.TAG.out.
race_client() {
  local tag="$1"; shift
  : >"$TMPROOT/cready.$tag"
  local deadline=$((SECONDS + GATE_WAIT_SECONDS))
  while [ ! -e "$GATE" ] && [ "$SECONDS" -lt "$deadline" ]; do :; done
  g "$@" >"$TMPROOT/client.$tag.out" 2>&1
  printf '%s' "$?" >"$TMPROOT/client.$tag.rc"
}

# open_gate TAG_A TAG_B - releases two racers once both say they are ready.
open_gate() {
  local deadline=$((SECONDS + GATE_WAIT_SECONDS))
  while { [ ! -e "$TMPROOT/cready.$1" ] || [ ! -e "$TMPROOT/cready.$2" ]; } &&
        [ "$SECONDS" -lt "$deadline" ]; do :; done
  : >"$GATE"
}

new_gate() {
  GATE="$TMPROOT/gate.$$.$SECONDS.$RANDOM"
  rm -f "$GATE"
}

client_rc() { local v; v=$(cat "$TMPROOT/client.$1.rc" 2>/dev/null); printf '%s' "${v:-99}"; }

# ------------------------------------------------- the fixture-drift guard --
#
# The fixture writes its own queue configuration, which means the client can
# grow a required key and this file can keep writing yesterday's configuration
# with nothing saying so. What that looks like from the outside is four
# assertions turning into SKIP lines with a configuration message, and a summary
# that still says nothing failed.
#
# Measured 2026-09-09: `max_reclaims_per_item_per_day` arrived in the client,
# the fixture did not carry it, and assertions 08, 09, 14 and 15 went quiet.
# This reads the required-key list out of the client's own `doctor` loop, so the
# list has one home. If that loop is ever rewritten and cannot be read, this
# assertion fails rather than passing on an empty list.
#
# RETIRES WHEN: the fixture stops writing its own configuration, which would
# mean the client reads a configuration this file no longer owns.

client_required_config_keys() {
  awk '
    /for v in locks_repo/ { grab = 1 }
    grab {
      line = $0
      sub(/^[ \t]*for v in[ \t]*/, "", line)
      sub(/;[ \t]*do.*$/, "", line)
      gsub(/\\[ \t]*$/, "", line)
      printf "%s ", line
      if ($0 ~ /;[ \t]*do/) { grab = 0 }
    }
  ' "$SOURCE_CLIENT" 2>/dev/null | tr ' \t' '\n\n' | sed '/^$/d'
}

assert_fixture_config_is_complete() {
  if [ "$CLIENT_PRESENT" != "1" ]; then
    skip 00 "fixture config: no client to read a required-key list from"
    note "scripts/hub is absent, which assertions 07 to 09 and 14 to 15 also report"
    return
  fi
  local keys missing="" k cfg
  keys=$(client_required_config_keys)
  if [ -z "$keys" ]; then
    fail 00 "fixture config: the client's required-key list could not be read from scripts/hub"
    note "the doctor loop this guard parses has changed shape; fix the parse rather than dropping the guard"
    return
  fi
  # Both fixture queues, because the cap fixture decays exactly the same way and
  # a missing key there turns assertion 19 into a call failure that reads like a
  # cap refusal.
  local label
  for cfg in "$FIXTURE_REPO/queue/config.yaml" "$CAP_REPO/queue/config.yaml"; do
    label=main
    [ "$cfg" = "$CAP_REPO/queue/config.yaml" ] && label=cap
    for k in $keys; do
      grep -q "^$k:" "$cfg" || missing="$missing $label/$k"
    done
  done
  if [ -n "$missing" ]; then
    fail 00 "fixture config: the client requires keys a fixture does not write:$missing"
    note "add them to write_fixture_queue or write_cap_fixture, or the client assertions skip on a configuration message"
    return
  fi
  pass 00 "fixture config: every key the client requires is written by both fixtures"
}

# ------------------------------------------------------------ assertions ----

main() {
  fingerprint_repo
  setup

  say "hub claim race test"
  note "git $(git --version | awk '{print $3}'), fixture under \$TMPDIR, no network"
  if [ "$CLIENT_PRESENT" = "1" ]; then
    note "client scripts/hub present; lost-the-race exit $EX_RACE, call-failed exit $EX_FAIL"
  else
    note "client scripts/hub absent; the client assertions will be skipped"
  fi
  say ""

  local ref="refs/heads/claim/$RACE_ID"
  local now future stale
  now=$(ts_shift 0); future=$(ts_shift +30); stale=$(ts_shift -30)

  # -- 00 -------------------------------------------------------------------
  # A precondition rather than a property of the design: it says whether the
  # client assertions below can measure anything at all.
  assert_fixture_config_is_complete

  # -- 01 -------------------------------------------------------------------
  local isolated=1
  case "$TMPROOT" in
    "$REPO_ROOT"|"$REPO_ROOT"/*) isolated=1 ;;
    *) [ -d "$LOCKS" ] && [ -d "$CLONE_A/.git" ] && [ -d "$CLONE_B/.git" ] && isolated=0 ;;
  esac
  assert 01 "fixture: a bare locks repository and two clones, outside the real repository" "$isolated"

  # -- 02 -------------------------------------------------------------------
  local claim_a claim_b nparents=1
  claim_a=$(mk_commit "$CLONE_A" "claim $RACE_ID by agent-a" "$(claim_record "$RACE_ID" agent-a claim "$future")")
  claim_b=$(mk_commit "$CLONE_B" "claim $RACE_ID by agent-b" "$(claim_record "$RACE_ID" agent-b claim "$future")")
  if [ -n "$claim_a" ] && [ -n "$claim_b" ]; then
    nparents=$(git -C "$CLONE_A" cat-file commit "$claim_a" | grep -c '^parent ')
  fi
  if [ "$nparents" = "0" ]; then
    assert 02 "both agents build an orphan claim commit, which can never fast-forward an existing ref" 0
  else
    assert 02 "both agents build an orphan claim commit (found $nparents parents)" 1
  fi

  # -- 03 -------------------------------------------------------------------
  run_race "$claim_a" "$claim_b" "$ref"
  local winner="" loser="" winner_commit="" loser_commit=""
  if [ "$RC_A" = "0" ] && [ "$RC_B" != "0" ]; then
    winner=a; loser=b; winner_commit="$claim_a"; loser_commit="$claim_b"
  elif [ "$RC_B" = "0" ] && [ "$RC_A" != "0" ]; then
    winner=b; loser=a; winner_commit="$claim_b"; loser_commit="$claim_a"
  fi
  if [ -n "$winner" ]; then
    assert 03 "first claim: exactly one of two simultaneous pushes succeeded (winner $winner)" 0
  else
    assert 03 "first claim: exactly one of two simultaneous pushes succeeded (got a=$RC_A b=$RC_B)" 1
  fi

  # -- 04 -------------------------------------------------------------------
  local loser_out=""
  if [ -n "$loser" ]; then
    loser_out="$TMPROOT/push.$loser.out"
    if is_ref_rejection "$loser_out" && ! is_transport_failure "$loser_out"; then
      assert 04 "the loser was refused as a ref rejection, not a transport failure" 0
    else
      assert 04 "the loser was refused as a ref rejection, not a transport failure" 1
      note "$(head -n 3 "$loser_out" | tr '\n' ' ')"
    fi
  else
    assert 04 "the loser was refused as a ref rejection, not a transport failure" 1
  fi

  # -- 05 -------------------------------------------------------------------
  # The loser's objects do reach the locks repository: git transfers the pack
  # and then refuses the ref update. So the property to assert is reachability
  # from the ref, not absence from the object store, and asserting the latter
  # would be a test that fails for a reason the design never claimed.
  local tip="" reachable=1
  tip=$(git -C "$LOCKS" rev-parse "$ref" 2>/dev/null)
  if [ -n "$winner_commit" ] && [ "$tip" = "$winner_commit" ] &&
     ! git -C "$LOCKS" merge-base --is-ancestor "$loser_commit" "$tip" 2>/dev/null; then
    reachable=0
  fi
  assert 05 "the ref holds the winner's commit and the loser's commit is not reachable from it" "$reachable"

  # -- 06 -------------------------------------------------------------------
  # The race above could in principle have been decided by timing rather than
  # by the primitive. This repeats it with no concurrency at all: the loser
  # tries again, unhurried, against a ref it can now see. If 06 passes and 03
  # failed, the fixture is at fault; if 06 fails, the design is.
  #
  # 06 is not redundant with 03, and there is a measurement rather than an
  # argument for that. Run this whole file against a fixture with the server
  # protection off and every push forced, on 2026-09-09, and 03 still passes
  # while 06, 11 and 13 fail: a simultaneous race is decided by the server's
  # ref lock whatever the pusher asked for, so 03 alone cannot tell a
  # compare-and-swap from a force. 06, 11 and 13 can.
  local late_out="$TMPROOT/late.out" late_rc=0 late_clone="$CLONE_B"
  [ "$loser" = "a" ] && late_clone="$CLONE_A"
  if [ -n "$loser" ]; then
    push_ref "$late_clone" "$loser_commit" "$ref" "$late_out"; late_rc=$?
    if [ "$late_rc" != "0" ] && is_ref_rejection "$late_out"; then
      assert 06 "an unhurried repeat of the losing claim is refused too, so 03 measured the primitive and not the timing" 0
    else
      assert 06 "an unhurried repeat of the losing claim is refused too (rc $late_rc)" 1
    fi
  else
    assert 06 "an unhurried repeat of the losing claim is refused too" 1
  fi

  # -- 07 -------------------------------------------------------------------
  # The client's own classifier, run over the bytes this run captured. See the
  # finding in the header: the simultaneous loser and the sequential loser get
  # different words for the same event, so a classifier verified against
  # hand-written fixtures can be complete and still be wrong.
  if [ "$CLIENT_PRESENT" = "1" ] && [ -n "$loser_out" ]; then
    local fnfile="$TMPROOT/is_race_output.sh"
    sed -n '/^is_race_output()/,/^}/p' "$SOURCE_CLIENT" >"$fnfile" 2>/dev/null
    if [ -s "$fnfile" ] && . "$fnfile" 2>/dev/null && type is_race_output >/dev/null 2>&1; then
      local sequential_out="$late_out"
      if is_race_output "$(cat "$loser_out")" && is_race_output "$(cat "$sequential_out")"; then
        assert 07 "client: its is_race_output recognises both the simultaneous and the sequential loser output" 0
      else
        assert 07 "client: its is_race_output recognises both the simultaneous and the sequential loser output" 1
        note "simultaneous: $(head -n 2 "$loser_out" | tr '\n' ' ')"
      fi
    else
      skip 07 "client: its is_race_output recognises the loser output this run produced"
      note "no is_race_output function found in the client to extract"
    fi
  else
    skip 07 "client: its is_race_output recognises the loser output this run produced"
    note "$CLIENT_SKIP_REASON"
  fi

  # -- 08 and 09 ------------------------------------------------------------
  # Section 9.4 names this as the one thing the client must get right: lost the
  # race and the call failed are different exit codes, because folding an
  # expired credential into "someone else got there first" makes an agent spin
  # through the whole queue reporting nothing wrong. Two assertions, because
  # one is satisfied by a client that returns the same number twice.
  local probe_ok=1
  if probe_client; then probe_ok=0; fi
  if [ "$probe_ok" = "0" ]; then
    local out rc
    out="$TMPROOT/client.claim.out"
    hub claim "$RACE_ID" >"$out" 2>&1; rc=$?
    if [ "$rc" = "$EX_RACE" ]; then
      assert 08 "client: claiming an item held by another agent exits $EX_RACE, the lost-the-race code" 0
    else
      assert 08 "client: claiming an item held by another agent exits $EX_RACE, got $rc" 1
      note "$(head -n 2 "$out" | tr '\n' ' ')"
    fi

    out="$TMPROOT/client.callfail.out"
    HUB_LOCKS_URL="$TMPROOT/there-is-no-such-locks-repository.git" \
      hub claim "$RACE_ID" >"$out" 2>&1; rc=$?
    if [ "$rc" = "$EX_FAIL" ] && [ "$EX_FAIL" != "$EX_RACE" ]; then
      assert 09 "client: an unreachable locks repository exits $EX_FAIL, a different code from losing the race" 0
    else
      assert 09 "client: an unreachable locks repository exits $EX_FAIL and not $EX_RACE, got $rc" 1
      note "$(head -n 2 "$out" | tr '\n' ' ')"
    fi
  else
    skip 08 "client: claiming an item held by another agent exits with the lost-the-race code"
    note "$CLIENT_SKIP_REASON"
    skip 09 "client: an unreachable locks repository exits with the call-failed code"
    note "$CLIENT_SKIP_REASON"
  fi

  # -- 10 and 11 ------------------------------------------------------------
  # The heartbeat is the same compare-and-swap with a parent. Both agents
  # fetch, both read the same tip, both build a child of it. These records
  # carry a long-expired lease so the tip is stale when the reclaim assertions
  # reach it.
  g git -C "$CLONE_A" fetch -q origin '+refs/heads/claim/*:refs/remotes/origin/claim/*' >/dev/null 2>&1
  g git -C "$CLONE_B" fetch -q origin '+refs/heads/claim/*:refs/remotes/origin/claim/*' >/dev/null 2>&1
  local seen_a seen_b beat_a beat_b beat_winner=""
  seen_a=$(git -C "$CLONE_A" rev-parse "refs/remotes/origin/claim/$RACE_ID" 2>/dev/null)
  seen_b=$(git -C "$CLONE_B" rev-parse "refs/remotes/origin/claim/$RACE_ID" 2>/dev/null)
  beat_a=$(mk_commit "$CLONE_A" "beat $RACE_ID by agent-a" "$(claim_record "$RACE_ID" agent-a beat "$stale")" "$seen_a")
  beat_b=$(mk_commit "$CLONE_B" "beat $RACE_ID by agent-b" "$(claim_record "$RACE_ID" agent-b beat "$stale")" "$seen_b")
  run_race "$beat_a" "$beat_b" "$ref"
  if [ "$RC_A" = "0" ] && [ "$RC_B" != "0" ]; then beat_winner="$beat_a"
  elif [ "$RC_B" = "0" ] && [ "$RC_A" != "0" ]; then beat_winner="$beat_b"; fi
  if [ -n "$beat_winner" ]; then
    assert 10 "heartbeat: two children of one tip raced, exactly one succeeded" 0
  else
    assert 10 "heartbeat: two children of one tip raced, exactly one succeeded (got a=$RC_A b=$RC_B)" 1
  fi

  local new_tip parent depth
  new_tip=$(git -C "$LOCKS" rev-parse "$ref" 2>/dev/null)
  parent=$(git -C "$LOCKS" rev-list --parents -n 1 "$new_tip" 2>/dev/null | awk '{print $2}')
  depth=$(git -C "$LOCKS" rev-list --count "$new_tip" 2>/dev/null)
  if [ "$new_tip" = "$beat_winner" ] && [ "$parent" = "$tip" ] && [ "$depth" = "2" ]; then
    assert 11 "the ref advanced by exactly one commit whose parent is the tip both agents read" 0
  else
    assert 11 "the ref advanced by exactly one commit whose parent is the tip both agents read (parent $parent, depth $depth)" 1
  fi

  # -- 12 and 13 ------------------------------------------------------------
  # The tip's lease ran out 30 hours ago, well past the 12 hour batch lease and
  # its 60 minute grace, so a reclaim is permitted by policy. Git neither knows
  # nor needs to: a reclaim is a child of the tip like anything else, so two
  # agents cannot both reclaim. That is what 12 and 13 measure. Whether the
  # lease had in fact elapsed is the client's judgement and is measured by 15.
  g git -C "$CLONE_A" fetch -q origin '+refs/heads/claim/*:refs/remotes/origin/claim/*' >/dev/null 2>&1
  g git -C "$CLONE_B" fetch -q origin '+refs/heads/claim/*:refs/remotes/origin/claim/*' >/dev/null 2>&1
  local stale_tip_a stale_tip_b rec_a rec_b rc_rec_a=0 rc_rec_b=0
  stale_tip_a=$(git -C "$CLONE_A" rev-parse "refs/remotes/origin/claim/$RACE_ID" 2>/dev/null)
  stale_tip_b=$(git -C "$CLONE_B" rev-parse "refs/remotes/origin/claim/$RACE_ID" 2>/dev/null)
  rec_a=$(mk_commit "$CLONE_A" "reclaim $RACE_ID by agent-a" "$(claim_record "$RACE_ID" agent-a reclaim "$future")" "$stale_tip_a")
  # Built before A pushes, because the second agent's whole situation is that
  # it still believes the tip it read.
  rec_b=$(mk_commit "$CLONE_B" "reclaim $RACE_ID by agent-b" "$(claim_record "$RACE_ID" agent-b reclaim "$future")" "$stale_tip_b")
  push_ref "$CLONE_A" "$rec_a" "$ref" "$TMPROOT/reclaim.a.out"; rc_rec_a=$?
  if [ "$rc_rec_a" = "0" ]; then
    assert 12 "stale lease: a reclaim appended as a child of the expired tip succeeded" 0
  else
    assert 12 "stale lease: a reclaim appended as a child of the expired tip succeeded (rc $rc_rec_a)" 1
    note "$(head -n 2 "$TMPROOT/reclaim.a.out" | tr '\n' ' ')"
  fi
  push_ref "$CLONE_B" "$rec_b" "$ref" "$TMPROOT/reclaim.b.out"; rc_rec_b=$?
  if [ "$rc_rec_b" != "0" ] && is_ref_rejection "$TMPROOT/reclaim.b.out"; then
    assert 13 "a second reclaim built on the pre-reclaim tip was refused, so two agents cannot both reclaim" 0
  else
    assert 13 "a second reclaim built on the pre-reclaim tip was refused (rc $rc_rec_b)" 1
  fi

  # -- 14 and 15 ------------------------------------------------------------
  # HUB.md: hand-back appends a handoff commit and does not release the claim,
  # so finished work never looks free again while Brett is away. The ref is
  # append-only either way, so git cannot enforce this and the client is the
  # only thing that can.
  #
  # 15 is a paired assertion on purpose. A handoff tip whose lease expired long
  # ago must be refused, while an ordinary claim tip whose lease expired just
  # as long ago must be reclaimable. Testing only the refusal would pass on a
  # client that refuses everything old, which is a different bug wearing the
  # same green tick.
  local href="refs/heads/claim/$HANDOFF_ID" eref="refs/heads/claim/$EXPIRED_ID"
  local h1 h2 e1
  h1=$(mk_commit "$CLONE_A" "claim $HANDOFF_ID by agent-a" "$(claim_record "$HANDOFF_ID" agent-a claim "$stale")")
  push_ref "$CLONE_A" "$h1" "$href" "$TMPROOT/handoff.1.out"
  h2=$(mk_commit "$CLONE_A" "handoff $HANDOFF_ID by agent-a" "$(claim_record "$HANDOFF_ID" agent-a handoff "$stale")" "$h1")
  push_ref "$CLONE_A" "$h2" "$href" "$TMPROOT/handoff.2.out"
  e1=$(mk_commit "$CLONE_A" "claim $EXPIRED_ID by agent-a" "$(claim_record "$EXPIRED_ID" agent-a claim "$stale")")
  push_ref "$CLONE_A" "$e1" "$eref" "$TMPROOT/expired.1.out"

  if [ "$probe_ok" = "0" ]; then
    local hc_out="$TMPROOT/client.handoff.claim.out" hc_rc=0
    hub claim "$HANDOFF_ID" >"$hc_out" 2>&1; hc_rc=$?
    if [ "$hc_rc" = "$EX_RACE" ]; then
      assert 14 "client: refuses to claim an item whose tip is a handoff, with the held code and not a call failure" 0
    else
      assert 14 "client: refuses to claim an item whose tip is a handoff (expected $EX_RACE, got $hc_rc)" 1
      note "$(head -n 2 "$hc_out" | tr '\n' ' ')"
    fi

    local ec_out="$TMPROOT/client.expired.claim.out" ec_rc=0
    hub claim "$EXPIRED_ID" >"$ec_out" 2>&1; ec_rc=$?
    if [ "$hc_rc" = "$EX_RACE" ] && [ "$ec_rc" = "0" ]; then
      assert 15 "client: a handoff tip is not reclaimable however old its lease, while an equally old ordinary claim is" 0
    else
      assert 15 "client: a handoff tip is not reclaimable however old its lease (handoff $hc_rc, ordinary $ec_rc; the ordinary one should be 0)" 1
      note "$(head -n 2 "$ec_out" | tr '\n' ' ')"
    fi
  else
    skip 14 "client: refuses to claim an item whose tip is a handoff"
    note "$CLIENT_SKIP_REASON"
    skip 15 "client: a handoff tip is not reclaimable however old its lease"
    note "$CLIENT_SKIP_REASON"
  fi

  # -- 16 -------------------------------------------------------------------
  # A claim ref is never deleted, on purpose, so the lock history stays
  # auditable. That makes the existence of a ref the wrong question for `hub
  # ready`: after a release the ref is still there and its tip says release,
  # and `hub claim` will take that item. An item filtered out of ready because
  # a ref exists is retryable work that no polling agent can ever see again.
  #
  # This asserts HUB.md's condition 4 in full rather than the release case
  # alone, and it is four-way on purpose. A client that stopped filtering
  # altogether would list the handoff and fail; a client that filters on
  # existence hides the released and the abandoned one and fails; and a client
  # that offered the live claim would fail too.
  local rel_ref="refs/heads/claim/$RELEASED_ID" r1 r2
  r1=$(mk_commit "$CLONE_A" "claim $RELEASED_ID by agent-a" "$(claim_record "$RELEASED_ID" agent-a claim "$future")")
  push_ref "$CLONE_A" "$r1" "$rel_ref" "$TMPROOT/released.1.out"
  r2=$(mk_commit "$CLONE_A" "release $RELEASED_ID by agent-a" "$(claim_record "$RELEASED_ID" agent-a release "$future")" "$r1")
  push_ref "$CLONE_A" "$r2" "$rel_ref" "$TMPROOT/released.2.out"

  # Another agent's claim, 30 hours stale against a 60 minute grace, which is
  # eligible for a reclaim and so is claimable work.
  local ab_ref="refs/heads/claim/$ABANDONED_ID" ab1
  ab1=$(mk_commit "$CLONE_A" "claim $ABANDONED_ID by agent-a" "$(claim_record "$ABANDONED_ID" agent-a claim "$stale")")
  push_ref "$CLONE_A" "$ab1" "$ab_ref" "$TMPROOT/abandoned.1.out"

  if [ "$probe_ok" = "0" ]; then
    local ready_out="$TMPROOT/client.ready.out" ready_ok=0
    hub ready >"$ready_out" 2>"$TMPROOT/client.ready.err"
    grep -q "^$RELEASED_ID " "$ready_out"    || ready_ok=1   # released: free
    grep -q "^$ABANDONED_ID " "$ready_out"   || ready_ok=1   # lease and grace elapsed: free
    grep -q "^$HANDOFF_ID " "$ready_out"     && ready_ok=1   # handoff: never free
    grep -q "^$RACE_ID " "$ready_out"        && ready_ok=1   # live lease: held
    if [ "$ready_ok" = "0" ]; then
      assert 16 "client: ready answers HUB.md condition 4, so a released and an abandoned claim ref are listed while a handoff and a live claim are not" 0
    else
      assert 16 "client: ready answers HUB.md condition 4 (released, abandoned, handoff, live)" 1
      note "listed: released $(grep -c "^$RELEASED_ID " "$ready_out"), abandoned $(grep -c "^$ABANDONED_ID " "$ready_out"), handoff $(grep -c "^$HANDOFF_ID " "$ready_out"), live $(grep -c "^$RACE_ID " "$ready_out")"
    fi
  else
    skip 16 "client: ready answers HUB.md condition 4 rather than filtering on whether a ref exists"
    note "$CLIENT_SKIP_REASON"
  fi

  # -- 17 and 18 ------------------------------------------------------------
  # An agent retrying `hub claim` on an item it claimed itself. While the lease
  # is live that is idempotent and must not touch the ref. Once the lease has
  # run out it is not idempotent at all: another agent is eligible to reclaim
  # after the grace, so answering "you still hold it" without renewing the
  # record puts two agents on one item and tells neither of them.
  #
  # Paired for the same reason as 15: a client that always renews passes 17 and
  # fails 18, and a client that never renews passes 18 and fails 17.
  local self_ref="refs/heads/claim/$SELF_ID" s1 self_tip self_rc=0 self_lease self_act
  s1=$(mk_commit "$CLONE_A" "claim $SELF_ID by $HUB_AGENT_TOKEN" \
        "$(claim_record "$SELF_ID" "$HUB_AGENT_TOKEN" claim "$stale")")
  push_ref "$CLONE_A" "$s1" "$self_ref" "$TMPROOT/self.1.out"

  if [ "$probe_ok" = "0" ]; then
    hub claim "$SELF_ID" >"$TMPROOT/client.self.out" 2>&1; self_rc=$?
    self_tip=$(git -C "$LOCKS" rev-parse "$self_ref" 2>/dev/null)
    self_lease=$(tip_value "$self_ref" lease_until)
    self_act=$(tip_value "$self_ref" action)
    if [ "$self_rc" = "0" ] && [ "$self_tip" != "$s1" ] &&
       [ "$(git -C "$LOCKS" rev-list --parents -n 1 "$self_tip" | awk '{print $2}')" = "$s1" ] &&
       [[ "$self_lease" > "$now" ]]; then
      assert 17 "client: claiming an item this agent holds on an expired lease renews the record instead of reporting success" 0
    else
      assert 17 "client: claiming an item this agent holds on an expired lease renews the record (rc $self_rc, tip moved: $([ "$self_tip" != "$s1" ] && echo yes || echo no), action ${self_act:-none}, lease ${self_lease:-none})" 1
      note "$(head -n 3 "$TMPROOT/client.self.out" | tr '\n' ' ')"
    fi

    local again_rc=0 again_tip
    hub claim "$SELF_ID" >"$TMPROOT/client.self2.out" 2>&1; again_rc=$?
    again_tip=$(git -C "$LOCKS" rev-parse "$self_ref" 2>/dev/null)
    if [ "$again_rc" = "0" ] && [ "$again_tip" = "$self_tip" ]; then
      assert 18 "client: claiming an item this agent holds on a live lease is idempotent and does not move the ref" 0
    else
      assert 18 "client: claiming an item this agent holds on a live lease is idempotent (rc $again_rc, tip moved: $([ "$again_tip" != "$self_tip" ] && echo yes || echo no))" 1
      note "$(head -n 3 "$TMPROOT/client.self2.out" | tr '\n' ' ')"
    fi
  else
    skip 17 "client: an expired self-claim is renewed rather than reported as still held"
    note "$CLIENT_SKIP_REASON"
    skip 18 "client: a live self-claim is idempotent"
    note "$CLIENT_SKIP_REASON"
  fi

  # -- 19 -------------------------------------------------------------------
  # The concurrency cap is the one rule in the protocol that is not a question
  # about one ref, so git cannot arbitrate it: two `hub claim` processes for one
  # agent on two different items both read a count of zero, both push, and both
  # pushes are correct on their own. With max_concurrent_claims of 1 that leaves
  # the agent holding two items and nothing in the locks repository saying so.
  #
  # This runs the two processes for real, through the same gate the push race
  # uses, against a fixture whose cap is 1.
  if [ "$probe_ok" = "0" ]; then
    local cap_rc_a cap_rc_b cap_refs cap_ok=1
    # One warm-up call, so the race measures the cap and nothing else: a cold
    # cache would have the two processes racing to create the object store and
    # to mint the token as well, and a failure there would look like a cap
    # refusal in the exit code.
    ( unset HUB_AGENT_TOKEN
      HUB_CACHE_DIR="$CAP_CACHE" HUB_SESSION_KEY="cap-race-session" \
        g bash "$CAP_CLIENT" doctor ) >"$TMPROOT/cap.warmup.out" 2>&1
    rm -f "$TMPROOT/cready.capa" "$TMPROOT/cready.capb"
    new_gate
    ( unset HUB_AGENT_TOKEN
      HUB_CACHE_DIR="$CAP_CACHE" HUB_SESSION_KEY="cap-race-session" \
        race_client capa bash "$CAP_CLIENT" claim "$CAP_ID_A" ) & local cpid_a=$!
    ( unset HUB_AGENT_TOKEN
      HUB_CACHE_DIR="$CAP_CACHE" HUB_SESSION_KEY="cap-race-session" \
        race_client capb bash "$CAP_CLIENT" claim "$CAP_ID_B" ) & local cpid_b=$!
    open_gate capa capb
    wait "$cpid_a" >/dev/null 2>&1
    wait "$cpid_b" >/dev/null 2>&1
    cap_rc_a=$(client_rc capa)
    cap_rc_b=$(client_rc capb)
    cap_refs=$(git -C "$LOCKS" for-each-ref --format='%(refname)' 'refs/heads/claim/C-*' 2>/dev/null | grep -c .)
    # One claim landed, one call was refused, and the refusal is a 3: a cap that
    # is already full is a precondition this agent failed, not a race it lost.
    if [ "$cap_refs" = "1" ] &&
       { { [ "$cap_rc_a" = "0" ] && [ "$cap_rc_b" = "$EX_FAIL" ]; } ||
         { [ "$cap_rc_b" = "0" ] && [ "$cap_rc_a" = "$EX_FAIL" ]; }; }; then
      assert 19 "client: two simultaneous claims by one agent against a cap of one leave exactly one claim" 0
    else
      assert 19 "client: two simultaneous claims by one agent against a cap of one leave exactly one claim (rc $cap_rc_a and $cap_rc_b, claim refs $cap_refs)" 1
      note "a: $(head -n 3 "$TMPROOT/client.capa.out" | tr '\n' ' ')"
      note "b: $(head -n 3 "$TMPROOT/client.capb.out" | tr '\n' ' ')"
    fi
    : "$cap_ok"
  else
    skip 19 "client: two simultaneous claims by one agent cannot both pass a cap of one"
    note "$CLIENT_SKIP_REASON"
  fi

  # -- 20 -------------------------------------------------------------------
  # The agent token is minted once per session and cached. Two first calls in
  # one session that both find the cache empty mint two identities, and the
  # loser's claim then belongs to an agent that its own later beat, release and
  # done calls cannot recognise: the item is held by a stranger who is itself.
  #
  # Repeated, because the window is small and a single pass proves nothing about
  # a race. Every repetition gets an empty cache directory of its own.
  if [ "$probe_ok" = "0" ]; then
    local i tok_a tok_b tok_cache differed=0 rounds=6 unreadable=0
    for i in 1 2 3 4 5 6; do
      tok_cache="$TMPROOT/tok-cache-$i"
      rm -f "$TMPROOT/cready.toka" "$TMPROOT/cready.tokb"
      new_gate
      ( unset HUB_AGENT_TOKEN
        HUB_CACHE_DIR="$tok_cache" HUB_SESSION_KEY="token-race-session" \
          race_client toka bash "$CLIENT" doctor ) & local tpid_a=$!
      ( unset HUB_AGENT_TOKEN
        HUB_CACHE_DIR="$tok_cache" HUB_SESSION_KEY="token-race-session" \
          race_client tokb bash "$CLIENT" doctor ) & local tpid_b=$!
      open_gate toka tokb
      wait "$tpid_a" >/dev/null 2>&1
      wait "$tpid_b" >/dev/null 2>&1
      tok_a=$(sed -n 's/.*agent token \([A-Za-z0-9_-]*\).*/\1/p' "$TMPROOT/client.toka.out" | head -n 1)
      tok_b=$(sed -n 's/.*agent token \([A-Za-z0-9_-]*\).*/\1/p' "$TMPROOT/client.tokb.out" | head -n 1)
      if [ -z "$tok_a" ] || [ -z "$tok_b" ]; then unreadable=1; break; fi
      [ "$tok_a" = "$tok_b" ] || differed=$((differed + 1))
    done
    if [ "$unreadable" = "1" ]; then
      assert 20 "client: two first calls in one session agree about the agent token" 1
      note "no 'agent token' line to read from a doctor run; the report changed shape"
      note "a: $(head -n 3 "$TMPROOT/client.toka.out" | tr '\n' ' ')"
    elif [ "$differed" = "0" ]; then
      assert 20 "client: two first calls in one session mint one agent token, over $rounds races against an empty cache" 0
    else
      assert 20 "client: two first calls in one session mint one agent token ($differed of $rounds races produced two identities)" 1
    fi
  else
    skip 20 "client: two first calls in one session agree about the agent token"
    note "$CLIENT_SKIP_REASON"
  fi

  # -- 22 and 23 ------------------------------------------------------------
  # What `hub done` tells an agent to do once the branch is pushed. The grant in
  # HUB.md is scoped by participation: one draft pull request is authorized in a
  # repository nobody but Brett has ever contributed to, and in a repository
  # anyone else has worked in the agent stops, drafts the body in chat, and
  # waits.
  #
  # Until 2026-09-10 the client branched on the forge instead. Every GitHub
  # member got the draft-pull-request instruction, which includes two members
  # that are not solo, so the client was telling an agent to do the thing the
  # grant forbids and a compliant agent would have done it. That is the failure
  # these two assertions exist to catch, and it is the reason they check the
  # instruction rather than the compare URL: the URL was right in both cases
  # and the sentence after it was not.
  #
  # Paired for the same reason as 15 and 17: a client that always prints the
  # draft instruction passes 22 and fails 23, and a client that always prints
  # the stop instruction passes 23 and fails 22.
  #
  # RETIRES WHEN: the grant stops being scoped by participation, or hand-back
  # stops printing an instruction at all.
  if [ "$probe_ok" = "0" ]; then
    local solo_out shared_out override_out solo_ok=0 shared_ok=0

    solo_out=$(handback_output "$SOLO_ID" "$future")
    printf '%s\n' "$solo_out" | grep -Fq \
      "https://github.com/salmon-data-mobilization/metasalmon/compare/agent/$SOLO_ID/$HUB_AGENT_TOKEN?expand=1" ||
      solo_ok=1
    printf '%s\n' "$solo_out" | grep -Fq "Open one draft pull request" || solo_ok=1
    printf '%s\n' "$solo_out" | grep -Fq "agent-run" || solo_ok=1
    printf '%s\n' "$solo_out" | grep -Fq "STOP" && solo_ok=1
    if [ "$solo_ok" = "0" ]; then
      assert 22 "client: handing back an item in a repository nobody but Brett has contributed to prints the compare URL and instructs one draft pull request" 0
    else
      assert 22 "client: hand-back in a solo repository instructs one draft pull request, labelled agent-run, after the compare URL" 1
      note "$(printf '%s' "$solo_out" | tail -n 6 | tr '\n' ' ')"
    fi

    # Two shared repositories, because they reach the answer by different
    # routes and both routes have to work. salmon-data-standards-workshop is
    # GitHub and carries no `solo:` key, which is the real queue's shape and the
    # exact case the forge branch got wrong. metasalmonpy carries `solo: false`
    # in the fixture configuration while the client's fallback list calls it
    # solo, so it says which source the client believes.
    shared_out=$(handback_output "$SHARED_ID" "$future")
    override_out=$(handback_output "$OVERRIDE_ID" "$future")
    printf '%s\n' "$shared_out" | grep -Fq \
      "https://github.com/salmon-data-mobilization/salmon-data-standards-workshop/compare/agent/$SHARED_ID/$HUB_AGENT_TOKEN?expand=1" ||
      shared_ok=1
    printf '%s\n' "$shared_out" | grep -Fq "STOP" || shared_ok=1
    printf '%s\n' "$shared_out" | grep -Fq "wait for Brett" || shared_ok=1
    printf '%s\n' "$shared_out" | grep -Fq "Open one draft pull request" && shared_ok=1
    printf '%s\n' "$override_out" | grep -Fq "STOP" || shared_ok=1
    printf '%s\n' "$override_out" | grep -Fq "Open one draft pull request" && shared_ok=1
    if [ "$shared_ok" = "0" ]; then
      assert 23 "client: handing back an item in a repository someone else has contributed to prints the compare URL and instructs the agent to stop, draft the body in chat, and wait" 0
    else
      assert 23 "client: hand-back in a shared repository instructs a stop rather than a draft pull request, by configuration and by the fallback list alike" 1
      note "unkeyed member: $(printf '%s' "$shared_out" | tail -n 6 | tr '\n' ' ')"
      note "solo: false member: $(printf '%s' "$override_out" | tail -n 6 | tr '\n' ' ')"
    fi
  else
    skip 22 "client: hand-back in a solo repository instructs one draft pull request"
    note "$CLIENT_SKIP_REASON"
    skip 23 "client: hand-back in a shared repository instructs a stop and a wait"
    note "$CLIENT_SKIP_REASON"
  fi

  # -- 25 -------------------------------------------------------------------
  # HUB_LOCKS_URL is refused once locks_repo names a real repository.
  #
  # This is the control that queue/config.yaml and HUB.md both describe as the
  # thing standing between an environment variable and every claim, heartbeat,
  # release and handoff going to an arbitrary remote. Until now nothing
  # measured it. A control that two documents describe and no test exercises is
  # a claim rather than a control: the variable used to win unconditionally,
  # the fix is one `case` branch, and a later edit that dropped that branch
  # would have restored the silent redirect with every assertion here still
  # green -- because every other fixture in this file sets HUB_LOCKS_URL and
  # depends on it being obeyed.
  #
  # Three things are checked, and the third is the one that matters. The exit
  # code says the call failed; the message says it failed for this reason and
  # not because a fixture was misconfigured; and the absence of a claim ref in
  # the throwaway locks repository says the redirect did not happen. A refusal
  # that printed the right words and pushed anyway would pass the first two.
  #
  # RETIRES WHEN: the placeholder branch is deleted from resolve_locks_url and
  # HUB_LOCKS_URL stops being read at all. Then there is no override to refuse
  # and this assertion is deleted rather than adapted.
  if [ "$probe_ok" = "0" ]; then
    local refuse_out="$TMPROOT/client.refuse.out" refuse_rc=0 refuse_refs refuse_ok=0
    # Its own agent token, so this call is not stopped by something other than
    # the refusal. The shared caller token holds several live claims by now and
    # this fixture's cap is 2, so without a fresh token the call would exit 3
    # on the cap before it ever reached a push -- which is the same exit code
    # and would have made the third check below pass for the wrong reason.
    ( HUB_CACHE_DIR="$REFUSE_CACHE" HUB_LOCKS_URL="$LOCKS" \
      HUB_AGENT_TOKEN="refusetest-caller" \
        g bash "$REFUSE_CLIENT" claim "$REFUSE_ID" ) >"$refuse_out" 2>&1
    refuse_rc=$?
    [ "$refuse_rc" = "$EX_FAIL" ] || refuse_ok=1
    grep -Fq "HUB_LOCKS_URL" "$refuse_out" || refuse_ok=1
    grep -Fq "redirect" "$refuse_out" || refuse_ok=1
    refuse_refs=$(git -C "$LOCKS" for-each-ref --format='%(refname)' \
      "refs/heads/claim/$REFUSE_ID" 2>/dev/null | grep -c .)
    [ "$refuse_refs" = "0" ] || refuse_ok=1
    if [ "$refuse_ok" = "0" ]; then
      assert 25 "client: with locks_repo naming a real repository, HUB_LOCKS_URL is refused rather than obeyed, the refusal names the variable, and no claim ref is written to the remote it named" 0
    else
      assert 25 "client: HUB_LOCKS_URL is refused once locks_repo is real (rc $refuse_rc, wanted $EX_FAIL; stray claim refs $refuse_refs)" 1
      note "$(head -n 3 "$refuse_out" | tr '\n' ' ')"
    fi
  else
    skip 25 "client: HUB_LOCKS_URL is refused once locks_repo names a real repository"
    note "$CLIENT_SKIP_REASON"
  fi

  # -- 26 -------------------------------------------------------------------
  # The participation answer is printed at claim time, not only at hand-back.
  #
  # Assertions 22 and 23 check the same fact at `hub done`, and that is where it
  # was printed and nowhere else until 2026-09-10. By then the agent has done
  # the work and pushed the branch -- and in a shared member repository the
  # push is itself outside the grant, so the hand-back instruction arrived to
  # forbid something already done. A gate that fires after the gated action is
  # a report. This pair measures the same two repositories one command earlier,
  # where the answer can still change what the agent does.
  #
  # Paired with 22 and 23 for the reason those two are paired with each other:
  # a client that always prints the permissive sentence passes half of this and
  # a client that always prints the restrictive one passes the other half.
  #
  # RETIRES WHEN: the grant stops being scoped by participation, at which point
  # 22, 23 and this one are deleted together.
  if [ "$probe_ok" = "0" ]; then
    local psolo_out="$TMPROOT/client.partsolo.out" pshared_out="$TMPROOT/client.partshared.out"
    local psolo_rc=0 pshared_rc=0 part_ok=0
    ( HUB_CACHE_DIR="$PART_CACHE" HUB_AGENT_TOKEN="$PART_TOKEN" \
        g bash "$PART_CLIENT" claim "$PART_SOLO_ID" ) >"$psolo_out" 2>&1
    psolo_rc=$?
    ( HUB_CACHE_DIR="$PART_CACHE" HUB_AGENT_TOKEN="$PART_TOKEN" \
        g bash "$PART_CLIENT" claim "$PART_SHARED_ID" ) >"$pshared_out" 2>&1
    pshared_rc=$?

    [ "$psolo_rc" = "0" ] || part_ok=1
    [ "$pshared_rc" = "0" ] || part_ok=1
    # Both claims succeed, and both say which branch to use, because the
    # participation answer is advice attached to a claim rather than a refusal.
    grep -Fq "work branch: agent/$PART_SOLO_ID/$PART_TOKEN" "$psolo_out" || part_ok=1
    grep -Fq "work branch: agent/$PART_SHARED_ID/$PART_TOKEN" "$pshared_out" || part_ok=1
    # The solo repository: the agent may push that branch.
    grep -Fq "Participation:" "$psolo_out" || part_ok=1
    grep -Fq "you may push" "$psolo_out" || part_ok=1
    grep -Fq "Do not push" "$psolo_out" && part_ok=1
    # The shared one: it may not, and the sentence has to say so here rather
    # than leaving it to hand-back.
    #
    # Each phrase is matched on one line, which is not a stylistic choice: the
    # first version of this paragraph in the client merged its two branches
    # into one sentence, printed the permissive opening and the restrictive
    # remainder together, and exited 0. A grep that spans no line end is what
    # notices that, because the merged text reads as neither sentence.
    grep -Fq "Participation:" "$pshared_out" || part_ok=1
    grep -Fq "Do not push that branch" "$pshared_out" || part_ok=1
    grep -Fq "do not open a pull request" "$pshared_out" || part_ok=1
    grep -Fq "wait for him to say yes" "$pshared_out" || part_ok=1
    grep -Fq "you may push" "$pshared_out" && part_ok=1
    if [ "$part_ok" = "0" ]; then
      assert 26 "client: a claim prints the participation answer for the item's repository, permissive in a repository nobody but Brett works in and restrictive in a shared one, while the work branch is still unpushed" 0
    else
      assert 26 "client: a claim states participation at claim time, not only at hand-back (rc $psolo_rc and $pshared_rc)" 1
      note "solo: $(tail -n 5 "$psolo_out" | tr '\n' ' ')"
      note "shared: $(tail -n 5 "$pshared_out" | tr '\n' ' ')"
    fi
  else
    skip 26 "client: a claim prints the participation answer at claim time"
    note "$CLIENT_SKIP_REASON"
  fi

  # -- 24 -------------------------------------------------------------------
  local head_after status_after refs_after untouched=1
  head_after=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)
  status_after=$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)
  refs_after=$(git -C "$REPO_ROOT" for-each-ref --format='%(refname) %(objectname)' 2>/dev/null)
  if [ "$head_after" = "$REPO_HEAD_BEFORE" ] &&
     [ "$status_after" = "$REPO_STATUS_BEFORE" ] &&
     [ "$refs_after" = "$REPO_REFS_BEFORE" ]; then
    untouched=0
  fi
  assert 24 "the repository under test has the same HEAD, working tree and refs as before the run" "$untouched"

  # ------------------------------------------------------------- summary ---
  say ""
  local verdict="PASS" tail_note=""
  if [ "$n_fail" -gt 0 ]; then
    verdict="FAIL"
  elif [ "$n_skip" -gt 0 ] && [ "$REQUIRE_CLIENT" = "1" ]; then
    verdict="FAIL"
  elif [ "$n_skip" -gt 0 ]; then
    tail_note="  (skips are tolerated until scripts/hub is committed; set HUB_TEST_REQUIRE_CLIENT=1 then)"
  fi
  printf 'RESULT %s  passed %d  failed %d  skipped %d%s\n' \
    "$verdict" "$n_pass" "$n_fail" "$n_skip" "$tail_note"

  [ "$verdict" = "PASS" ] && return 0
  return 1
}

main "$@"
