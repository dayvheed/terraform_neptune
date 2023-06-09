provider "aws" {
  region = "us-east-1"
  profile = "personal-account" 
}

# create vpc
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

# Define the IAM role for Neptune loader
resource "aws_iam_role" "neptune_loader_role" {
  name = "NeptuneLoaderFromS3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_iam_policy_attachment" "s3_read_policy_attachment" {
  name       = "AmazonS3ReadOnlyAccess"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  roles      = [aws_iam_role.neptune_loader_role.name]
}


## ------ AWS Neptune Cluster  -------------------------------------------------
resource "aws_neptune_cluster" "example" {

  cluster_identifier                  = "${var.neptune_name}"
  engine                              = "neptune"
  skip_final_snapshot                 = true
  iam_database_authentication_enabled = false
  neptune_cluster_parameter_group_name = "default.neptune1.2"
  apply_immediately                   = true
  vpc_security_group_ids              = [ "${aws_security_group.neptune_example.id}" ]
  iam_roles          = [aws_iam_role.neptune_loader_role.arn]
  serverless_v2_scaling_configuration {}

}

resource "aws_neptune_cluster_instance" "example" {
  count              = "${var.neptune_count}"
  cluster_identifier = "${aws_neptune_cluster.example.id}"
  identifier         = var.neptune_instance_name
  engine             = "neptune"
  instance_class     = "db.serverless"
  neptune_parameter_group_name = "default.neptune1.2"
  apply_immediately  = true
}


# Create an EC2 key pair for SSH access to the instance
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "myKey1"       # Create a "myKey1" to AWS!!
  public_key = tls_private_key.pk.public_key_openssh

  provisioner "local-exec" { # Create a "myKey1.pem" to your computer!!
    command = "echo '${tls_private_key.pk.private_key_pem}' > ./myKey1.pem && chmod 600 ./myKey1.pem"
  }

}


## ------ EC2 Instance inside SG  ----------------------------------------------

resource "aws_instance" "neptune-ec2-connector" {
  ami = "ami-00c39f71452c08778"
  instance_type = "t2.micro"
  tags = {
    Name = "neptune-demo"
  }
  vpc_security_group_ids = [ "${aws_security_group.neptune_example.id}" ]
  key_name = "myKey1"
}

## ------ SGs  -----------------------------------------------------------------

resource "aws_security_group" "neptune_example" {
  name        = "${var.neptune_sg_name}"
  description = "Allow traffic for ecs"
  vpc_id      = "${aws_default_vpc.default.id}"

  ingress {
    from_port   = 8182
    to_port     = 8182
    protocol    = "tcp"
    self = true
    #security_groups = [ "${aws_security_group.neptune_example.id}" ]
  }


  # Allow SSH from anywhere...
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