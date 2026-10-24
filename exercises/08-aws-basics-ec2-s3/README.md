# Exercise 08 — AWS Basics: EC2 + S3

Launch a real server and a real storage bucket on AWS, with Terraform, then
tear both down again. This is the smallest useful AWS setup: one EC2 instance
serving a web page, one private S3 bucket holding a file, and nothing left
running when you are done.

## Files

- `main.tf` — provider, EC2 instance, security group, S3 bucket, bucket policy
- `variables.tf` — region, instance type, SSH source address, bucket name
- `outputs.tf` — public IP, website URL, bucket name
- `user_data.sh` — boot script run by the instance: installs nginx, serves a page

## Prerequisites

- An AWS account with a user that has EC2 and S3 permissions
- AWS CLI installed and configured: `aws configure` (access key, secret key,
  region, output format). Check it with `aws sts get-caller-identity`.
- Terraform installed: https://developer.hashicorp.com/terraform/install
- An SSH key pair in your AWS region. Create one if needed:

```bash
aws ec2 create-key-pair --key-name lab-key --query 'KeyMaterial' \
  --output text > lab-key.pem
chmod 400 lab-key.pem
```

Keep `lab-key.pem` private. Never commit it, and never commit AWS credentials.

## Costs — read this first

The instance defaults to `t3.micro` in `eu-central-1` (Frankfurt), which is
in the AWS free tier for new accounts (750 hours/month for 12 months). S3
storage for a few small files costs cents. Outside the free tier, a `t3.micro`
running all month is a few euros/dollars. Run `terraform destroy` at the end
of the exercise either way — leaving resources running is how lab bills happen.

## Task 1 — Look at what Terraform will build

```bash
cd exercises/08-aws-basics-ec2-s3
terraform init
terraform plan
```

Read the plan before applying it. You should see: one `aws_instance`, one
`aws_security_group` with two ingress rules, one `aws_s3_bucket`, plus the
versioning and public-access-block resources. Nothing else.

Set your own SSH source address first. By default the security group only
allows SSH from the CIDR in `allowed_ssh_cidr`. Find your public IP
(`curl -s ifconfig.me`) and pass it, for example:

```bash
terraform plan -var "allowed_ssh_cidr=$(curl -s ifconfig.me)/32"
```

Do not set this to `0.0.0.0/0` on a real account. HTTP (port 80) is open to
the world on purpose — that is how visitors reach the page — but SSH is not.

## Task 2 — Apply, then open the page

```bash
terraform apply -var "allowed_ssh_cidr=$(curl -s ifconfig.me)/32"
```

Terraform prints the outputs at the end. Open the `website_url` in a browser:
it should show the nginx welcome page replaced by the small page from
`user_data.sh` ("Hello from EC2"). If the page does not load, check the
security group (port 80 open?) and give the instance a minute to finish
booting — `user_data.sh` runs on first boot only.

## Task 3 — SSH in and look around

```bash
ssh -i lab-key.pem ec2-user@<public_ip>
```

Replace `<public_ip>` with the `instance_public_ip` output. On the instance,
check that nginx is running (`systemctl status nginx`) and that the page file
exists at `/usr/share/nginx/html/index.html`. Then log out.

## Task 4 — Put a file in S3 and fetch it back

```bash
echo "hello from the lab" > hello.txt
aws s3 cp hello.txt s3://<bucket_name>/hello.txt
aws s3 ls s3://<bucket_name>/
aws s3 cp s3://<bucket_name>/hello.txt ./hello-back.txt
diff hello.txt hello-back.txt && echo "round trip OK"
```

Replace `<bucket_name>` with the `bucket_name` output. Note the bucket is
private: there is no public URL for this file, and `aws s3 cp` works because
it uses your credentials, not anonymous access. That is the point — S3
defaults here are private, and the public-access block in `main.tf` keeps
them that way.

## Task 5 — Turn on versioning, then prove it

Versioning is already enabled in `main.tf`. Upload a second version of the
same file and list versions:

```bash
echo "version two" > hello.txt
aws s3 cp hello.txt s3://<bucket_name>/hello.txt
aws s3api list-object-versions --bucket <bucket_name> \
  --prefix hello.txt --query 'Versions[].{Key:Key,Id:VersionId,Latest:IsLatest}'
```

You should see two versions. This is why versioning matters in real projects:
an overwrite or a bad deploy does not destroy the previous file.

## Task 6 — Clean up (do not skip this)

```bash
terraform destroy -var "allowed_ssh_cidr=$(curl -s ifconfig.me)/32"
```

Type `yes` when asked. Then confirm nothing is left:

```bash
aws ec2 describe-instances --query 'Reservations[].Instances[].State.Name'
aws s3 ls
```

The instance should be terminated (or gone from the list) and the bucket
should be gone. If `terraform destroy` fails on the bucket because it still
holds objects, empty it first (`aws s3 rm s3://<bucket_name> --recursive`)
and run destroy again.

## What you practised

- Terraform workflow: init, plan, apply, destroy — and reading a plan
  before you trust it
- EC2 basics: AMI lookup, instance type, key pair, security groups,
  user data, outputs
- S3 basics: private-by-default buckets, versioning, public-access block,
  CLI round trip
- The habit that matters most on cloud accounts: destroying lab resources

## Next

Exercise 09 builds on this: Docker Compose running several services together,
which is what you would actually deploy on an instance like this one.
