# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1" # Set the AWS region to Mumbai
}

# Data source to dynamically get the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID for Ubuntu AMIs

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group to allow SSH, HTTP, and Flask app traffic
resource "aws_security_group" "allow_http_ssh_flask" {
  name        = "allow_http_ssh_flask" # Renamed to reflect all allowed ports
  description = "Allow HTTP, SSH and Flask (port 5000)"

  # Ingress rule for SSH access (port 22)
  ingress {
    description = "SSH access from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: 0.0.0.0/0 allows access from any IP. Consider restricting this in production.
  }

  # Ingress rule for HTTP access (port 80)
  ingress {
    description = "HTTP access from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress rule for Flask App access (port 5000)
  ingress {
    description = "Flask App access from anywhere"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule to allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"] # Allows outbound traffic to any destination
  }
}

# EC2 Instance to host the Flask Docker application
resource "aws_instance" "flask_docker" {
  ami             = data.aws_ami.ubuntu.id # Use the dynamically retrieved AMI ID
  instance_type   = "t2.micro"             # Free-tier eligible instance type
  # Associate the instance with the updated security group
  vpc_security_group_ids = [aws_security_group.allow_http_ssh_flask.id]

  # User data script to install Docker and run the Flask app
  user_data = <<-EOF
    #!/bin/bash
    echo "Starting user data script..."
    # Update package lists
    sudo apt-get update -y
    # Install Docker
    sudo apt-get install -y docker.io
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    echo "Docker installed and started."

    # Run the Flask application in a Docker container
    # -d: Run in detached mode
    # --name flask-app: Assign a name to the container
    # -p 5000:5000: Map host port 5000 to container port 5000
    # tiangolo/uwsgi-nginx-flask:python3.8: Use a pre-built Flask image
    # bash -c "...": Inline command to create and run a simple Flask app
    sudo docker run -d --name flask-app -p 5000:5000 tiangolo/uwsgi-nginx-flask:python3.8 \
      bash -c "echo 'from flask import Flask; app = Flask(__name__); @app.route(\"/\")\\ndef home(): return \\\"Hello from Flask on EC2!\\\"; if __name__ == \\\"__main__\\\": app.run(host=\\\"0.0.0.0\\\")' > /app/main.py && python /app/main.py"
    echo "Flask app Docker container started."
  EOF

  # Tags for easier identification in AWS console
  tags = {
    Name = "FlaskDockerEC2"
  }
}

# Output the public IP address of the EC2 instance
output "ec2_public_ip" {
  value       = aws_instance.flask_docker.public_ip
  description = "The public IP of the EC2 instance where the Flask app is running"
}
