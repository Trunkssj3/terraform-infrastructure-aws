# Instance Security Group
resource "aws_security_group" "instance_sg" {
  name        = "allow_ssh"
  description = "Allow SSH connections from outside"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
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

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-security-group"
  }
}

resource "aws_instance" "web_1" {
  ami           = "ami-053b12d3152c0cc71"  
  instance_type = "t3a.micro"
  subnet_id     = aws_subnet.public_1.id

  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io
              sudo usermod -aG docker $USER
              sudo systemctl start docker
              sudo systemctl enable docker              
              newgrp docker
              docker run -d -p 3000:3000 adongy/hostname-docker
              EOF

  tags = {
    Name = "web-server-1"
  }
}

resource "aws_instance" "web_2" {
  ami           = "ami-053b12d3152c0cc71"  # Ubuntu 22.04 AMI ID
  instance_type = "t3a.micro"
  subnet_id     = aws_subnet.public_2.id

  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io
              sudo usermod -aG docker $USER
              sudo systemctl start docker
              sudo systemctl enable docker              
              newgrp docker
              docker run -d -p 3000:3000 adongy/hostname-docker
              EOF

  tags = {
    Name = "web-server-2"
  }
}

# Application Load Balancer
resource "aws_lb" "web" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

# Target Group
resource "aws_lb_target_group" "web" {
  name     = "web-target-group"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# Listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Target Group Attachments
resource "aws_lb_target_group_attachment" "web_1" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_1.id
  port             = 3000
}

resource "aws_lb_target_group_attachment" "web_2" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_2.id
  port             = 3000
}


