#!/usr/bin/env bash
# Live: real Claude in a real Herdr lab pane, stopped with fm-control exit.
# Usage: live-herdr-claude-exit.sh <root> <idle|done|pending>
set -u
ROOT=$1; MODE=$2
. "$ROOT/bin/fm-herdr-lab.sh"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
unset NO_MISTAKES_GATE FM_GATE_REFUSE_BYPASS FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE
SESSION=$(fm_herdr_lab_name "exit$MODE" 2>/dev/null || echo "fm-lab-exit$MODE-$$")
export HERDR_SESSION="$SESSION"
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
cleanup() { fm_herdr_lab_teardown "$SESSION" >/dev/null 2>&1; chmod -R u+w "$LAB" 2>/dev/null; rm -rf "$LAB"; }
trap cleanup EXIT
fm_herdr_lab_prepare "$SESSION" || { echo "prepare failed"; exit 1; }
"$ROOT/bin/fm-lab-home.sh" create "$LAB" >/dev/null || exit 1
echo "lab session: $SESSION"
PROJ="$LAB/proj"; WT="$LAB/wt"; mkdir -p "$PROJ" "$LAB/data/lx"
git -C "$PROJ" init -q; echo '# p' > "$PROJ/README.md"; git -C "$PROJ" add .; git -C "$PROJ" -c user.name=t -c user.email=t@e.invalid commit -qm i
git -C "$PROJ" worktree add --quiet -b lx "$WT"
printf '# Task\n## Captain'"'"'s intent\nlive exit check\n' > "$LAB/data/lx/brief.md"
. "$ROOT/bin/fm-backend.sh"; fm_backend_source herdr || exit 1
C=$(fm_backend_herdr_container_ensure "$WT") || { echo container fail; exit 1; }
CONTAINER=${C%%$'\t'*}; SEED=${C#*$'\t'}; WS=${CONTAINER#*:}
read -r TAB PANE <<<"$(fm_backend_herdr_create_task "$CONTAINER" fm-lx "$WT" "$SEED")"
cat > "$LAB/state/lx.meta" <<EOF
window=$SESSION:$PANE
endpoint_task_id=lx
worktree=$WT
project=$PROJ
harness=claude
kind=ship
mode=no-mistakes
yolo=off
model=default
effort=default
backend=herdr
herdr_session=$SESSION
herdr_workspace_id=$WS
herdr_tab_id=$TAB
herdr_pane_id=$PANE
EOF
H() { herdr "$@" --session "$SESSION"; }
H pane run "$PANE" "cd '$WT' && claude" >/dev/null 2>&1 || H pane send-text "$PANE" "cd '$WT' && claude"$'\r' >/dev/null
agent() { H agent get "$PANE" 2>/dev/null | jq -r '.result.agent.agent_status // .error.code // "?"'; }
# wait up to 60s for claude to register; accept a folder-trust prompt
for i in $(seq 1 60); do
  s=$(agent); scr=$(H pane read "$PANE" --lines 40 2>/dev/null)
  if printf '%s' "$scr" | grep -qiE 'trust (the files|this folder)|Yes, (I trust|proceed)'; then H pane send-keys "$PANE" Down >/dev/null; sleep 0.5; H pane send-keys "$PANE" Enter >/dev/null; sleep 2; fi
  case "$s" in idle|done) break ;; esac; sleep 1
done
echo "registered agent_status before prompt: $(agent)"
if [ "$MODE" = done ]; then
  H pane send-text "$PANE" "Reply with exactly the word OK and nothing else." >/dev/null; sleep 0.5; H pane send-keys "$PANE" Enter >/dev/null
  # look away (focus another tab) so Herdr marks the finished turn as unseen "done"
  OTHER=$(H tab create --workspace "$WS" --focus 2>/dev/null | jq -r '.result.tab.tab_id // empty')
  [ -n "$OTHER" ] && H tab focus "$OTHER" >/dev/null 2>&1
  echo "focused other tab: ${OTHER:-none}"
  for i in $(seq 1 90); do s=$(agent); [ "$s" = done ] && break; sleep 1; done
  sleep 2
fi
if [ "$MODE" = pending ]; then
  H pane send-text "$PANE" "half-written captain draft" >/dev/null; sleep 2
fi
echo "agent_status before exit: $(agent)"
echo "fm pane_agent_state before exit: $(fm_backend_herdr_pane_agent_state "$SESSION" "$PANE")"
echo "fm agent_state before exit: $(fm_backend_agent_state herdr "$SESSION:$PANE")"
echo "--- pane before exit (tail) ---"; H pane read "$PANE" --source visible 2>/dev/null | grep -v '^\s*$' | tail -12
echo "--- fm-control.sh lx exit ---"
OUT=$(cd "$ROOT" && env FM_HOME="$LAB" HERDR_SESSION="$SESSION" "$ROOT/bin/fm-control.sh" lx exit 2>&1); RC=$?
echo "$OUT"; echo "rc=$RC"
echo "agent get after exit: $(H agent get "$PANE" 2>/dev/null | jq -c .)"
echo "process state after exit: $(fm_backend_herdr_pane_process_state "$SESSION" "$PANE")"
echo "fm pane_agent_state after exit: $(fm_backend_herdr_pane_agent_state "$SESSION" "$PANE")"
echo "--- pane after exit (tail) ---"; H pane read "$PANE" --source visible 2>/dev/null | grep -v '^\s*$' | tail -8
echo "agent_status after exit: $(agent)"
H pane get "$PANE" >/dev/null 2>&1 && echo "endpoint still present: yes"; [ -d "$WT" ] && echo "worktree still present: yes"
exit $RC
