provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "example" {
  ami          = "ami-0fb653ca2d3203ac1" # Ubuntu Server 20.04 の AMI ID
  instance_type = "t2.micro"

  tags = {
    Name = "terraform-example-instance"
  }
}