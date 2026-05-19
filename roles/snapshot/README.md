# snapshot

Creates timeshift rsync-mode snapshots so a broken `make site` run can be
reverted in place via `make rollback`. **Local-disk only** — not a
disaster-recovery tool. Pair with the `backup` role for off-host
incremental backup.

## What it does

- `apt install timeshift`
- Writes `/etc/timeshift/timeshift.json` with this collection's excludes
  and retention.
- Runs `timeshift --create --tags <tag> --comments <text>`.

Default excludes:

- `/opt/vllm/hf-cache/**` (HF model cache — borg handles this)
- `/var/lib/docker/**` (container images — regenerable)
- `/var/lib/rancher/k3s/agent/containerd/**` (k3s image store)

## Variables

| Var | Default | Notes |
|---|---|---|
| `snapshot_enabled` | `true` | Master gate; `site.yml` imports the snapshot playbook and respects this. |
| `snapshot_comment` | `"ansible-pre-site"` | Free-form comment stored with the snapshot. |
| `snapshot_tag` | `"D"` | timeshift tag. Use `"O"` to mark a snapshot "Keep forever" (`setup.yml` uses this). |
| `snapshot_excludes` | see defaults | Paths excluded from the snapshot. |
| `snapshot_retention` | `{daily: 5, weekly: 2, monthly: 1, boot: 5}` | Counts used by timeshift's rolling pruner. |
| `snapshot_target` | `"latest"` | **Rollback only.** Either `"latest"` or an explicit snapshot name. |

## Rollback

`tasks/rollback.yml` is invoked by `playbooks/rollback.yml`:

```bash
make rollback                                # rolls back to the newest snapshot
make rollback ASK='-e snapshot_target=clean-baseline'  # roll back to baseline
```

The restore step reboots the host. SSH will drop. Reconnect after roughly
two minutes.

## Notes

- The role does NOT enable timeshift's own cron schedule — snapshots are
  taken by Ansible (pre-`site.yml` and on-demand via `make snapshot`).
- For DGX hosts on btrfs or ZFS root, swap the rsync mode out separately;
  the current scaffold targets stock DGX OS (ext4).
