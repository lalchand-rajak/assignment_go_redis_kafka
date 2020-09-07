provider "aws" {
    region  = "ap-south-1"
    access_key = "AKIAIH7AAFZTSYGFY4XQ"
    secret_key = "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"
}

resource "aws_iam_role" "ecs_role" {
  name = "ecs_role"

  assume_role_policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "ecs.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
EOF
}

resource "aws_iam_policy" "ecs-policy" {
  name        = "ecs-policy"
  description = "ecs policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecs:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-attach" {
  role       = aws_iam_role.ecs_role
  policy_arn = aws_iam_policy.ecs-policy.arn


resource "aws_iam_instance_profile" "ec2_profile" {
  name = "test_profile"
  role = aws_iam_role.ecs_role
}

resource "aws_iam_role" "ec2-role" {
  name = "ec2-role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy" "ec2-policy" {
  name        = "ec2-policy"
  description = "ec2 policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ec2-attach" {
  role       = aws_iam_role.ec2-role
  policy_arn = aws_iam_policy.ec2-policy.arn

resource "aws_vpc" "ecs_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ecs_vpc"
  }
}


resource "aws_subnet" "ecs-subnet" {
  vpc_id     = aws_vpc.ecs_vpc.id
  cidr_block = "10.0.1.0/24"
  avaiability_zone = "ap-south-1"
  tags = {
    Name = "ecs-subnet"
  }
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.ecs_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
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

  tags = {
    Name = "allow_web"
  }
}


resource "aws_alb" "ecs-load-balancer" {
    name                = "ecs-load-balancer"
    security_groups     = aws_security_group.allow_web.id
    subnets             = aws_subnet.ecs-subnet.id

    tags {
      Name = "ecs-load-balancer"
    }


resource "aws_alb_target_group" "ecs-target-group" {
    name                = "ecs-target-group"
    port                = "8080"
    protocol            = "HTTP"
    vpc_id              = aws_vpc.ecs_vpc.id

    health_check {
        healthy_threshold   = "5"
        unhealthy_threshold = "2"
        interval            = "30"
        matcher             = "200"
        path                = "/"
        port                = "8080"
        protocol            = "HTTP"
        timeout             = "5"
    }

    tags {
      Name = "ecs-target-group"
    }
}

http_tcp_listeners = [
    {
      port               = 8080
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

}


resource "aws_launch_configuration" "ecs-launch-configuration" {
  name_prefix   = "ecs-launch-configuration"
  image_id      = ami-09a7bbd08886aafdf
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ecs_autoscale" {
  name                 = "terraform-asg-example"
  launch_configuration = aws_launch_configuration.ecs-launch-configuration
  min_size             = 1
  max_size             = 2

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_cluster" "go-ecs-cluster" {
  name = "go-ecs-cluster"
}

resource "aws_ecs_task_definition" "ecs-task" {
  family                = "ecs-task"
  container_definitions = <<DEFINITION

  [
   {
    "name": "GO-main",
    "image": "Go-image",
    "cpu": 2,
    "memory": 256,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
      }
    ]
  },
  {
    "name": "redis",
    "image": "redis-image",
    "cpu": 2,
    "memory": 256,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 6379,
        "hostPort": 6379
      }
    ]
  },
  {
    "name": "kafka",
    "image": "kafka-image",
    "cpu": 2,
    "memory": 256,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 9092,
        "hostPort": 9092
      }
    ]
  }
]
DEFINITION

  volume {
    name      = "ecs-task-storage"
    host_path = "/ecs/service-storage"
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [ap-south-1]"
  }
}


resource "aws_ecs_service" "Go-redis-kafka" {
  name            = "Go-redis-kafka"
  cluster         = aws_ecs_cluster.go-ecs-cluster.id
  task_definition = aws_ecs_task_definition.ecs-task.arn
  desired_count   = 1
  iam_role        = aws_iam_role.ecs_role.arn
  depends_on      = [aws_iam_role_policy.ecs_policy]

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.ecs-target-group.arn
    container_name   = "Go"
    container_port   = 8080
  }
  
}