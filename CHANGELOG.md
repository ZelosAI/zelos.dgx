# Changelog

All notable changes to the `zelos.dgx` Ansible collection are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this collection adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Released versions are tagged in the source repository as `v<major>.<minor>.<patch>` and published as GitHub Releases with auto-generated notes; this file is the curated human-readable summary.

## [Unreleased]

### Added
- `scripts/mirror_push.py` helper for force-mirroring the repo (all branches and tags) into another remote.
- `.github/workflows/release-tag.yml` to auto-tag and create a GitHub Release whenever `main` advances, reading the version from `galaxy.yml`.

### Changed
- Role variables now carry their role-name prefix to satisfy `ansible-lint`'s `var-naming[no-role-prefix]` rule. User-facing renames:
  - `borg_*` -> `backup_*` (in the `backup` role)
  - `k3s_install`, `k3s_version`, `k3s_device_plugin_version` -> `k3s_gpu_install`, `k3s_gpu_version`, `k3s_gpu_device_plugin_version` (in the `k3s_gpu` role)
  - `node_exporter_*` and `dcgm_exporter_*` -> `monitoring_*` (in the `monitoring` role)
- `CLAUDE.md` Git/Workflow section now defines the `feature/<plan-name>` branch convention, Claude-driven auto-merge into `develop`, and the user-gated release flow into `main`.

## [0.2.0] - 2026-05-19

### Added
- Containerised Ansible control node (`Dockerfile`, `make ansible-shell`).
- Initial scaffold of all roles: `bootstrap`, `snapshot`, `backup`, `nvidia_verify`, `docker`, `tailscale`, `virtual_display`, `sunshine`, `vllm`, `k3s_gpu`, `monitoring`.

### Changed
- Collection namespace renamed from `kmechlin` to `zelos` (FQCN: `zelos.dgx`).

## [0.1.0] - Initial scaffold

- First public scaffold of the collection. Not yet validated against real hardware.
