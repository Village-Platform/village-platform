# Backlog sync

`backlog.json` is the roadmap backlog (16 phases and tracks, 162 issues). `sync.rb` creates it on
GitHub:

| Where | What |
|---|---|
| `village-platform/village-platform` | 16 epics + 136 backend, dashboard, data and setup issues |
| `village-platform/aghour-android` | 1 epic + 9 Android issues (Phase 12 client work and the pilot release) |
| Both repositories | Labels (`type:`, `priority:`, `size:`, `horizon:`, `area:`, `phase:`), one milestone per phase |
| Owner `village-platform` | Project board **Aghour village platform** with `Priority`, `Size` and `Phase` fields, both repositories linked |

Every issue is a sub-issue of its phase epic. The `Depends on` / `Blocks` sections link the real
issue numbers, and links across the two repositories use `owner/repo#n`. Issues that are already
done are created and then closed as completed, so the history is still there.

## Run it

```bash
gh auth login                 # an account with write access to both repositories
gh auth refresh -s project    # the project commands need this scope
ruby scripts/backlog/sync.rb --dry-run   # prints what it would create
ruby scripts/backlog/sync.rb
```

Options: `--owner NAME`, `--project "Title"`, `--skip-project`.

It is safe to run again. Labels and milestones are matched by name and issues by exact title,
and only what is missing gets created. Bodies are rewritten only when they differ from
`backlog.json`. So when you rename an issue on GitHub, rename it in `backlog.json` too, or the next
run creates a duplicate.

A run takes about three minutes, because it waits one second after each issue to stay under
GitHub's rate limit for creating content.

## After the run (web UI only)

- Project views: Board (by Status), Roadmap, By phase (group by `Phase`), Blocked, My work.
- Project workflows: auto-add from both repositories, item closed → Done, PR merged → Done.
