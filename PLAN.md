# v1.3.5 Upgrade Hotfix Plan

1. Reproduce the failure path from source and harden upgrade affordability detection so red/grey upgrade controls cannot be accepted from a stray green pixel.
2. Strengthen post-input confirmation so transient UI/hover changes cannot advance the macro's internal tower level.
3. Add focused regression contracts for the affordability gate and persistent confirmation behavior.
4. Run repository/self-test validation and inspect the exact diff before opening a PR.
5. Keep the archived v1.3.5 release untouched until live Roblox QA covers no-money state with TimeScale OFF and 2x.

Rollback: revert the runtime/test commit(s) on this branch. No production branch, tag, or release asset will be modified by this work before QA.
