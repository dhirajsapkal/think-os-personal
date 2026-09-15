# Maintenance budget

The ongoing time cost of running Think OS is low by design.

- **Daily** (free): a launchd session-capture job appends a one-line stub to `01 Now/Work Log.md` every 2h during work hours. You do nothing. Toggle with `/thinkos-autosave`.
- **Weekly** (~5 min): `/weekly-review` rolls over `01 Now/Current Focus.md`. Run it manually or via the scheduled launchd job installed by `/thinkos-automate`.
- **Quarterly** (~30 min): `/quarterly-review` archives the Work Log, audits projects, prunes connectors. Hand-curate.
- **On-demand freshness check**: `/thinkos-refresh` walks HOT/WARM files and flags anything past its review window. `/thinkos-vitals` gives a broader health snapshot — staleness, line-count budgets, unreviewed autocaptures, broken cross-links, and ledger volume.
- **Install health**: `/thinkos-doctor` spot-checks that scripts, launchd jobs, MCP config, and Basic Memory are wired correctly. Run after any OS update or if something feels off.
- **Annually** (~60 min): hand-review `05 Profile/Identity.md` and `05 Profile/Business Brain.md`. Slow-changing things benefit from deliberate review.
