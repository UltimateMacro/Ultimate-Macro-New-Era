# Strategy Lab Spatial Actions Plan

1. Add a tested parser/rewriter for coordinate-bearing tower actions: `CloneTower`, `BrawlerReposition`, and `EnforcerReposition`.
2. Extend Strategy Lab visual mode with a dedicated Actions overlay/table so destination coordinates can be selected, dragged, edited numerically, undone/redone, and saved back to the original `.strat` command without touching unrelated arguments.
3. Keep placement collision/range logic isolated from action destinations; actions are visual/editing metadata only.
4. Wire the new UI assets into editor packaging/updater contracts and bump Strategy Lab to v4.4.
5. Add regression tests/contracts, run JavaScript/PowerShell/AHK validation and the existing self-test, then open a draft PR for manual UI QA before merge.

Rollback: revert the feature commits or close the draft PR. No runtime tower behavior is changed by this branch.