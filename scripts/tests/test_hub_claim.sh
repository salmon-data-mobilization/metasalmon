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
#   07 to 09 and 14 to 15 exercise scripts/hub, because they are about the
#   client's behaviour rather than git's: whether its rejection vocabulary
#   recognises the output real git actually produced here, whether losing the
#   race and failing the call are different exit codes, and whether a handoff
#   tip is refused for both a claim and a reclaim.
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
members:
  - repo: metasalmon
    org: salmon-data-mobilization
    forge: github
YAML

  local id
  for id in "$RACE_ID" "$HANDOFF_ID" "$EXPIRED_ID"; do
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
}

setup() {
  require_git_version

  TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/hub-claim-test.XXXXXX") || die "mktemp failed"
  LOCKS="$TMPROOT/hub-locks.git"
  CLONE_A="$TMPROOT/agent-a"
  CLONE_B="$TMPROOT/agent-b"
  FIXTURE_REPO="$TMPROOT/fixture-repo"
  CLIENT="$FIXTURE_REPO/scripts/hub"

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
  local keys missing="" k
  keys=$(client_required_config_keys)
  if [ -z "$keys" ]; then
    fail 00 "fixture config: the client's required-key list could not be read from scripts/hub"
    note "the doctor loop this guard parses has changed shape; fix the parse rather than dropping the guard"
    return
  fi
  for k in $keys; do
    grep -q "^$k:" "$FIXTURE_REPO/queue/config.yaml" || missing="$missing $k"
  done
  if [ -n "$missing" ]; then
    fail 00 "fixture config: the client requires keys this fixture does not write:$missing"
    note "add them to write_fixture_queue, or the client assertions skip on a configuration message"
    return
  fi
  pass 00 "fixture config: every key the client requires is written by this fixture"
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
  local head_after status_after refs_after untouched=1
  head_after=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)
  status_after=$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)
  refs_after=$(git -C "$REPO_ROOT" for-each-ref --format='%(refname) %(objectname)' 2>/dev/null)
  if [ "$head_after" = "$REPO_HEAD_BEFORE" ] &&
     [ "$status_after" = "$REPO_STATUS_BEFORE" ] &&
     [ "$refs_after" = "$REPO_REFS_BEFORE" ]; then
    untouched=0
  fi
  assert 16 "the repository under test has the same HEAD, working tree and refs as before the run" "$untouched"

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
