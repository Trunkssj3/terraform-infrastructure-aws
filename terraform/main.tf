
provider "aws" {
  region = "ap-south-1"
}

resource "aws_security_group" "allow_http_ssh" {
  name        = "allow_http_ssh"
  description = "Allow HTTP, SSH and Flask (port 5000)"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask App"
    from_port   = 5000
    to_port     = 5000
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


resource "aws_instance" "flask_docker" {
  ami                    = "ami-03c156cf4a6b389e6" # Ubuntu 22.04 LTS Mumbai
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_http_ssh.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker

    docker run -d --name flask-app -p 5000:5000 tiangolo/uwsgi-nginx-flask:python3.8 \
      bash -c "echo 'from flask import Flask; app = Flask(__name__); @app.route(\"/\")\\ndef home(): return \\\"Hello from Flask on EC2!\\\"; if __name__ == \\\"__main__\\\": app.run(host=\\\"0.0.0.0\\\")' > /app/main.py && python /app/main.py"
  EOF

  tags = {
    Name = "FlaskDockerEC2"
  }
}

output "ec2_public_ip" {
  value       = aws_instance.flask_docker.public_ip
  description = "The public IP of the EC2 instance"
}
