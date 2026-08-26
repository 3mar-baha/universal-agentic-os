#!/usr/bin/env bash
#
# workflow-tests.sh — Real end-to-end tests for the Universal Agentic
# Engineering OS workflow.
#
# Executes the actual machinery against a throwaway project — no mocks:
#
#   T1  uos new            scaffold, runtime vendoring, first commit
#   T2  uos init           toolkit verify, git hooks activation, doctor
#   T3  generic engines    ingest / plan / graph auto-detect / decide
#   T4  TDD micro-cycle    red -> green driven through the Makefile contract
#   T5  circuit breaker    3 strikes -> DIR + BLOCKED -> dispatch refused
#                          -> Guide-approved resume -> dispatch succeeds
#   T6  merge gates        broken script refused; fixed script merged,
#                          checkpoint stamped, worktree pruned
#   T7  session lifecycle  session_start banner + kit injection, teardown
#   T8  pre-commit         live-fire rejections: API key, bearer header,
#                          attribution trailer; benign commit passes
#   T9  release refusals   unknown version, dirty tree, existing tag
#   T10 agent launches     claude/codex/opencode binaries execute, and
#                          Codex accepts the exact -c override syntax the
#                          launcher generates
#
# Usage:
#   bash tests/workflow-tests.sh
#
# Exit status: number of failed tests (0 = all green).
# Network: T10 downloads the agent CLIs via npx (cached after first run).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; }

section() { printf '\n[%s]\n' "$1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ======================================================================
section "T1 uos new — scaffold, vendoring, first commit"
# ======================================================================
if bash "${REPO_ROOT}/scripts/new-project.sh" demo "$TMP" > /dev/null 2>&1; then
    ok "new-project.sh exits 0"
else
    bad "new-project.sh exited non-zero"
fi
D="${TMP}/demo"
# CI runners ship without a global git identity; every commit context below
# needs one. Only fill it when absent so a real user's identity is untouched.
if [ -z "$(git config --global user.email 2> /dev/null || true)" ]; then
    git config --global user.email "workflow-tests@example.invalid"
    git config --global user.name "Workflow Tests"
fi
for f in CLAUDE.md README.md .gitignore .env.example LICENSE CONTRIBUTING.md \
         CHANGELOG.md SECURITY.md Makefile .github/workflows/ci.yml \
         docs/00-VISION.md docs/01-ARCHITECTURE.md docs/02-BACKLOG.md \
         docs/03-DECISIONS.md docs/04-RUNBOOK.md docs/05-TEST-PLAN.md \
         docs/10-CHECKPOINT.md .mcp.json AGENTS.md \
         skills/universal-agentic-workflow.md .claude/hooks/session_start.sh; do
    if [ -f "${D}/${f}" ]; then ok "scaffolded: ${f}"; else bad "missing: ${f}"; fi
done
if git -C "$D" log --format=%s -1 2> /dev/null | grep -q '^chore: scaffold demo'; then
    ok "initial commit made"
else
    bad "initial commit missing or wrong subject"
fi

# ======================================================================
section "T2 uos init — bootstrap inside the scaffolded project"
# ======================================================================
if (cd "$D" && bash scripts/init.sh > /dev/null 2>&1); then
    ok "init.sh completes"
else
    bad "init.sh failed"
fi
if [ "$(git -C "$D" config core.hooksPath)" = ".githooks" ]; then
    ok "git hooks activated in project"
else
    bad "core.hooksPath not set"
fi
if (cd "$D" && bash scripts/uos.sh doctor > /dev/null 2>&1); then
    ok "doctor healthy in project"
else
    bad "doctor reported failures"
fi

# ======================================================================
section "T3 generic engines on a scaffolded project"
# ======================================================================
if (cd "$D" && bash scripts/uos.sh ingest > /dev/null 2>&1 && test -f .claude/spec-index.md); then
    ok "ingest parses scaffold specs and writes index"
else
    bad "ingest failed"
fi
if (cd "$D" && bash scripts/uos.sh plan 2> /dev/null | grep -q NEXT); then
    ok "plan surfaces the open milestone"
else
    bad "plan did not show NEXT"
fi
if (cd "$D" && bash scripts/generate-graph.sh > /dev/null 2>&1) \
    && grep -q 'uos:graph:start' "${D}/docs/01-ARCHITECTURE.md"; then
    ok "graph auto-detects canonical docs/01-ARCHITECTURE.md"
else
    bad "graph sync failed"
fi
if (cd "$D" && bash scripts/generate-graph.sh --check > /dev/null 2>&1); then
    ok "graph --check current after sync"
else
    bad "graph stale right after generation"
fi
if (cd "$D" && bash scripts/record-decision.sh "Test decision" > /dev/null 2>&1) \
    && grep -q '^## ADR-001' "${D}/docs/03-DECISIONS.md"; then
    ok "decide appends ADR-001 to canonical decision log"
else
    bad "decide failed"
fi

# ======================================================================
section "T4 TDD micro-cycle — red before green"
# ======================================================================
mkdir -p "${D}/tests"
cat > "${D}/tests/run.sh" <<'EOF'
#!/usr/bin/env bash
set -e
bash bin/greet.sh | grep -q 'hello from demo'
EOF
cat > "${D}/Makefile" <<'EOF'
test:
	bash tests/run.sh
.PHONY: test
EOF
chmod +x "${D}/tests/run.sh"
if (cd "$D" && ! make test > /dev/null 2>&1); then
    ok "RED: test fails before implementation exists"
else
    bad "RED: test passed without implementation"
fi
mkdir -p "${D}/bin"
printf '#!/usr/bin/env bash\nprintf '"'"'hello from demo\\n'"'"'\n' > "${D}/bin/greet.sh"
chmod +x "${D}/bin/greet.sh"
if (cd "$D" && make test > /dev/null 2>&1); then
    ok "GREEN: test passes after minimal implementation"
else
    bad "GREEN: implementation did not turn test green"
fi
sed -i 's/^- \[ \] M1/- [x] M1/' "${D}/docs/10-CHECKPOINT.md"
if (cd "$D" && bash scripts/uos.sh plan 2> /dev/null | grep -q 'DONE'); then
    ok "checkpoint checkbox drives plan state"
else
    bad "plan did not reflect completed milestone"
fi

# ======================================================================
section "T5 circuit breaker — strikes, BLOCKED, dispatch refusal, resume"
# ======================================================================
payload() {
    printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"tool_response":{"exitCode":%s}}' "$1" "$2"
}
(cd "$D" && payload "npm test" 1 | bash .claude/hooks/post_tool_call.sh > /dev/null 2>&1 || true)
(cd "$D" && payload "npm test" 1 | bash .claude/hooks/post_tool_call.sh > /dev/null 2>&1 || true)
breaker_rc=0
(cd "$D" && payload "npm test" 1 | bash .claude/hooks/post_tool_call.sh > /dev/null 2>&1) || breaker_rc=$?
if [ "$breaker_rc" -eq 2 ]; then
    ok "strike 3 halts with exit code 2"
