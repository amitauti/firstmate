# Live lab transcript: worktree-pool double-claim fix
Lab FM_HOME=/tmp/fm-lab.gk10sP (bin/fm-lab-home.sh), private tmux socket fm-lab, real Treehouse v2.3.0 pool (2 slots) at $LAB/work/pool, real Claude crew harness. Scripts run from the gate worktree (commit 126bff9) inside the lab primary pane.

## Setup: stale record stale-a (dead worker) still names slot 1
```
worktree=/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj  branch=fm/stale-a
```

## S1: fresh spawn is offered the stale-claimed slot 1 and lands in free slot 2
```
$ bin/fm-spawn.sh live-scout $LAB/work/proj --scout
fm-gate-refuse: gate agent lifecycle permitted only against lab home /tmp/fm-lab.gk10sP
spawned live-scout harness=claude kind=scout window=primary:fm-live-scout worktree=/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj
SPAWN_EXIT=0

## live-scout meta
worktree=/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj
kind=scout
## slot owner claims
slot 1: 
slot 2: task=live-scout home=/tmp/fm-lab.gk10sP 
## treehouse status
{"name":"1","status":"available","lease_holder":""}
{"name":"2","status":"in-use","lease_holder":""}
## crew window cwd
/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj

# crew pane (real treehouse get: slot 1 entered, exited, re-get -> slot 2, Claude launched)
treehouse get
amit@compoundworks:/tmp/fm-lab.gk10sP/work/proj$ treehouse get
A new version of treehouse is available: v2.3.0 → v3.1.0
Run "treehouse update" to update
🌳 Setting up worktree...
🌳 Entered worktree at /tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj. Type 'exit' to return.
amit@compoundworks:/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj$ exit
exit
🌳 Worktree returned to pool.
amit@compoundworks:/tmp/fm-lab.gk10sP/work/proj$ treehouse get
A new version of treehouse is available: v2.3.0 → v3.1.0
Run "treehouse update" to update
🌳 Setting up worktree...
🌳 Entered worktree at /tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj. Type 'exit' to return.
amit@compoundworks:/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj$ cd -- '/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj'
amit@compoundworks:/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj$ export GOTMPDIR=/tmp/fm-live-scout/gotmp
amit@compoundworks:/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj$ export COMPACT_ADVISER_DISABLE=1
amit@compoundworks:/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj$ export FM_TASK_ID=live-scout
amit@compoundworks:/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj$ . '/tmp/fm-live-scout+64ade6f6cdec5842b023d7067988edd32d29bae1cfe4d16eef2904d5552be2ce/launch.s1790709686.1729110.725.sh'
 ▐▛███▛█   Claude Code v2.1.284
▝▜██████▀  Opus 5.5 · Claude Max
 ▝▝   ▝▝   /tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj
❯ : Firstmate operational input waiting: read '/tmp/fm-lab.gk10sP/state/operational-inbox/1790709686-8dde39054ec6ce9f.msg' and handle its contents as Firstmate operational input.
  Read 1 file, listed 1 directory (ctrl+o to expand)
● I read the launch brief. It's a lab probe, and the only instruction is "Do not act," so I haven't done anything. The worktree is unchanged: no edits, commits or pushes.
  The steering inbox at /tmp/fm-lab.gk10sP/state/live-scout.inbox has nothing new, only an empty handled/ folder. I'm waiting for further instructions from Firstmate.
✻ Cooked for 11s · done 3:21 AM
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
❯ 
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
```

## S2: every free slot claimed -> spawn refuses naming colliding task and remedy; no record, no leaked lease
```
$ bin/fm-spawn.sh second-scout $LAB/work/proj --scout
fm-gate-refuse: gate agent lifecycle permitted only against lab home /tmp/fm-lab.gk10sP
error: task second-scout's allocated worktree /tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj is also task stale-a's recorded copy (/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj); refusing to launch into a colliding worktree. Read task stale-a's current state with bin/fm-crew-state.sh stale-a; when task stale-a is the stale one, close it with bin/fm-teardown.sh stale-a (it leaves a copy on another task's branch with that task), then spawn again; inspect window primary:fm-second-scout
SPAWN_EXIT=1
state/*.meta after: live-scout.meta stale-a.meta (no second-scout.meta); treehouse: slot1 available (no lease), slot2 in-use
```

## Regression baseline: same state with base commit 0a2cdf9's fm-spawn -> lands IN the stale-claimed slot (occurrence 2 reproduced)
```
$ $LAB/base/bin/fm-spawn.sh base-scout $LAB/work/proj --scout
fm-gate-refuse: gate agent lifecycle permitted only against lab home /tmp/fm-lab.gk10sP
spawned base-scout harness=claude kind=scout window=primary:fm-base-scout worktree=/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj
SPAWN_EXIT=0
stale-a.meta: worktree=.../1/proj ; base-scout.meta: worktree=.../1/proj  <- two records, one copy
```

