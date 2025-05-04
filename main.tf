provider "aws" {
  region = "us-east-2"
}

# EC2インスタンスを作成する
# resource "aws_instance" "example" {
#   ami                    = "ami-0fb653ca2d3203ac1" # Ubuntu Server 20.04 の AMI ID
#   instance_type          = "t2.micro"
#   vpc_security_group_ids = [aws_security_group.instance.id]

#   user_data = <<-EOF
#               #!/bin/bash
#               echo "Hello, World!" > index.html
#               nohup busybox httpd -f -p ${var.server_port} &
#               EOF

#   user_data_replace_on_change = true

#   tags = {
#     Name = "terraform-example-instance"
#   }
# }

resource "aws_security_group" "instance" {
  name = "terraform-sg-instance"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # セキュリティ的に良くないので、使ってない時はEC2インスタンスを停止or削除
  }
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

# outputは、Terraformの実行結果に出力したり、他のモジュールに渡したりするための値を定義する
# output "public_ip" {
#   value       = aws_instance.example.public_ip
#   description = "The public IP address of the web server"
# }

# Auto Scaling Group(ASG)とは、EC2インスタンスのグループを作成し、
# 負荷に応じてインスタンスの数を自動的に増減させるためのサービス。

# ASG内のインスタンスに適用するLaunch Configurationを作成
resource "aws_launch_configuration" "example" {
  image_id        = "ami-0fb653ca2d3203ac1"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World!" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

  # Auto Scaling Group がある起動設定を使った場合に必須
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier = data.aws_subnets.default.ids

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

# dataはプロバイダから取得する読み出し専用情報を定義する
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