else
    bad "strike 3 exit code was ${breaker_rc}, expected 2"
fi
if grep -q '^status: BLOCKED' "${D}/docs/10-CHECKPOINT.md" \
    && grep -q 'DIAGNOSTIC INCIDENT REPORT' "${D}/docs/10-CHECKPOINT.md"; then
    ok "DIR written and checkpoint marked BLOCKED"
else
    bad "DIR/BLOCKED state missing"
fi
if (cd "$D" && ! bash scripts/uos.sh dispatch blocked-probe 2 > /dev/null 2>&1); then
    ok "dispatch refused while BLOCKED"
else
    bad "dispatch allowed during BLOCKED"
fi
# Guide approves a changed hypothesis: breaker state resets.
sed -i 's/^status: BLOCKED/status: ACTIVE/' "${D}/docs/10-CHECKPOINT.md"
rm -f "${D}/.claude/.strike_tracker"
if (cd "$D" && bash scripts/uos.sh dispatch tdd-stream 2 > /dev/null 2>&1) \
    && [ -f "${D}/.worktrees/tdd-stream/.claude/STREAM.md" ]; then
    ok "after Guide approval, dispatch provisions the stream"
else
    bad "dispatch failed after BLOCKED cleared"
fi

# ======================================================================
section "T6 merge gates — broken diff refused, clean diff integrated"
# ======================================================================
WT="${D}/.worktrees/tdd-stream"
printf '#!/usr/bin/env bash\nif\n' > "${WT}/broken.sh"
git -C "$WT" add broken.sh
git -C "$WT" -c user.email=t@t -c user.name=t commit -qm "feat: add broken script"
if (cd "$D" && ! bash scripts/uos.sh merge tdd-stream > /dev/null 2>&1); then
    ok "merge refused: bash -n gate caught broken script"
else
    bad "merge accepted a syntactically broken diff"
fi
printf '#!/usr/bin/env bash\nprintf '"'"'ok\\n'"'"'\n' > "${WT}/broken.sh"
git -C "$WT" add broken.sh
git -C "$WT" -c user.email=t@t -c user.name=t commit -qm "fix: repair script"
if (cd "$D" && bash scripts/uos.sh merge tdd-stream > /dev/null 2>&1) \
    && grep -q 'integrated: tdd-stream' "${D}/docs/10-CHECKPOINT.md" \
    && [ ! -e "${WT}" ]; then
    ok "clean stream merged --no-ff, stamped, worktree pruned"
else
    bad "clean merge flow failed"
fi

# ======================================================================
section "T7 session lifecycle hooks in the project"
# ======================================================================
start_out="$(cd "$D" && CLAUDE_TOOLKIT_DIR="${CLAUDE_TOOLKIT_DIR:-${HOME}/ai-agent-toolkit}" \
    bash .claude/hooks/session_start.sh 2> /dev/null || true)"
