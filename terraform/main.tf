terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-northeast-2"
}

# *************************************************
# VPC 생성
# *************************************************

resource "aws_vpc" "main-vpc" {
  cidr_block = "192.168.0.0/24"
  tags = { Name = "미션 VPC"}

}


# *************************************************
# 서브넷 구성
# *************************************************


resource "aws_subnet" "public-a" {
  vpc_id = aws_vpc.main-vpc.id
  cidr_block = "192.168.0.0/26"
  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = { Name = "외부망 a 가용영역"}
}

resource "aws_subnet" "public-c" {
  vpc_id = aws_vpc.main-vpc.id
  cidr_block = "192.168.0.64/26"
  availability_zone = "ap-northeast-2c"
  tags = { Name = "외부망 c 가용영역"}
}

resource "aws_subnet" "internal-a" {
  vpc_id = aws_vpc.main-vpc.id
  cidr_block = "192.168.0.128/27"
  availability_zone = "ap-northeast-2a"
  tags = { Name = "내부망 a 가용영역"}
}

resource "aws_subnet" "internal-c" {
  vpc_id = aws_vpc.main-vpc.id
  cidr_block = "192.168.0.160/27"
  availability_zone = "ap-northeast-2c"
  tags = { Name = "내부망 c 가용영역"}
}



# *************************************************
# 보안 그룹
# *************************************************

resource "aws_security_group" "allow-ssh" {
  vpc_id = aws_vpc.main-vpc.id
  tags = { Name = "ssh 허용"}

  ingress {
    protocol = "tcp"
    to_port = 22
    from_port = 22
    cidr_blocks = ["175.215.120.104/32"]

  }

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    to_port = 0
    from_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# *************************************************
# 라우팅 테이블
# *************************************************

resource "aws_route_table" "route-table"{
  vpc_id = aws_vpc.main-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }


  tags = { Name = "미션 라우팅 테이블"}
}


# *************************************************
# 인터넷 게이트웨이
# *************************************************

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.main-vpc.id

  tags = {
    Name = "미션-인터넷-게이트웨이"
  }
}


# *************************************************
# 서브넷 - 라우팅 테이블 연결
# *************************************************

resource "aws_route_table_association" "associate-public-route-table" {
  route_table_id = aws_route_table.route-table.id
  subnet_id = aws_subnet.public-a.id
}



# *************************************************
# EC2 외부망 A 가용영역
# *************************************************


resource "aws_instance" "application-1" {
  ami = "ami-062cf18d655c0b1e8" # 우분투 이미지
  subnet_id = aws_subnet.public-a.id
  instance_type = "t2.medium"

  key_name = "playground"

  lifecycle {
    ignore_changes = [key_name]
  }

  security_groups = [
    aws_security_group.allow-ssh.id
  ]

  tags = { Name ="애플리케이션1"}
}

# *************************************************
# EC2 내부망 C 가용영역
# *************************************************

resource "aws_instance" "db-1"{
  ami = "ami-062cf18d655c0b1e8" # 우분투 이미지
  subnet_id = aws_subnet.internal-c.id
  instance_type = "t2.medium"

  security_groups = [
    aws_security_group.allow-ssh.id
  ]


  tags = { Name ="데이터베이스"}

}


# *************************************************
# ** 탄력적 ip 생성
# *************************************************

resource "aws_eip" "private-ec2-eip" {
  vpc = true
  instance = aws_instance.db-1.id
}


