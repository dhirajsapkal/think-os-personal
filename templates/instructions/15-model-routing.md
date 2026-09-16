# Right Model for the Task

Match the model to what the task actually requires. The useful split is not "hard vs easy" — it is **where the answer lives**.

| Kind | The job is | Use |
|---|---|---|
| **Extraction** | The answer is already in the input. Find it, shape it, drop the rest. | Haiku |
| **Judgment** | The input does not state the answer. Decide what matters, what duplicates what, what to propose. | Sonnet |
| **Deliberation** | Multi-step reasoning where a wrong call is expensive and not obviously wrong. | Opus |

The line is sharper than it sounds. Pulling "who said they'd do what" out of a meeting transcript is extraction. Deciding which of those commitments is already tracked, and which matters this week, is judgment.

**The test that actually works:** ask whether the input states the answer *unambiguously*. Not whether the output looks like a summary — summarisation is where this misleads most often.

A worked example from this repo. Session checkpointing reads a transcript and writes a structured summary, which looks like textbook extraction. It is not: a transcript describes what was *proposed* in the same confident past tense as what was *done*, and separating those is a judgment call on every line. Measured on one slice with one prompt, Haiku ignored the required headings and asserted a version bump, a benchmark result and a token count that had never happened. Sonnet used the headings and every item traced to something real. The task was reclassified.

## Applying it

- **Summarising, reformatting, classifying against a fixed list, pulling structured fields out of an API response** → Haiku. These are the bulk of background work.
- **Synthesis, proposing priorities, semantic dedup, anything a person would call a judgment call** → Sonnet.
- **Architecture decisions, ambiguous tradeoffs, debugging something that has already resisted one attempt** → Opus.
- **Deterministic work — reindexing, file moves, checksum comparison** → no model at all. Write the shell or Python instead. A model call for work a script does exactly is pure cost and adds a failure mode.

## For scheduled work

`scripts/lib/model-routing.sh` holds the per-task table and is the single place to change it. `thinkos-cron-run.sh` reads it automatically. Inspect it with:

```bash
bash scripts/lib/model-routing.sh          # whole table
bash scripts/lib/model-routing.sh granola  # one task
```

Override per run without editing the table:

```bash
THINKOS_MODEL_WEEKLY_REVIEW=opus bash scripts/thinkos-cron-run.sh weekly-review
```

## When delegating to a subagent

The same split applies, and the `model` parameter takes `haiku`, `sonnet`, or `opus`. A subagent that reads a large corpus and returns a summary should be Haiku — that is most research fan-out. A subagent asked to review a plan or find a subtle bug should not be.

## The failure to avoid

Reaching for the largest model by default is the expensive mistake, but the reverse matters too: using Haiku for something that needs judgment produces confident, plausible, wrong output — and that costs more to unpick than the tokens saved. When a task's output will be **trusted without review**, weight toward the stronger model.
