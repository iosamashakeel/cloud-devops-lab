# Exercise 05 — Ansible Intro

Configure real servers the repeatable way. In this exercise you write an Ansible
inventory, then a playbook that installs nginx, deploys a templated config and a
custom landing page — idempotently, so running it twice changes nothing the
second time.

## Files

- `ansible.cfg` — local config: inventory path, sane defaults (no host-key prompts in a lab)
- `inventory.ini` — the hosts you manage, grouped
- `webserver.yml` — the playbook: install nginx, push config + page, start the service
- `templates/nginx.conf.j2` — Jinja2 template for the nginx server block (variables per host)
- `files/index.html` — the landing page copied to each server

## Prerequisites

- Ansible installed: `pip install ansible` (or your OS package)
- One or more Linux targets reachable over SSH. Easiest lab targets:
  - **Local VM or WSL** as the target, with SSH set up
  - **Docker containers with sshd** (see `files/docker-target/Dockerfile` idea in Task 4)
  - Any throwaway VPS you control

Your control machine also works as a target: use `ansible_connection=local` (already
shown in the inventory under the `[local]` group).

## Task 1 — Check connectivity

```bash
ansible all -m ping -i inventory.ini
```

Every host should answer `pong`. If a host is unreachable, fix SSH access before
continuing — Ansible does not guess, it tells you exactly what's wrong.

## Task 2 — Run the playbook (check mode first)

Dry-run to see what *would* change:

```bash
ansible-playbook webserver.yml --check
```

Then run it for real:

```bash
ansible-playbook webserver.yml
```

Run it a second time and note the `ok=` vs `changed=` counts: a well-written
playbook converges. Nothing to do → nothing changed.

## Task 3 — Verify the result

Visit `http://<target-ip>` in a browser. You should see the landing page with the
hostname of the server that served it — proof the template rendered per host.

Check the config on the target:

```bash
ansible webservers -m command -a "nginx -t" -i inventory.ini
```

## Task 4 — Extend it yourself

1. Add a second host to `inventory.ini` and re-run: watch the same playbook
   configure both machines identically.
2. Add a `firewall` tag section to the playbook that opens port 80 (hint:
   the `ansible.posix.firewalld` or `community.general.ufw` module).
3. Try the Docker-target approach: build two sshd containers on the lab network,
   point the inventory at them, and provision both with one command.

## What you practiced

- Inventory as code: hosts, groups, variables in one place
- Idempotent playbooks: tasks describe desired state, not shell scripts
- Templates: per-host configuration rendered from variables
- Check mode: preview changes before you touch a server
