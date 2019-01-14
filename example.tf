provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_instance" "web" {
  ami           = "ami-2d39803a"
  availability_zone = ""
  instance_type = "t2.micro"

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF
  tags {
    Name = "test web server"
  }
  vpc_security_group_ids = ["${aws_security_group.instance.id}"]
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"
  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "elb" {
  name = "terraform-example-elb"

  egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "example" {
  name = "terraform-asg-example"
  security_groups = ["${aws_security_group.elb.id}"]
  availability_zones = ["us-east-1a"]
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:${var.server_port}/"
  }
  listener {
    lb_port = "${var.server_port}"
    lb_protocol = "http"
    instance_port = "${var.server_port}"
    instance_protocol = "http"
  }
}

resource "aws_elb_attachment" "example" {
  elb      = "${aws_elb.example.id}"
  instance = "${aws_instance.web.id}"
}

resource aws_route53_zone "testZone" {
  name = "aws.paullschock.com"
}

resource aws_route53_record "www" {
  zone_id = "${aws_route53_zone.testZone.zone_id}"
  name = "aws.paullschock.com"
  type = "A"

  alias {
    name = "${aws_elb.example.dns_name}"
    zone_id = "${aws_elb.example.zone_id}"
    evaluate_target_health = true
  }
}

output "name_servers" {
  value = "${aws_route53_zone.testZone.name_servers}"
}

output "elb_dns_name" {
  value = "${aws_elb.example.dns_name}"
}
