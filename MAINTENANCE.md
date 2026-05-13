# Maintenance budget

The ongoing time cost of running Think OS is low by design.

- **Daily** (free): the Stop hook auto-logs your sessions to `01 Now/Work Log.md`. You do nothing.
- **Weekly** (~5 min): `/weekly-review` rolls over `01 Now/Current Focus.md`. Run it manually or schedule in desktop agent.
- **Quarterly** (~30 min): `/quarterly-review` archives the Work Log, audits projects, prunes connectors. Hand-curate.
- **On-demand freshness check**: `/thinkos-stale` walks all HOT/WARM files and flags anything past its review window.
- **Annually** (~60 min): hand-review `05 Profile/Identity.md` and `05 Profile/Business Brain.md`. Slow-changing things benefit from deliberate review.
