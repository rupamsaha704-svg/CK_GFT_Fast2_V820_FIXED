# SESSION EXPORT PROMPT — paste this into EACH of your other Kiro sessions

> I (the user) have many separate Kiro sessions, each holding different work and data. A Kiro
> session cannot read another session's history, so I must export each one myself. Open EACH old
> session and paste the fenced block below as a message. That session's agent will read its OWN
> history and save a complete, honest handoff into the GitHub repo (or print it for me to save),
> so nothing is lost when my access ends. Do this once per session.

```
You are ONE of my many Kiro sessions. I am about to lose access (free quota ending), so I am
consolidating the work from ALL my sessions into a single GitHub repository. Your job right now is
to EXPORT everything important from THIS session so a future agent can recover it. Be thorough and
completely honest — do not fabricate, do not summarise away important detail, do not invent results.

REPO (my consolidation target): https://github.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED
BRANCH to write to: kiro/validation-toolkit   (if you cannot reach/clone it, see FALLBACK below)

STEP 1 — Read THIS session's full conversation history and gather, honestly and in detail:
  1. PURPOSE: what this session was about (the goal / strategy / task).
  2. KEY DECISIONS: every important decision, rule, or conclusion we reached (and why).
  3. CODE & FILES: every script/EA/config/file produced here. Include the FULL file contents if
     they are not already saved in a git repo (do not truncate — this may be the only copy).
  4. DATA: any datasets, numbers, backtest/validation results, metrics, parameters, or settings.
  5. STRATEGY RULES: any trading-setup rules, entry/SL/TP logic, timeframes, sessions, symbols.
  6. MY INSTRUCTIONS/PREFERENCES: anything I asked you to remember or always do.
  7. UNFINISHED WORK: what was in progress, what the next steps were, any open questions.
  8. WARNINGS: any bugs, caveats, or mistakes discovered here that a future agent must know.

STEP 2 — WRITE the export:
  - Create a file in the repo at:  docs/session_exports/SESSION_<short-unique-name>.md
    (choose a short descriptive name from this session's topic, e.g. SESSION_gold_scalper_v3.md).
  - Put ALL of STEP 1 into it, well-organised with headings, in enough detail that someone with
    NO access to this chat could fully understand and continue the work.
  - Commit it and push to branch kiro/validation-toolkit.
     (CSV/data files may be gitignored; if so, use `git add -f` so the data is preserved too.)
  - If a hash-chained ledger exists at SPEC/dof_ledger.py, append one record noting this export
    and run its `verify`.

STEP 3 — Confirm to me (in Bengali) the exact file path you wrote and that the push succeeded.

FALLBACK (if you cannot access git / the repo from this session):
  Print the ENTIRE STEP 1 export as one long, self-contained Markdown document directly in the
  chat, with clear START/END markers, so I can copy it and upload it to the repo myself. Do NOT
  shorten it — completeness matters more than brevity here.

RULES: be exhaustive and truthful; never fabricate a result or a number; if something is uncertain,
say so plainly; respond to me in Bengali. This export is the only thing that will survive, so
capture everything of value.
```
