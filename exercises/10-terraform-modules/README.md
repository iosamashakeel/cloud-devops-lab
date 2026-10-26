# Exercise 10 — Terraform Modules

Exercise 08 built one server and one bucket in a single flat file. That works
for a lab, but it does not scale: copy-pasting the same security group and
instance block into every project is how drift and mistakes creep in. This
exercise splits the same kind of infrastructure into two reusable modules,
then uses one of them twice.

## Learning goals

- Structure a Terraform project as a root module plus child modules.
- Decide what belongs in a module: inputs (`variables.tf`), resources
  (`main.tf`), and outputs (`outputs.tf`).
- Reuse the same module twice with different inputs, instead of duplicating
  resource blocks.
- Pass values between modules through outputs, not by hardcoding ids.

## Files

```
10-terraform-modules/
├── main.tf                  # root: provider + two module calls
├── variables.tf             # root inputs (region, instance type, SSH source)
├── outputs.tf               # root outputs (IPs of both web servers)
├── modules/
│   ├── network/
│   │   ├── main.tf          # VPC, public subnet, internet gateway, route table
│   │   ├── variables.tf     # VPC CIDR, subnet CIDR, name prefix
│   │   └── outputs.tf       # vpc_id, subnet_id
│   └── web-server/
│       ├── main.tf          # security group + EC2 instance
│       ├── variables.tf     # vpc_id, subnet_id, instance type, SSH source, name
│       ├── outputs.tf       # instance_id, public_ip
│       └── user_data.sh     # installs nginx, serves a page naming the server
```

## Prerequisites

- An AWS account with a user that has EC2 and VPC permissions.
- AWS CLI configured (`aws configure`), and an SSH key pair in your region.
  See exercise 08 if you have not done this before.
- Terraform ≥ 1.5: https://developer.hashicorp.com/terraform/install

## Costs — read this first

Two `t3.micro` instances in `eu-central-1` (Frankfurt) are in the AWS free
tier for new accounts (750 hours/month for 12 months). Run
`terraform destroy` at the end either way.

## Task 1 — Read the modules before you run anything

Start with the two module contracts, not the resources:

```bash
cat modules/network/variables.tf modules/network/outputs.tf
cat modules/web-server/variables.tf modules/web-server/outputs.tf
```

Then read the root module, `main.tf`. Notice three things:

1. The root module creates no EC2 instance and no VPC directly. It only
   declares the provider and calls modules.
2. `module "web_a"` receives its `subnet_id` from
   `module.network.subnet_id`. That is the only link between the modules.
3. `module "web_b"` is the exact same source path as `web_a`, with a
   different `name`. Same code, second server, no duplication.

## Task 2 — Plan and apply

```bash
cd exercises/10-terraform-modules
terraform init
terraform plan
terraform apply
```

The plan should show: one VPC, one subnet, one internet gateway, one route
table, two security groups, and two EC2 instances. If the plan shows anything
else, stop and read it before approving.

## Task 3 — Check both servers

```bash
terraform output
```

Open both URLs from the output in a browser. Each page says which server it
came from (`web-a` or `web-b`), so you can tell the two identical modules
apart. SSH is open only from the address in `allowed_ssh_cidr`, never from
`0.0.0.0/0`.

## Task 4 — Change one input, not the code

Change the instance type for `web_b` only, in the root `main.tf` (for
example, pass a different `instance_type` to that one module call), then run
`terraform plan` again. Only `web_b` should change. That is the whole point
of a module: one behaviour, configured per use.

## Task 5 — Clean up

```bash
terraform destroy
```

Confirm the destroy plan lists the same resources the apply created, then
approve it. Nothing should be left running.

## Stretch tasks

- Add a third module call, `web_c`, in a different availability zone. You
  will need a second subnet: add a second subnet to the network module first
  (a new input, a new resource, a new output), rather than hacking it in the
  root.
- Move the hardcoded nginx page in `user_data.sh` into a module variable so
  each server can serve different text.
- Extract the security group into its own module and use it from
  `web-server`, so the web server module itself gets smaller.

## Notes

- Never commit AWS credentials or `.pem` key files. The `.tfstate` file
  created by `terraform apply` contains resource ids and should stay local;
  do not commit it either.
- Module source paths here are local (`./modules/network`). Published
  modules from the Terraform Registry work the same way, with a registry
  address instead of a path.
