# backup

Configures a daily, incremental, deduplicated, encrypted borg backup with
support for **four** repo locations: SSH, local disk, NFS share, SMB
(Samba/CIFS) share. Runs via a systemd timer; the wrapper exit-codes are
visible in `systemctl status borg-backup.service` / `journalctl -u`.

Complements the `snapshot` role:

- `snapshot` = on-host timeshift, fast in-place rollback for a broken
  `make site`. Doesn't survive disk loss.
- `backup` = off-host borg repo. Survives full system wipe. Restore is
  an extract-then-copy process, not in-place.

## Repo modes

| `borg_repo_mode` | What you set | What the role does |
|---|---|---|
| `ssh` | `borg_repo: user@host:/path/<hostname>` | borg dials SSH directly. No mount step. |
| `local` | `borg_repo:` empty → `/var/backup/borg/<hostname>` (or your override) | Local disk. Useful for testing only — defeats the off-host goal. |
| `nfs` | `borg_nfs_share: nas:/export/borg`, `borg_mount_point: /mnt/borg-repo` | Mounts the NFS share via `ansible.posix.mount` (persists across reboot), then uses `<mount>/<hostname>` as the repo. |
| `smb` | `borg_smb_share: //nas/borg`, `borg_smb_username`, `vault_borg_smb_password` | Writes `/etc/borg-smb-credentials` (0600), mounts via `cifs-utils` with `credentials=...` (never inline). |

## Encryption

Default: `repokey-blake2`. The passphrase comes from
`vault_borg_passphrase` (required unless `borg_encryption: none`). The
role writes `/etc/borg/passphrase` (0600 root) and the wrapper reads it
at runtime — `BORG_PASSPHRASE` is set inside the script, never in unit
files or `ps` output.

> **Lose the passphrase = lose the data.** Back up
> `vault_borg_passphrase` to a password manager / paper — separately
> from the host.

## What gets backed up

Default paths:

- `/etc`
- `/opt` (includes `/opt/vllm` + the HF model cache — borg's dedup
  makes this cheap after the first run)
- `/var/lib`
- `/home`

Default excludes:

- `/var/lib/docker/{tmp,overlay2}/**` (regenerable; image layers in
  `/var/lib/docker/image/**` ARE captured)
- `/var/cache/**`, `/var/tmp/**`, `/tmp/**`
- `/opt/vllm/hf-cache/**/.lock`

## Schedule

systemd timer `borg-backup.timer`, default `OnCalendar=daily`,
`RandomizedDelaySec=30m`, `Persistent=true` (missed runs catch up).
Bump `borg_schedule` for a different cadence.

## Restore

```bash
borg list <repo>                             # see archives
make backup-restore ARCHIVE=<archive-name>   # extracts to /var/restore/<archive>
```

Files land in `borg_restore_target/<archive>` — inspect, then copy into
place by hand. For a full-system restore boot a rescue environment and
extract the whole tree.

## First run

`borg_run_now` defaults to **false** so the first (and largest) borg
create doesn't accidentally happen mid-`make site`. Two ways to kick
the first run:

```bash
make backup-now              # one-shot
# OR
make setup                   # captures clean baseline + first full borg backup
```

After the initial full upload, every subsequent run only ships changed
chunks (incremental + dedup).
