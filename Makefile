ANSIBLE   = ansible-playbook
INV       = inventory/hosts.yml
BOOT_INV  = inventory/bootstrap.yml
ASK       = --ask-vault-pass

.PHONY: help deps lint syntax ping \
        bootstrap setup site \
        snapshot rollback backup backup-now backup-restore \
        nvidia base remote-desktop ai k3s monitoring tailscale

help:
	@echo "Operator flow on a fresh DGX:"
	@echo "  1. make bootstrap     one-time, interactive (admin user + password)"
	@echo "  2. make setup         one-time, captures clean-baseline snapshot + full borg backup"
	@echo "  3. make site          repeatable, pre-flight snapshot taken each run"
	@echo ""
	@echo "Safety net targets:"
	@echo "  snapshot              take an ad-hoc timeshift snapshot"
	@echo "  rollback              restore latest snapshot (-e snapshot_target=<name> for explicit)"
	@echo "  backup                refresh borg config + systemd timer (no immediate backup)"
	@echo "  backup-now            same as backup, but trigger an immediate run too"
	@echo "  backup-restore        extract a borg archive to /var/restore (pass ARCHIVE=<name>)"
	@echo ""
	@echo "Provisioning targets:"
	@echo "  nvidia                verify NVIDIA driver only"
	@echo "  base                  docker + tailscale"
	@echo "  remote-desktop        virtual_display + sunshine"
	@echo "  ai                    docker + vllm"
	@echo "  monitoring            node_exporter + DCGM exporter"
	@echo "  k3s                   install k3s with NVIDIA runtime (opt-in)"
	@echo "  tailscale             tailscale only"
	@echo ""
	@echo "Repo hygiene:"
	@echo "  deps                  install required collections"
	@echo "  lint                  yamllint + ansible-lint"
	@echo "  syntax                ansible-playbook --syntax-check on every playbook"
	@echo "  ping                  ansible -m ping all hosts"

deps:
	ansible-galaxy collection install -r requirements.yml

lint:
	yamllint .
	ansible-lint

syntax:
	@for pb in playbooks/*.yml; do \
		echo "syntax: $$pb"; \
		$(ANSIBLE) -i $(INV) $$pb --syntax-check || exit 1; \
	done

ping:
	ansible -i $(INV) all -m ping -b

bootstrap:
	$(ANSIBLE) -i $(BOOT_INV) playbooks/bootstrap.yml --ask-pass --ask-become-pass

setup:
	$(ANSIBLE) -i $(INV) playbooks/setup.yml $(ASK)

site:
	$(ANSIBLE) -i $(INV) playbooks/site.yml $(ASK)

snapshot:
	$(ANSIBLE) -i $(INV) playbooks/snapshot.yml $(ASK)

rollback:
	$(ANSIBLE) -i $(INV) playbooks/rollback.yml $(ASK)

backup:
	$(ANSIBLE) -i $(INV) playbooks/backup.yml $(ASK)

backup-now:
	$(ANSIBLE) -i $(INV) playbooks/backup.yml $(ASK) -e borg_run_now=true

backup-restore:
	$(ANSIBLE) -i $(INV) playbooks/backup_restore.yml $(ASK) -e borg_archive=$(ARCHIVE)

nvidia:
	$(ANSIBLE) -i $(INV) playbooks/nvidia_verify.yml $(ASK)

base:
	$(ANSIBLE) -i $(INV) playbooks/base.yml $(ASK)

remote-desktop:
	$(ANSIBLE) -i $(INV) playbooks/remote_desktop.yml $(ASK)

ai:
	$(ANSIBLE) -i $(INV) playbooks/ai_serving.yml $(ASK)

k3s:
	$(ANSIBLE) -i $(INV) playbooks/k3s.yml $(ASK)

monitoring:
	$(ANSIBLE) -i $(INV) playbooks/monitoring.yml $(ASK)

tailscale:
	$(ANSIBLE) -i $(INV) playbooks/tailscale.yml $(ASK)
