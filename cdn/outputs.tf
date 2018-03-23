output "servers" {
  value = ["${aws_instance.server.*.public_ip}"]
}

output "public_ips_v6" {
  value = ["${aws_instance.server.*.ipv6_addresses}"]
}

output "public-ip" {
  value = "${aws_instance.server.*.public_ip}"
}

output "elb-dns" {
  value = "${aws_elb.public.*.dns_name}"
}
