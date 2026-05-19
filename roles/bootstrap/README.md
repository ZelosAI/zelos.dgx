# bootstrap

One-shot role that prepares a fresh DGX-class host for unattended Ansible runs.

Run as the OS-default admin user (e.g. `ubuntu` on DGX OS) with `--ask-pass
--ask-become-pass`. It creates a dedicated `ansible` user, installs an SSH
public key from the control node, and grants NOPASSWD sudo. Every other
playbook in this collection then connects as the new `ansible` user
non-interactively.

## What it does NOT do

- It does **not** lock down or modify the original admin account. The admin
  remains usable as a recovery path if the ansible key is ever lost.
- It does **not** touch the firewall, SSH config, or anything else outside
  of `bootstrap_user` setup.

## Required variables

| Var | Notes |
|---|---|
| `bootstrap_authorized_keys_file` | Absolute path on the control node to a single SSH public key file (e.g. `~/.ssh/id_ed25519.pub`). |

## Optional variables (see `defaults/main.yml`)

| Var | Default | Notes |
|---|---|---|
| `bootstrap_user` | `ansible` | Account to create. |
| `bootstrap_user_groups` | `[sudo]` | Supplementary groups. |
| `bootstrap_user_shell` | `/bin/bash` | Login shell. |
| `bootstrap_sudoers_nopasswd` | `true` | Drop `/etc/sudoers.d/90-ansible-bootstrap` granting `NOPASSWD: ALL`. |

## Typical invocation

```bash
cp inventory/bootstrap.example.yml inventory/bootstrap.yml
$EDITOR inventory/bootstrap.yml      # set ansible_host, ansible_user, key path
ansible-playbook -i inventory/bootstrap.yml playbooks/bootstrap.yml \
  --ask-pass --ask-become-pass
```

After this succeeds, switch to the main `inventory/hosts.yml` (which uses
`ansible_user: ansible`) and proceed with `make setup`.
