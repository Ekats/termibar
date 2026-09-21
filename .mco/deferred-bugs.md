# Deferred Bugs

Bugs found *on the way* to a task — parked here so the task stays on the happy path.
This file is the single home for "noticed but not now." It is a triage queue, not a fix log.

## Protocol (agents follow this — no exceptions)

1. **Find a bug mid-task → append ONE line to the log below** (date, one-sentence symptom + `file:line`). That's it. Do **not** fix it, investigate it, or replan the task around it.
2. **Stay on the happy path.** Finish and report the task you were actually given.
3. **At the end of the task, list the deferred bugs you logged** (in your final report). Also surface one *earlier* if it becomes directly relevant to the current task — a one-line "note: this touches deferred bug X" is enough.
4. **Never fix a deferred bug unless explicitly asked.** The human triages this list during review — right after the task's data/deliverable lands. Fixing out of order is how a task gets lost.

A bug on the way is a **note**, not a detour. One line here beats a five-file tangent every time.

## Log

| id | date | status | bug |
|----|------|--------|-----|