## S3: relaunch into the double-claimed copy refuses before touching the agent (occurrence 1 path)
```
$ bin/fm-control.sh base-scout relaunch --note 'lab probe'
fm-gate-refuse: gate agent lifecycle permitted only against lab home /tmp/fm-lab.gk10sP
error: task base-scout's recorded worktree /tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj is also task stale-a's recorded copy (/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj); refusing to relaunch into a colliding worktree. Read task stale-a's current state with bin/fm-crew-state.sh stale-a; when task stale-a is the stale one, close it with bin/fm-teardown.sh stale-a (it leaves a copy on task base-scout's branch with task base-scout), then relaunch again
RELAUNCH_EXIT=1
base-scout pane still running claude; base-scout.meta byte-identical
```

## S4: follow the remedy while ownership is unprovable (detached copy) -> teardown refuses, even with --force
```
$ bin/fm-crew-state.sh stale-a
state: unknown · source: pane · harness state unavailable (unknown missing)
EXIT=0
$ bin/fm-teardown.sh stale-a
fm-gate-refuse: gate agent lifecycle permitted only against lab home /tmp/fm-lab.gk10sP
REFUSED: task stale-a's recorded worktree /tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj is also task base-scout's recorded worktree, and the branch checked out in it cannot be read, so which task owns that copy cannot be established; nothing was changed - not even with --force.
Read both tasks (bin/fm-crew-state.sh stale-a; bin/fm-crew-state.sh base-scout), then re-run teardown once the copy is on its owning task's branch.
EXIT=1
$ bin/fm-teardown.sh stale-a --force
fm-gate-refuse: gate agent lifecycle permitted only against lab home /tmp/fm-lab.gk10sP
REFUSED: task stale-a's recorded worktree /tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj is also task base-scout's recorded worktree, and the branch checked out in it cannot be read, so which task owns that copy cannot be established; nothing was changed - not even with --force.
Read both tasks (bin/fm-crew-state.sh stale-a; bin/fm-crew-state.sh base-scout), then re-run teardown once the copy is on its owning task's branch.
EXIT=1
```

## S5: copy on live task base-scout's recorded branch -> teardown stale-a closes only stale-a, slot stays with owner, not recycled
```
$ bin/fm-teardown.sh stale-a
fm-gate-refuse: gate agent lifecycle permitted only against lab home /tmp/fm-lab.gk10sP
warning: task stale-a's recorded worktree /tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj is task base-scout's copy - it is on base-scout's recorded branch 'fm/base-scout' - so only stale-a's own record is closed; the slot, its copy, and task base-scout's record are left untouched, and the slot is not returned to the pool.
warning: task stale-a's recorded worktree /tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj was reassigned to task base-scout (home /tmp/fm-lab.gk10sP), which claimed that pool slot after this record was written; that slot is no longer stale-a's, so its processes, copy, and claim are left untouched and only stale-a's own cleanup runs.
/tmp/fm-lab.gk10sP/work/proj: already current
teardown stale-a complete (window primary:fm-stale-a; pool slot /tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj left with task base-scout (home /tmp/fm-lab.gk10sP) and not returned to the pool)
Backlog: stale-a just finished (this home keeps no markdown backlog at /tmp/fm-lab.gk10sP/data/backlog.md). Update /tmp/fm-lab.gk10sP/data/backlog.md - move stale-a to Done, keep Done to the 10 most recent, then re-scan Queued and dispatch only work whose blockers are gone and date is due.
EXIT=0
after: state = base-scout.meta live-scout.meta; slot1 on fm/base-scout; owner-sentinel present; base-scout.meta byte-identical; slot1 in-use; .fm-slot-owner task=base-scout; base-scout pane still claude
```

## S6: relaunch again after reconcile succeeds
```
fm-gate-refuse: gate agent lifecycle permitted only against lab home /tmp/fm-lab.gk10sP
fm-gate-refuse: gate agent lifecycle permitted only against lab home /tmp/fm-lab.gk10sP
relaunched base-scout harness=claude from=claude model=default effort=default backend=tmux endpoint=primary:fm-base-scout worktree=/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/1/proj
EXIT=0
```

## S7: cross-home - a registered local secondmate home's record naming live-scout's slot blocks relaunch
```
$ bin/fm-control.sh live-scout relaunch --note 'lab probe'
fm-gate-refuse: gate agent lifecycle permitted only against lab home /tmp/fm-lab.gk10sP
error: task live-scout's recorded worktree /tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj is also task sm-stale's recorded copy (/tmp/fm-lab.gk10sP/work/pool/.treehouse/proj-54e558/2/proj); refusing to relaunch into a colliding worktree. Read task sm-stale's current state with bin/fm-crew-state.sh sm-stale; when task sm-stale is the stale one, close it with bin/fm-teardown.sh sm-stale (it leaves a copy on task live-scout's branch with task live-scout), then relaunch again
EXIT=1
```
