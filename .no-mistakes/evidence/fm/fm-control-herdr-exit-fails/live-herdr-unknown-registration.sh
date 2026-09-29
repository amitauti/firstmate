#!/usr/bin/env bash
# Live: real Herdr registry holding an `unknown` agent_status. Compares the
# classifier and fm-control exit at <root> (head) and <base> (pre-fix).
set -u
ROOT=$1; BASE=$2
. "$ROOT/bin/fm-herdr-lab.sh"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
unset NO_MISTAKES_GATE FM_GATE_REFUSE_BYPASS FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE
SESSION=$(fm_herdr_lab_name unkreg); export HERDR_SESSION="$SESSION"
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
cleanup() { fm_herdr_lab_teardown "$SESSION" >/dev/null 2>&1; chmod -R u+w "$LAB" 2>/dev/null; rm -rf "$LAB"; }
trap cleanup EXIT
fm_herdr_lab_prepare "$SESSION" || exit 1
"$ROOT/bin/fm-lab-home.sh" create "$LAB" >/dev/null || exit 1
echo "lab session: $SESSION"
PROJ="$LAB/proj"; WT="$LAB/wt"; mkdir -p "$PROJ" "$LAB/data/lx"
git -C "$PROJ" init -q; echo '# p' > "$PROJ/README.md"; git -C "$PROJ" add .; git -C "$PROJ" -c user.name=t -c user.email=t@e.invalid commit -qm i
git -C "$PROJ" worktree add --quiet -b lx "$WT"
printf '# Task\n' > "$LAB/data/lx/brief.md"
. "$ROOT/bin/fm-backend.sh"; fm_backend_source herdr || exit 1
C=$(fm_backend_herdr_container_ensure "$WT"); CONTAINER=${C%%$'\t'*}; SEED=${C#*$'\t'}; WS=${CONTAINER#*:}
read -r TAB PANE <<<"$(fm_backend_herdr_create_task "$CONTAINER" fm-lx "$WT" "$SEED")"
printf 'window=%s\nendpoint_task_id=lx\nworktree=%s\nproject=%s\nharness=claude\nkind=ship\nmode=no-mistakes\nyolo=off\nmodel=default\neffort=default\nbackend=herdr\nherdr_session=%s\nherdr_workspace_id=%s\nherdr_tab_id=%s\nherdr_pane_id=%s\n' \
  "$SESSION:$PANE" "$WT" "$PROJ" "$SESSION" "$WS" "$TAB" "$PANE" > "$LAB/state/lx.meta"
H() { herdr "$@" --session "$SESSION"; }
classify() { # <root>
  env -i PATH="$PATH" HOME="$HOME" HERDR_SESSION="$SESSION" bash -c '. "$1/bin/fm-backend.sh"; fm_backend_source herdr
    printf "pane_agent_state=%s agent_state=%s" "$(fm_backend_herdr_pane_agent_state "$2" "$3")" "$(fm_backend_agent_state herdr "$2:$3")"' _ "$1" "$SESSION" "$PANE"
}
echo "=== case A: registration agent_status=unknown over a SHELL-ONLY pane (agent process gone, registration lingers) ==="
H pane report-agent "$PANE" --source fm-live --agent claude --state unknown >/dev/null
sleep 1
echo "herdr agent get: $(H agent get "$PANE" | jq -c '{agent:.result.agent.agent,status:.result.agent.agent_status}')"
echo "pane process state: $(fm_backend_herdr_pane_process_state "$SESSION" "$PANE")"
echo "HEAD classifier: $(classify "$ROOT")"
echo "BASE classifier: $(classify "$BASE")"
for which in BASE HEAD; do
  r=$ROOT; [ $which = BASE ] && r=$BASE
  echo "--- $which: fm-control.sh lx exit ---"
  out=$(env FM_HOME="$LAB" HERDR_SESSION="$SESSION" FM_CONTROL_EXIT_WAIT=5 "$r/bin/fm-control.sh" lx exit 2>&1); rc=$?; printf '%s\n' "$out" | grep -v '^fm-gate-refuse'; echo "rc=$rc"
done
echo
echo "=== case B (adversarial): registration agent_status=unknown over a LIVE agent-named process must NOT read dead ==="
ln -sf "$(command -v sleep)" "$LAB/claude"
H pane send-text "$PANE" "'$LAB/claude' 600"$'\r' >/dev/null
for i in $(seq 1 30); do [ "$(fm_backend_herdr_pane_process_state "$SESSION" "$PANE")" = agent ] && break; sleep 0.3; done
H pane report-agent "$PANE" --source fm-live --agent claude --state unknown >/dev/null
sleep 1
echo "herdr agent get: $(H agent get "$PANE" | jq -c '{agent:.result.agent.agent,status:.result.agent.agent_status}')"
echo "pane process state: $(fm_backend_herdr_pane_process_state "$SESSION" "$PANE")"
echo "HEAD classifier: $(classify "$ROOT")"
echo "BASE classifier: $(classify "$BASE")"
for which in BASE HEAD; do
  r=$ROOT; [ $which = BASE ] && r=$BASE
  echo "--- $which: fm-control.sh lx exit (live agent, unknown registration) ---"
  out=$(env FM_HOME="$LAB" HERDR_SESSION="$SESSION" FM_CONTROL_EXIT_WAIT=5 "$r/bin/fm-control.sh" lx exit 2>&1); rc=$?; printf '%s\n' "$out" | grep -v '^fm-gate-refuse'; echo "rc=$rc"
done
echo "agent-named process still running after refusal: $(fm_backend_herdr_pane_process_state "$SESSION" "$PANE")"
