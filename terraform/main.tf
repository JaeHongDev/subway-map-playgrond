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
  tags       = { Name = "미션 VPC" }

}


# *************************************************
# 서브넷 구성
# *************************************************


resource "aws_subnet" "public-a" {
  vpc_id                  = aws_vpc.main-vpc.id
  cidr_block              = "192.168.0.0/26"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags                    = { Name = "외부망 a 가용영역" }
}

resource "aws_subnet" "public-c" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = "192.168.0.64/26"
  availability_zone = "ap-northeast-2c"
  tags              = { Name = "외부망 c 가용영역" }
}

resource "aws_subnet" "internal-a" {
  vpc_id                  = aws_vpc.main-vpc.id
  cidr_block              = "192.168.0.128/27"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags                    = { Name = "관리망 a 가용영역" }
}

resource "aws_subnet" "internal-c" {
  vpc_id            = aws_vpc.main-vpc.id
  cidr_block        = "192.168.0.160/27"
  availability_zone = "ap-northeast-2c"
  tags              = { Name = "내부망 c 가용영역" }
}



# *************************************************
# 보안 그룹
# *************************************************


# bastion security group
resource "aws_security_group" "bastion-ssh" {
  vpc_id = aws_vpc.main-vpc.id

  tags = { Name = "베스천 서버에서 접근하는 ssh" }

  ingress {
    protocol    = "tcp"
    to_port     = 22
    from_port   = 22
    cidr_blocks = ["175.215.120.104/32"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    to_port     = 0
    from_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}


# 베스천 서버에서 접근 가능한 보안 그룹
resource "aws_security_group" "allow-bastion-ssh" {
  vpc_id = aws_vpc.main-vpc.id

  tags = { Name = "베스천 서버의 접근 허용" }

  ingress {
    protocol        = "tcp"
    to_port         = 22
    from_port       = 22
    security_groups = [aws_security_group.bastion-ssh.id]
  }

  ingress {
    protocol        = "icmp"
    to_port         = -1
    from_port       = -1
    security_groups = [aws_security_group.bastion-ssh.id]
  }

  egress {
    to_port     = 0
    from_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}


# allow application -> db
resource "aws_security_group" "allow-internal-db" {
  vpc_id = aws_vpc.main-vpc.id

  tags = { Name = "내부망 데이터베이스 접근" }


  ingress {
    protocol  = "tcp"
    to_port   = 3306
    from_port = 3306

    // https를 허용하는 보안 그룹에서만 접근하도록
    security_groups = [aws_security_group.allow-https-443.id]
  }

}


# allow https

resource "aws_security_group" "allow-https-443" {
  vpc_id = aws_vpc.main-vpc.id

  tags = { Name = "https 허용" }

  ingress {
    protocol    = "tcp"
    to_port     = 443
    from_port   = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# allow http

resource "aws_security_group" "allow-http-80" {
  vpc_id = aws_vpc.main-vpc.id

  tags = { Name = "http 허용" }

  ingress {
    protocol    = "tcp"
    to_port     = 80
    from_port   = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
}



# *************************************************
# public 라우팅 테이블
# *************************************************

resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.main-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }

  tags = { Name = "미션 라우팅 테이블" }
}

# *************************************************
# private 라우팅 테이블
# *************************************************

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.main-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.private-nat-gateway.id
  }

  tags = { Name = "미션 내부망 라우팅 테이블" }
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

# public
resource "aws_route_table_association" "associate-public-route-table" {
  route_table_id = aws_route_table.route-table.id
  subnet_id      = aws_subnet.public-a.id
}


resource "aws_route_table_association" "associate-public-route-table-1" {
  route_table_id = aws_route_table.route-table.id
  subnet_id      = aws_subnet.public-c.id
}

resource "aws_route_table_association" "associate-public-route-table-2" {
  route_table_id = aws_route_table.route-table.id
  subnet_id      = aws_subnet.internal-a.id
}

# private
resource "aws_route_table_association" "associate-private-route-table" {
  route_table_id = aws_route_table.private-route-table.id
  subnet_id      = aws_subnet.internal-c.id
}

# *************************************************
# EC2 외부망 A 가용영역
# *************************************************


resource "aws_instance" "application-1" {
  ami           = "ami-062cf18d655c0b1e8" # 우분투 이미지
  subnet_id     = aws_subnet.public-a.id
  instance_type = "t3.small"

  key_name = "playground"

  lifecycle {
    ignore_changes = [key_name, security_groups]
  }

  security_groups = [
    aws_security_group.allow-bastion-ssh.id,
    aws_security_group.allow-https-443.id,
    aws_security_group.allow-http-80.id
  ]

  tags = { Name = "애플리케이션1" }
}

# *************************************************
# EC2 내부망 C 가용영역
# *************************************************

resource "aws_instance" "db-1" {
  ami           = "ami-062cf18d655c0b1e8" # 우분투 이미지
  subnet_id     = aws_subnet.internal-c.id
  instance_type = "t3.small"

  key_name = "playground"

  security_groups = [
    aws_security_group.allow-bastion-ssh.id,
    aws_security_group.allow-internal-db.id
  ]

  tags = { Name = "데이터베이스" }

}

# *************************************************
# EC2 관리망 a 가용영역 ()
# *************************************************

resource "aws_instance" "bastion-1" {
  ami           = "ami-062cf18d655c0b1e8" # 우분투 이미지
  subnet_id     = aws_subnet.internal-a.id
  instance_type = "t3.micro"

  key_name = "playground"


  security_groups = [
    aws_security_group.bastion-ssh.id
  ]

  tags = { Name = "베스천 서버" }
}


# *************************************************
# ** 탄력적 ip 생성
# *************************************************

resource "aws_eip" "private-ec2-eip" {
  vpc      = true
  instance = aws_instance.db-1.id
}

resource "aws_eip" "public-ng-eip" {
  vpc = true
}

# *************************************************
# ** nat gateway
# *************************************************

resource "aws_nat_gateway" "private-nat-gateway" {
  allocation_id = aws_eip.public-ng-eip.id
  subnet_id     = aws_subnet.public-c.id

  tags = { Name = "미션 nat 게이트웨이" }
}