# multiregion-terraform
Example multi-region AWS Terraform application. This Git Repo has been modified from u/kung-foo's original design to include the building and wrapping of a Load Balancer

**TL;DR**: launch EC2 instances in all AWS regions with a single `terraform` command.

Amazon has 15 data centers, each with multiple availability zones spread around the world. This Terraform application launches EC2 instances in every possible zone and wraps them in a specific Elastic Load Balancer in each possible region. These ELBS are then set to route users to the geographically closest region and server cluster.

## Features

* Single `main.tf` with a module instance for each Amazon's [15 regions][1]
* Creates an EC2 instance in every region and availability zone
* Creates two Route 53 records (A and AAAA) with [latency based routing][2] to all ELBs
* All instances allow ICMP Echo Request (ping) from `0.0.0.0/0`
* Supports IPv4 _and_ IPv6

## How-to

Notes:

* **IMPORTANT**: edit [cdn/variables.tf](cdn/variables.tf) and set `r53_zone_id` and `r53_domain_name`. Currently Set to my records.
* requires Terraform >= v0.10.3
* comment out regions in [main.tf](main.tf) to test a smaller deployment
* Terraform types used: aws_ami, aws_vpc, aws_internet_gateway, aws_subnet, aws_route_table, aws_route_table_association, aws_security_group, aws_instance, aws_elb and aws_route53_record
* This build includes a keys.tf file that has been excluded in .gitignore for privacy reasons. Listed below is the template I used to build mine.

```
Creat cdn/keys.tf file
...

#ACCESS & SECRET Keys
variable "access_key" {
  description = "My Access Key"
  default     = "MYACCESSKEY"
}

variable "secret_key" {
  description = "My Secret Key"
  default     = "MYSECRETKEY"
}

#OpenSSH KeyPair
variable "key_name" {
  description = "My Admin KEYPAIR.pem file"
  default     = "KEYPAIR"
}

variable "public_key" {
  description = "My Public Key"
  default     = "ssh-rsa YOURPUBLICKEYHERE"
}

```

[1]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-available-regions
[2]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html#routing-policy-latency
[3]: https://www.terraform.io/docs/providers/aws/#shared-credentials-file
