# CLAUDE.md

> **Note for Claude sessions:** this file follows the Zelos suite-wide template
> from [zelosai/docs/template/CLAUDE.md.tmpl](https://github.com/ZelosAI/zelosai/blob/main/docs/template/CLAUDE.md.tmpl).
> The canonical gitflow rules every Zelos repo follows live in
> [zelosai/docs/architecture/05-gitflow.md](https://github.com/ZelosAI/zelosai/blob/main/docs/architecture/05-gitflow.md).

## Repository

- **Repo:** `ZelosAI/zelos.dgx`
- **Image:** `ghcr.io/zelosai/zelos.dgx` (multi-arch `linux/amd64` + `linux/arm64`)
- **Collection FQCN:** `zelos.dgx`
- **Purpose:** Provision headless NVIDIA DGX-class workstations (Lenovo PGX,
  DGX Station, DGX Spark) running DGX OS, so the box is reachable remotely
  for (1) Sunshine/Moonlight remote desktop and (2) vLLM AI model serving.
  All access is over Tailscale. The collection also delivers a
  [`zelosclient`](https://github.com/ZelosAI/zelosclient) container onto the
  provisioned host (plain docker-compose / systemd, NOT a Kubernetes
  workload) wired to the suite-wide
  [`zelosbackplane`](https://github.com/ZelosAI/zelosbackplane).
- **State:** **v0.2.0** scaffold (per `galaxy.yml`). Roles, playbooks, and
  the `zdgx` CLI are implemented; CI runs `yamllint` + `ansible-lint` +
  per-playbook `--syntax-check` on every push. **Not yet validated
  end-to-end against real DGX hardware.**

## Active Branch

- Work on: `claude/claude-md-docs-0wYXt`

## Layout

```
zelos.dgx/
├── README.md                       # public entry point + provisioning Mermaid
├── CLAUDE.md                       # this file
├── CHANGELOG.md                    # Keep-a-Changelog
├── ROADMAP.md                      # in-flight / next / backlog / shipped, links to tracker
├── LICENSE                         # Apache-2.0
├── ansible.cfg                     # inventory=inventory/hosts.yml, roles_path=roles
├── galaxy.yml                      # namespace=zelos, name=dgx, version=0.2.0 (release source of truth)
├── pyproject.toml                  # `zdgx` CLI package (host-installable + container ENTRYPOINT)
├── Dockerfile                      # python:3.12-slim + ansible 9.5 + ansible-lint + the zdgx CLI
├── Makefile                        # build / run-shell / dev-shell (container only)
├── meta/runtime.yml                # requires_ansible >=2.15
├── requirements.yml                # community.general / ansible.posix / community.docker
├── cli/zdgx/                       # Typer CLI source (app.py, runner.py, __main__.py)
├── scripts/
│   └── mirror_push.py              # force-mirror repo (all branches + tags) to another remote
├── .github/workflows/
│   ├── lint.yml                    # yamllint + ansible-lint + per-playbook syntax-check
│   ├── docs.yml                    # mermaid block validation (mermaid-cli on Node 20)
│   ├── release.yml                 # multi-arch GHCR push from develop/main/v* tags
│   ├── release-tag.yml             # auto-tag `v<X.Y.Z>` from galaxy.yml on main push, GH Release
│   ├── add-to-project.yml          # auto-add new issues to Zelos Platform Tracker (project #2)
│   └── tracker-ready-for-qa.yml    # auto-transition linked issues on develop build success
├── playbooks/
│   ├── site.yml                    # imports snapshot.yml + the rest
│   ├── bootstrap.yml               # create the `ansible` user (run once, --ask-pass)
│   ├── setup.yml                   # baseline: full borg backup + clean-baseline snapshot
│   ├── snapshot.yml                # timeshift snapshot (pre-site or ad-hoc)
│   ├── rollback.yml                # timeshift restore (reboots host)
│   ├── backup.yml                  # borg config + systemd timer
│   ├── backup_restore.yml          # borg extract → /var/restore/<archive>
│   ├── nvidia_verify.yml
│   ├── base.yml                    # docker + tailscale
│   ├── remote_desktop.yml          # virtual_display + sunshine
│   ├── ai_serving.yml              # docker + vllm
│   ├── k3s.yml                     # opt-in, gated by k3s_gpu_install
│   ├── monitoring.yml
│   └── tailscale.yml
├── inventory/
│   ├── hosts.yml                   # main inventory (ansible_user=ansible after bootstrap)
│   ├── bootstrap.example.yml       # one-time bootstrap inventory (ansible_user=ubuntu)
│   ├── vault.example.yml           # template → copy to group_vars/all/vault.yml
│   └── group_vars/all/main.yml     # all knobs (snapshot_*, backup_*, vllm_*, ...)
├── docs/
│   ├── openai-client.example.py
│   └── prometheus-scrape.example.yml
└── roles/
    ├── bootstrap/                  # creates the `ansible` user + key + NOPASSWD sudo
    ├── snapshot/                   # timeshift snapshot (create + rollback tasks)
    ├── backup/                     # borg daily backup; ssh/local/nfs/smb repo modes;
    │                               # /etc/borg/{passphrase,excludes}, borg-backup.sh + systemd timer
    ├── nvidia_verify/              # nvidia-smi + driver version assert
    ├── docker/                     # docker-ce + compose plugin + nvidia-container-toolkit;
    │                               # /etc/docker/daemon.json with nvidia default runtime
    ├── tailscale/                  # apt install + `tailscale up --authkey --ssh` (idempotent)
    ├── virtual_display/            # generates EDID via files/gen_edid.py; installs
    │                               # /etc/X11/xorg.conf.d/10-nvidia-headless.conf; enables lightdm
    ├── sunshine/                   # downloads .deb; systemd USER unit (X session visibility);
    │                               # enables loginctl linger
    ├── vllm/                       # /opt/vllm with docker-compose.yml + vault'd .env;
    │                               # vllm/vllm-openai with runtime: nvidia; /v1/models health check
    ├── k3s_gpu/                    # opt-in k3s install + optional NVIDIA k8s device plugin
    └── monitoring/                 # node_exporter binary + systemd; dcgm-exporter container
```

## Operator flow

All operator actions go through the `zdgx` CLI (a Typer app installed
into the container as ENTRYPOINT, also installable on the host via
`pip install -e .`). The Makefile is now just for the container image:
`make build`, `make run-shell`, `make dev-shell`.

```
zdgx bootstrap   # one-time, interactive (admin user + password)
zdgx setup       # one-time: full borg backup + clean-baseline snapshot
zdgx site        # repeatable; pre-flight snapshot taken each run
```

`zdgx --help` lists every subcommand. Common global options:
`-i/--inventory`, `--vault-password-file`, `--limit`, `--check`, `-v`,
`-e/--extra-vars`.

Recovery hierarchy:

- bad `zdgx site` run → `zdgx rollback` (latest pre-flight snapshot)
- cumulative drift → `zdgx rollback --target clean-baseline`
- disk loss → reinstall OS, `zdgx bootstrap`, restore with `zdgx backup-restore --archive <name>`

The two safety nets are deliberately separate. **timeshift** is local
snapshot for in-place rollback; **borg** is off-host
deduplicated/encrypted incremental backup to ssh/local/nfs/smb repo
with a systemd `daily` timer. Lose the disk → borg restore. Break a
config → timeshift rollback.

## How to run it / How to build it

There are three equivalent workflows: host-installed CLI, prod-like
container shell (`run-shell`), and live-edit container shell
(`dev-shell`). The container is the recommended path because it pins
Ansible + dependencies; the host install is convenient for ad-hoc work.

### Setup (one-time)

```bash
git clone https://github.com/ZelosAI/zelos.dgx.git
cd zelos.dgx

# Inventory + vault (always required, however you run zdgx)
cp inventory/bootstrap.example.yml inventory/bootstrap.yml
vim inventory/bootstrap.yml            # admin user, host, key path
vim inventory/hosts.yml                # confirm ansible_host
cp inventory/vault.example.yml inventory/group_vars/all/vault.yml
ansible-vault encrypt inventory/group_vars/all/vault.yml
```

### Workflow A: host-installed CLI

```bash
python3 -m venv venv && source venv/bin/activate
pip install -e .                       # installs the zdgx CLI
pip install ansible ansible-lint yamllint
zdgx deps                              # community.general / posix / docker

zdgx bootstrap                         # prompts for admin SSH + sudo password
zdgx ping                              # smoke test as `ansible`
zdgx setup                             # baseline snapshot + first full borg backup
zdgx site                              # repeatable full provision
```

### Workflow B: container, prod-like (`make run-shell`)

```bash
make build
make run-shell                         # bash inside the container, RO inventory + vault
# inside the container:
zdgx site
```

`make run-shell` mounts your inventory + vault read-only at the
container paths Ansible expects. Override `INVENTORY_FILE` /
`SECRETS_FILE` / `SSH_DIR` on the make line to point elsewhere.

### Workflow C: container, live edits (`make dev-shell`)

```bash
make build                             # only when image deps change
make dev-shell
# inside the container:
zdgx --help                            # reflects any change you make on the host
zdgx setup --check                     # dry run
```

`dev-shell` bind-mounts the current repo over `/workspace` *and* over
the collection install path (`/usr/share/ansible/collections/...`), so
role/playbook/CLI edits on the host take effect immediately without a
rebuild.

### One-shot (no shell)

The container's ENTRYPOINT is `zdgx`:

```bash
docker run --rm \
  -v $PWD/inventory/hosts.yml:/workspace/inventory/hosts.yml:ro \
  -v $PWD/inventory/group_vars/all/vault.yml:/workspace/inventory/group_vars/all/vault.yml:ro \
  -v $HOME/.ssh:/home/ansible/.ssh:ro \
  ghcr.io/zelosai/zelos.dgx:latest setup --check
```

## What has been verified / What has NOT been verified

### Verified

- `gen_edid.py` outputs a valid 128-byte EDID 1.3 (header OK, checksum
  OK, preferred timing for 4K60 produces correct CVT-RB 533.25 MHz
  pixel clock).
- `yamllint .` is clean.
- CI (`.github/workflows/lint.yml`) runs `yamllint`, `ansible-lint`,
  and per-playbook `--syntax-check` on every push and PR; current
  `main` is green.
- `.github/workflows/release.yml` builds and pushes multi-arch images
  (`linux/amd64` + `linux/arm64`) to `ghcr.io/zelosai/zelos.dgx` on
  every push to `develop`, every push to `main`, and every `v*` tag.

### NOT verified

- **Nothing has run against a real DGX host.** Expect to iterate on
  the first `zdgx site`.
- Sunshine first-boot may need an interactive login as `sunshine_user`
  before the user systemd service starts cleanly (documented in role
  README).
- The EDID generator produces a structurally valid EDID but isn't
  bit-accurate to any real panel. If the NVIDIA driver rejects it,
  swap in a known-good EDID dump from a Dell U2718Q or similar 4K
  panel.
- For DGX A100/H100 datacenter cards with no display outputs, the
  `virtual_display` approach won't work — use Xvfb/VirtualGL instead.
- The promised `zelosclient` container delivery role does not yet
  exist; the collection currently provisions vLLM + Sunshine + Docker
  but not the suite-wiring container.

## Configuration surface (most likely tweaks)

All knobs in `inventory/group_vars/all/main.yml`:

- `vllm_model`, `vllm_served_model_name`, `vllm_tensor_parallel_size`,
  `vllm_max_model_len`, `vllm_gpu_memory_utilization`
- `virtual_display_width/height/refresh`
- `sunshine_version`, `sunshine_user`
- `k3s_gpu_install` (opt-in), `k3s_gpu_operator_install`
- `monitoring_bind` (loopback by default; flip to Tailscale IP for
  remote scraping)
- `tailscale_ssh`
- `snapshot_enabled`, `snapshot_excludes`, `snapshot_retention`
- `backup_repo_mode` (ssh|local|nfs|smb), `backup_repo`,
  `backup_nfs_share` / `backup_smb_share`, `backup_schedule`,
  `backup_encryption`, `backup_compression`

Vault secrets in `inventory/group_vars/all/vault.yml` (gitignored,
encrypt with `ansible-vault`):

- `vault_tailscale_auth_key`
- `vault_hf_token` (for gated HF models like Llama)
- `vault_vllm_api_key`
- `vault_k3s_token` (only if `k3s_gpu_install: true`)
- `vault_borg_passphrase` (back this up off-host — lose it = lose the backups)
- `vault_borg_smb_password` (only if `backup_repo_mode: smb`)

## Git / Workflow

### Branch model

- `main` is the protected release line. Every merge to `main` is a
  release and gets tagged `v<major>.<minor>.<patch>` automatically by
  `.github/workflows/release-tag.yml`, which reads the version from
  `galaxy.yml`. The version field in `galaxy.yml` is the source of
  truth — never tag manually.
- `develop` is the integration line. Features land here continuously.
- Feature branches are named `claude/<session-slug>` (when the
  harness sets one) or `feature/<plan-name>` for human-initiated work,
  cut from the live tip of `origin/develop`. Never reuse a feature
  branch from a previous plan.

### Starting work

```
git fetch origin
git checkout -b claude/<session-slug> origin/develop
```

Never start work directly on `develop` or `main`.

### Completing work (feature → develop)

1. Commit with clear, descriptive messages.
2. Push: `git push -u origin claude/<session-slug>`.
3. Open a PR into `develop` with a meaningful title and a Summary +
   Test plan body. Include `Closes #<N>` when the work resolves a
   tracked issue. Do this without waiting to be asked — the PR is
   part of "work complete."
4. Enable auto-merge with squash:
   `gh pr merge --auto --squash --delete-branch`. This waits for the
   required `lint` check (yamllint + ansible-lint + syntax-check) to
   pass green, then squash-merges and deletes the remote branch. The
   user does **not** need to review feature → develop PRs.
5. If CI fails, fix the issue on the same branch and let auto-merge
   retry. Do not force-merge.

### Cutting a release (develop → main)

Only when the user explicitly asks ("cut a release", "ship develop",
etc.). Never proactive.

1. Inspect what's landed: `git log v<last-tag>..origin/develop`
   (or `main..develop` if no tags yet).
2. Propose a semver bump from `galaxy.yml`'s current `version:`:
   - **patch** — bug fixes, doc updates, internal cleanup
   - **minor** — new roles, new playbooks, new configuration knobs
   - **major** — breaking changes to inventory variables, role
     interfaces, or operator-facing commands
3. Branch `release/v<X.Y.Z>` from `origin/develop`, bump
   `galaxy.yml`'s `version:`, PR into `develop`, and auto-merge it
   (same as any feature). This keeps develop and main in sync on
   versioning.
4. Then PR `develop` → `main`. Title: `Release v<X.Y.Z>`. Body:
   summary of changes since the last release. **Never auto-merge.**
   The user reviews and merges.
5. Use a *merge commit* (not squash) for develop → main so the
   release boundary is a single visible merge on main, and so
   GitHub's `Closes #N` auto-close fires for each PR squashed into
   develop.
6. The `release-tag` workflow runs on the resulting push to `main`,
   creates the `v<X.Y.Z>` tag, and publishes a GitHub Release with
   auto-generated notes.
7. Back-merge `main → develop` to absorb the release merge commit.

### Hard rules

- Never PR a feature branch directly into `main`.
- Never push directly to `develop` or `main`.
- Never auto-merge anything into `main`.
- If `develop` does not exist on the remote, create it from `main`
  before opening the first feature PR.

### Container builds

`.github/workflows/release.yml` builds and pushes multi-arch images
(`linux/amd64` + `linux/arm64`) to `ghcr.io/zelosai/zelos.dgx` on
every push to `develop`, every push to `main`, and every `v*` tag
push. The version is read from **`galaxy.yml`** (the Ansible
collection's version field is authoritative — the `pyproject.toml`
for the `zdgx` CLI is a secondary, container-internal concern). Tags
applied:

- **develop push** → `:v<X.Y.Z>-dev` · `:latest` · `:sha-<short>`
- **main push** → `:v<X.Y.Z>` · `:latest` · `:stable` · `:sha-<short>`
- **`v<X.Y.Z>` git tag push** → same as main push, plus validates
  that the tag name matches `galaxy.yml`'s version (build fails if
  they diverge).

`:latest` follows the most recent build of any kind; `:stable` tracks
`main` only.

The existing `.github/workflows/release-tag.yml` (auto-tagger that
creates a `v<X.Y.Z>` git tag from `galaxy.yml`'s version on each
`main` merge) remains in place — it produces the tag that
`release.yml` then responds to. The two workflows are complementary.

## Issue tracking & releases

All features, bugs, and chores in the Zelos suite are tracked in the
org-level GitHub Project [**Zelos Platform Tracker**](https://github.com/orgs/ZelosAI/projects/2).
Every issue opened in any ZelosAI repo auto-adds to the project via
`.github/workflows/add-to-project.yml` (uses the `ADD_TO_PROJECT_PAT`
org secret).

**File issues in the repo they belong to**, not in `zelosai`, unless
the work genuinely spans multiple repos.

**Project fields to set on each item:**

- **Work type** — `Feature` / `Bug` / `Chore`.
- **Priority** — `P0` (drop everything) / `P1` (this sprint) / `P2`
  (this release) / `P3` (someday).
- **Status** — `Todo` / `In Progress` / `Ready for QA` / `Done` /
  `Blocked`. Transitions: `Todo` → `In Progress` is set manually
  when you start work. `In Progress` → `Ready for QA` fires
  **automatically** when the feature → develop PR merges and the
  `release` workflow's dev container build succeeds (see
  `.github/workflows/tracker-ready-for-qa.yml`). `Ready for QA` →
  `Done` fires **automatically** via the project's "Item closed"
  workflow when the linked issue is auto-closed on the develop →
  main promotion (per `Closes #N` in the feature PR body). Use
  `Blocked` (side-state, any phase) when you can't make forward
  progress; note the blocker in the issue.
- **Release** — cross-repo target: `v0.1`, `v0.2`, `v0.3`, `v1.0`,
  or `Backlog`.
- **Milestone** — matching repo-level milestone (same names exist
  in every repo). Keep Milestone and Release in sync so repo-native
  views match the project.

**When to file vs just fix:** if it's a self-contained change you're
about to ship this session, the PR is the record — no issue needed.
File an issue for work that won't ship this session, anything
cross-repo, anything the user asks to track, or follow-ups you
discover but won't do now.

**Linking PRs:** PRs that resolve an issue must include `Closes #N`
(or `Fixes #N`) in the description so GitHub auto-closes the issue
on merge and the project's "Item closed" workflow moves it to `Done`.

## Planning and execution loop

This repo follows a structured planning ↔ execution flow with Claude.
Three artifacts stay in lockstep: the [Zelos Platform Tracker](https://github.com/orgs/ZelosAI/projects/2)
(structured state), this repo's [`ROADMAP.md`](./ROADMAP.md)
(human-readable view of THIS component), and the suite-wide
[`zelosai/ROADMAP.md`](https://github.com/ZelosAI/zelosai/blob/main/ROADMAP.md)
(cross-component view).

### When a plan is accepted (planning → backlog)

The moment `ExitPlanMode` returns user approval, Claude must convert
the accepted plan into trackable work BEFORE starting any
implementation:

1. **Identify feature boundaries.** Each implementable slice from the
   plan becomes one issue in the canonical repo for that work.
   Cross-repo slices get one canonical issue plus follow-up
   references in companion repos.
2. **File one issue per slice.** Title `Feature: <slice headline>`
   (or `Bug:` / `Chore:` if more accurate). Body carries the slice's
   **Why**, **Files to change**, **Verification**, and any decisions
   made during planning. Don't summarize — paste the slice content
   so future sessions can execute from the issue alone without
   re-reading the plan file.
3. **Apply project fields.** `Work type`, `Priority` (P0–P3),
   `Status=Todo`, `Release` (v0.x or `Backlog`). Field + option IDs
   change when the project schema is edited; re-fetch them with
   `gh project field-list 2 --owner zelosai --format json` instead
   of hardcoding.
4. **Apply the repo milestone.** Match `Release`.
   `gh issue create … --milestone v0.x`.
5. **Update this repo's `ROADMAP.md`.** Every filed feature lands
   in a lane: `In flight` (Status=In Progress), `Next` (Status=Todo
   with a v0.x release), `Backlog` (Release=Backlog), or `Recently
   shipped` (Status=Done, closed in the last release). Link by
   issue URL with the title + priority + release tags.
6. **Update `zelosai/ROADMAP.md`** as well if the feature matters
   at the suite level — anything in a v0.x release lane (in-flight
   / next / following) always goes in the suite roadmap; pure
   component-local backlog items can stay component-only.
7. **Update suite-architecture memory** if the plan introduces a
   new component or reshapes how existing ones interact.

This applies to plans of any size. Trivial single-file fixes the user
asked to be done in-session still skip the issue step (per "When to
file vs just fix" above) — but anything that came through
`ExitPlanMode` is, by definition, planned work and gets tracked.

### When given an issue to execute (backlog → implementation)

If the user references an issue by number or URL, Claude:

1. **Fetch the issue.** `gh issue view <N> -R zelosai/zelos.dgx
   --json title,body,labels,milestone,assignees,projectItems`.
   Read end-to-end before touching code.
2. **Move the project item to `Status=In Progress`** and **move the
   entry in `ROADMAP.md` from `Next` (or `Backlog`) to `In flight`**.
   Same for the suite roadmap if the item lives there. Both happen
   in a single commit on the feature branch, before any
   implementation commits.
3. **Branch off `develop`.** Name:
   `claude/<short-slug-from-title>`.
4. **Implement** per the issue body's "Files to change" and
   "Verification" sections. Surface deviations to the user before
   pushing.
5. **PR feature → develop** with `Closes #<N>` in the body. Merge
   with `gh pr merge <PR> --squash --delete-branch --admin`. After
   merge: the `release` workflow builds and pushes the dev
   container; the `tracker-ready-for-qa` workflow then auto-moves
   the project item to `Status=Ready for QA`. Manually move the
   `ROADMAP.md` entry from `In flight` to `Ready for QA`.
6. **Promote develop → main** via a separate PR (`gh pr merge <PR>
   --merge --admin` to preserve commits). This is the merge that
   fires GitHub's `Closes #N` auto-close.
7. **Back-merge `main → develop`** to absorb the promotion's merge
   commit.
8. **Move the ROADMAP entries.** `Ready for QA` → `Recently shipped`
   in this repo's `ROADMAP.md` (and in `zelosai/ROADMAP.md` if it's
   there too). This can be folded into the back-merge PR or a tiny
   follow-up commit.
9. **Confirm.** The project's "Item closed" workflow moves Status
   to `Done` automatically; verify with `gh issue view <N>` and the
   project view.

If an issue turns out to be too coarse to execute as a single PR,
propose splitting it (in plan mode) before starting any code.

## Relation to the Zelos suite

`zelos.dgx` is the first of N planned `zelos.<hosttype>` Ansible
collections that bring bare-metal hosts into the [Zelos suite](https://github.com/ZelosAI/zelosai).
Each collection has two responsibilities: (1) **provision the host**
(drivers, container runtime, Tailscale, inference runtime, optional
k3s, observability, safety nets), and (2) **deliver a
[`zelosclient`](https://github.com/ZelosAI/zelosclient) container
onto the host** wired to the local inference runtime and to the
suite's [`zelosbackplane`](https://github.com/ZelosAI/zelosbackplane)
endpoint. That container is **not a Kubernetes workload** — it runs
as a plain docker-compose or systemd unit, regardless of whether
`k3s_gpu_install: true` is set. The suite's Kubernetes story lives
in [`zelosai`](https://github.com/ZelosAI/zelosai) as a Go +
kubebuilder operator with CRDs; `zelos.dgx` is explicitly the
non-k8s path.

Architecture context:

- [zelosai/docs/architecture/03-provisioning.md](https://github.com/ZelosAI/zelosai/blob/main/docs/architecture/03-provisioning.md) — the provisioning story.
- [zelosai/docs/architecture/04-components/zelos.dgx.md](https://github.com/ZelosAI/zelosai/blob/main/docs/architecture/04-components/zelos.dgx.md) — this collection's role in the suite.
- [zelosai/docs/architecture/00-overview.md](https://github.com/ZelosAI/zelosai/blob/main/docs/architecture/00-overview.md) — suite overview.
- [zelosai/docs/architecture/05-gitflow.md](https://github.com/ZelosAI/zelosai/blob/main/docs/architecture/05-gitflow.md) — the canonical gitflow this repo follows.

## Good next-iteration prompts

- "Add a `zelosclient` role that drops the suite-wiring container on
  the provisioned host via docker-compose, pointed at the local vLLM
  and the suite `zelosbackplane` URL." (This is the missing half of
  the collection's stated purpose.)
- "Add an `open_webui` role that runs Open WebUI on `:3000` pointed
  at the local vLLM, and add it to `ai_serving.yml`."
- "Add a `caddy` role that fronts vLLM + Open WebUI with HTTPS
  (Caddy local CA or Tailscale serve)."
- "Add a `zdgx smoke` subcommand that runs `nvidia-smi`,
  `docker run --gpus all`, a vLLM `/v1/chat/completions` call, and
  a Sunshine `:47990` reachability check against an
  already-provisioned host."
- "Write molecule tests for the `docker` and `nvidia_verify` roles."
- "Generalize the inventory to a `dgx` group; convert single-host
  references in templates."
- "Add a `restic` role as an alternative `backup_backend` to borg."

## Ansible conventions

This repo is a `zelos.*` Ansible collection and follows the canonical conventions —
**read these before changing roles, playbooks, or variables**:

- [15-ansible-collection-conventions.md](https://github.com/ZelosAI/zelosai/blob/main/docs/architecture/15-ansible-collection-conventions.md)
  — role anatomy, verb dispatchers, the one-dict variable rule, inventory-driven configuration,
  templating + module discipline, plugins, playbook taxonomy, the container/CLI contract.
- [18-organization-model.md](https://github.com/ZelosAI/zelosai/blob/main/docs/architecture/18-organization-model.md)
  — the `<tenancy>.<environment>.<product>.<domain>` identity tuple, reserved variable names,
  the rename registry, per-environment secrets keys.
- [16-dns-and-hostname-standard.md](https://github.com/ZelosAI/zelosai/blob/main/docs/architecture/16-dns-and-hostname-standard.md)
  — hostname/TLS/OIDC form those variables produce.
- This repo's [CONTRIBUTING-ansible.md](./CONTRIBUTING-ansible.md) — the local digest +
  pre-push checks (`yamllint`, `ansible-lint`, `ansible-galaxy collection build`).

Lint is config-as-code: `.ansible-lint` (production profile) and `.yamllint` in this repo are
authoritative; fix violations or carry inline `# noqa <rule>` with a justification — never grow
`skip_list` silently.

## Notes / Blockers

- `claude.ai/code/session_…` URLs are NOT fetchable from this
  environment. Paste task specs as text.
- Repo lives at `ZelosAI/zelos.dgx`. The legacy `kmechlin/zelos.dgx`
  (and the older `kmechlin/ansible-dgx-collection`) mirrors should
  be considered stale; some role `meta/main.yml` files still
  reference `kmechlin` as author and are slated for a metadata
  pass.
- This collection is at `0.2.0` per `galaxy.yml`. Bump in
  `galaxy.yml` on each material change; tags are auto-applied on
  `main` push by `release-tag.yml`.
- The promised `zelosclient` delivery role has not been
  implemented; until it is, `zelos.dgx` provisions the host but
  does not actually wire it to the suite backplane.
