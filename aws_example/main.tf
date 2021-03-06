provider "aws" {
  region = "${var.aws_region}"
  profile = "haidv"  # use your aws profile name that define in ~/.aws/credentials
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY AN EC2 INSTANCE RUNNING UBUNTU
# See terratest/aws_test.go for how to write automated tests for this code.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_instance" "example" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"

  tags {
    Name = "${var.instance_name}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LOOK UP THE LATEST UBUNTU AMI
# ---------------------------------------------------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
}