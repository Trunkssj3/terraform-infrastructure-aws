provider "aws" {
  region = "ap-south-1"
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH from anywhere"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "my_ec2" {
  ami                    = "ami-03c156cf4a6b389e6" # Ubuntu 22.04 LTS Mumbai
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "MySimpleEC2"
  }
}

output "ec2_public_ip" {
  value       = aws_instance.my_ec2.public_ip
  description = "Public IP of the created EC2"
}

