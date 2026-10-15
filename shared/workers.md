# Where the work runs

Every wf skill is started where the user talks — a normal session or a Claude Code **Projects
coordinator** — and that place stays the **lead**: it talks with the user, decides, hands out work
and collects the results. Work that needs no conversation goes to **workers**.

## The workers you have
- **Projects coordinator** (you can start threads and route work to them): **threads** are the
  workers for repository work — each a cloud session on its own branch that loads the project's
  plugins (wf must be added in Project settings › Plugins) and can spawn its own subagents, so the
  critic runs inside the thread. Where you cannot read or change the repository yourself, a thread
  does it and reports.
- **Normal session:** **subagents** (the Agent tool; an isolated worktree when they edit), or you.

## Rules
- **Talking stays with the lead.** A thread's questions and approvals wait inside that thread, and
  nothing said to the lead reaches them. So every worker gets what it needs up front and runs
  **unattended**: it takes the least invasive reading, lists its assumptions, and returns open
  questions in its report instead of asking.
- **A brief stands alone:** what to run — for a thread the wf skill by name (`wf:deliver` …), for a
  subagent the skill file's absolute path —, the inputs, the original bar in full, that it runs
  unattended, the concurrency it may use itself (none unless stated), and what to report (verdicts,
  gate line with test counts, commits or PR, open findings and questions).
- **Cut by files, not by count.** Pieces that share files go to one worker, in order; independent
  pieces may run at once, never more workers than the concurrency limit (default 2, or what the
  user said). A follow-up goes to the thread already working in that area. Small things the lead
  does itself — every worker starts with a fresh context and that costs.
- **Landing.** Threads land work as pull requests. Merging is the user's call unless they
  authorised it; then tell the thread to merge, earliest dependency first, later ones rebased.
- **Plugin missing in a thread** (wf not added to the project): say so once, and put the skill's
  procedure into the brief instead.
