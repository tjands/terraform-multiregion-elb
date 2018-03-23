terraform {
  required_version = ">= 0.10.3"
}

provider "aws" {
  region = "${var.region}"

  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_route53_zone" "default" {
  zone_id = "${var.r53_zone_id}"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["099720109477"]
}

resource "aws_vpc" "main" {
  cidr_block                       = "192.168.0.0/16"
  assign_generated_ipv6_cidr_block = "true"
  enable_dns_support               = "true"
  enable_dns_hostnames             = "true"

  tags {
    Name = "cdn-${var.region}"
  }
}

resource "aws_key_pair" "ubuntu" {
  key_name   = "${var.key_name}"
  public_key = "${var.public_key}"
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "cdn-${var.region}-igw"
  }
}

resource "aws_subnet" "public" {
  count      = "${length(data.aws_availability_zones.available.names)}"
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"

  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index)}"
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
  availability_zone               = "${element(data.aws_availability_zones.available.names, count.index)}"

  tags = {
    Name = "cdn-${element(data.aws_availability_zones.available.names, count.index)}-public"
  }
}

resource "aws_route_table" "public" {
  count  = "${length(data.aws_availability_zones.available.names)}"
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = "${aws_internet_gateway.default.id}"
  }
}

resource "aws_route_table_association" "public" {
  count          = "${length(data.aws_availability_zones.available.names)}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.public.*.id, count.index)}"
}

resource "aws_security_group" "default" {
  name   = "cdn-${var.region}-sg"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = -1
    to_port          = -1
    protocol         = "icmpv6"
    ipv6_cidr_blocks = ["::/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere 
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #TODO Currently can SSH in from anywhere if you have the Key. Our Infrastructure should only SSH from Office Static IP
  }
}

resource "aws_instance" "server" {
  count                  = "${length(data.aws_availability_zones.available.names) * var.servers_per_az}"
  instance_type          = "${var.instance_type}"
  ami                    = "${data.aws_ami.ubuntu.id}"
  key_name               = "${var.key_name}"
  subnet_id              = "${element(aws_subnet.public.*.id, count.index)}"
  ipv6_address_count     = "1"                                                                               #TODO Check what this does
  vpc_security_group_ids = ["${aws_security_group.default.id}", "${aws_vpc.main.default_security_group_id}"]

  tags = {
    Name = "cdn-server-${element(data.aws_availability_zones.available.names, count.index)}-${count.index}"
  }
}

# Create a new load balancer
resource "aws_elb" "public" {
  name = "cdn-${var.region}-elb"

  # availability_zones = ["${aws_subnet.public.*.availability_zone}"]

  security_groups = ["${aws_security_group.default.id}", "${aws_vpc.main.default_security_group_id}"]
  subnets         = ["${aws_subnet.public.*.id}"]
  listener {
    instance_port     = 8000   #TODO Why this number
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  listener {
    instance_port      = 8000
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "arn:aws:iam::123456789012:server-certificate/certName"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:22"
    interval            = 30
  }
  instances                   = ["${aws_instance.server.*.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags {
    Name = "elb-terraform" # dont think i need this
  }
}

resource "aws_route53_record" "cdn" {
  zone_id = "${data.aws_route53_zone.default.zone_id}"
  name    = "${format("%s.%s", var.r53_domain_name, data.aws_route53_zone.default.name)}"
  type    = "A"

  alias {
    name                   = "${aws_elb.public.dns_name}"
    zone_id                = "${aws_elb.public.zone_id}"
    evaluate_target_health = false
  }

  set_identifier = "cdn-${var.region}-v4"

  latency_routing_policy {
    region = "${var.region}"
  }
}