if printf '%s' "$start_out" | grep -q 'SESSION START' \
    && printf '%s' "$start_out" | grep -qE 'context kit.*ready'; then
    ok "session_start orchestrates kit and prints banner"
else
    bad "session_start banner incomplete"
fi
if (cd "$D" && bash .claude/hooks/session_end.sh > /dev/null 2>&1) \
    && { [ ! -e "${D}/.claude/skills" ] || [ -z "$(ls -A "${D}/.claude/skills" 2> /dev/null)" ]; } \
    && { [ ! -e "${D}/.claude/agents" ] || [ -z "$(ls -A "${D}/.claude/agents" 2> /dev/null)" ]; }; then
    ok "session_end wipes all injected context"
else
    bad "session_end left injected context behind"
fi

# ======================================================================
section "T8 pre-commit live fire — secrets, bearers, attribution"
# ======================================================================
# Fixture patterns are assembled at runtime so this file's own source
# never contains a scanner-matchable secret (the pre-commit hook scans it
# like any other staged content).
FAKE_KEY="sk-ant-$(printf 'a%.0s' $(seq 1 26))"
BEARER_TOKEN="$(printf 'A%.0s' $(seq 1 28))"
commit_reject() {
    # commit_reject <name> <file> <content> [<msg>]
    local name="$1" file="$2" content="$3" msg="${4:-feat: probe}"
    printf '%s\n' "$content" > "${D}/${file}"
    git -C "$D" add "${file}"
    if ! git -C "$D" commit -qm "$msg" 2> /dev/null; then
        ok "rejected: ${name}"
    else
        bad "accepted: ${name}"
    fi
    git -C "$D" reset -q HEAD "${file}" 2> /dev/null
    rm -f "${D}/${file}"
}
commit_reject "fake api key"      leak.txt   "TOKEN=${FAKE_KEY}"
commit_reject "bearer header"     leak.json  "\"Authorization\": \"Bearer ${BEARER_TOKEN}\""
printf 'benign change\n' > "${D}/benign.txt"
git -C "$D" add benign.txt
if git -C "$D" commit -qm "Co-authored-by: Someone <s@t>

benign body" 2> /dev/null; then
    ok "non-AI co-author trailer passes"
else
    bad "false positive: human co-author trailer rejected"
fi
if ! git -C "$D" commit --amend -qm "Co-authored-by: Claude <noreply@anthropic.com>" 2> /dev/null; then
    ok "rejected: AI attribution trailer (commit-msg)"
else
    bad "AI attribution trailer accepted"
fi

# ======================================================================
section "T9 release refusals"
# ======================================================================
CLONE="${TMP}/clone"
git clone -q "${REPO_ROOT}" "$CLONE" 2> /dev/null
TOP_VER="$(grep -m1 -oE '^## \[[0-9]+(\.[0-9]+){2,3}\]' "${REPO_ROOT}/CHANGELOG.md" | tr -d '[]# ')"
if (cd "$CLONE" && ! bash scripts/release.sh 9.9.9 > /dev/null 2>&1); then
    ok "refused: version absent from CHANGELOG"
else
    bad "released a version with no CHANGELOG section"
fi
touch "${CLONE}/dirty.tmp"
if (cd "$CLONE" && ! bash scripts/release.sh "${TOP_VER}" > /dev/null 2>&1); then
    ok "refused: dirty work tree"
else
    bad "released from a dirty tree"
fi
rm -f "${CLONE}/dirty.tmp"
git -C "$CLONE" tag "v${TOP_VER}" 2> /dev/null
if (cd "$CLONE" && ! bash scripts/release.sh "${TOP_VER}" 2> /dev/null); then
    ok "refused: tag already exists"
else
    bad "re-created an existing release tag"
fi

# ======================================================================
section "T10 agent launches with real launcher arguments"
# ======================================================================
if npx --yes @anthropic-ai/claude-code@latest --help > /dev/null 2>&1; then
    ok "claude code binary executes"
else
    bad "claude code failed to execute"
fi
if VANTRILEX_API_KEY=dummy npx --yes @openai/codex@latest \
    -c 'model_providers.vantrilex.name=Vantrilex' \
    -c 'model_providers.vantrilex.env_key=VANTRILEX_API_KEY' \
    -c 'model_providers.vantrilex.wire_api=chat' \
    -c 'model_provider=vantrilex' \
    -c 'model=stub-model' \
    --version > /dev/null 2>&1; then
    ok "codex accepts the exact -c override syntax Vantrilex generates"
else
    bad "codex rejected the generated -c overrides"
fi
if npx --yes opencode-ai@latest --version > /dev/null 2>&1; then
    ok "opencode binary executes"
else
    bad "opencode failed to execute"
fi

# ======================================================================
printf '\n[summary] %s passed, %s failed\n' "$PASS" "$FAIL"
exit "$FAIL"
