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


resource "aws_vpc" "vpc" {
  cidr_block = "192.168.0.0/24"

  tags = { name = "서브웨이 VPC" }
}

resource "aws_subnet" "subnet1-ex" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.0.0/26"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-2a"

  tags = { name = "spring 서버 외부망" }
}

resource "aws_subnet" "subnet1-in" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "192.168.0.128/27"
  availability_zone = "ap-northeast-2a"

  tags = { name = "내부망 서브넷" }
}

resource "aws_subnet" "subnet2-ex" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.0.64/26"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-2b"

  tags = { name = "데이터베이스 접근용 서버 외부망" }
}


resource "aws_subnet" "subnet2-in" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "192.168.0.160/27"
  availability_zone = "ap-northeast-2b"

  tags = { name = "데이터베이스 서브넷" }
}

resource "aws_security_group" "application-sg" {
  vpc_id = aws_vpc.vpc.id
  name   = "security-group-ex"

  ingress {
    from_port   = 443
    to_port     = 443
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


resource "aws_security_group" "db-sg" {
  vpc_id = aws_vpc.vpc.id
  name   = "security-group-in"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.subnet2-ex.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { name = "데이터베이스 접근 보안 그룹" }
}

resource "aws_security_group" "allow-ssh" {
  vpc_id = aws_vpc.vpc.id
  name   = "security-group-manage"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["121.176.58.136/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_instance" "spring-server" {
  ami           = "ami-062cf18d655c0b1e8" # 사용할 AMI ID
  instance_type = "t3.micro"              # 인스턴스 유형

  subnet_id = aws_subnet.subnet1-ex.id

  vpc_security_group_ids = [
    aws_security_group.application-sg.id,
    aws_security_group.allow-ssh.id,
  ]

  key_name = "playground" # SSH 키 페어 이름

  tags = {
    Name = "spring-server"
  }
}

resource "aws_instance" "database-server" {
  ami           = "ami-062cf18d655c0b1e8" # 사용할 AMI ID
  instance_type = "t3.micro"              # 인스턴스 유형

  subnet_id = aws_subnet.subnet2-in.id

  vpc_security_group_ids = [
    aws_security_group.db-sg.id
  ]

  key_name = "playground" # SSH 키 페어 이름

  tags = {
    Name = "spring-server"
  }

}

resource "aws_internet_gateway" "playground-igw" {
  vpc_id = aws_vpc.vpc.id
  tags   = { name = "인터넷 게이트웨이" }
}

resource "aws_route_table" "playground-rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.playground-igw.id
  }
  tags = {
    Name = "라우팅 테이블"
  }
}
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.subnet1-ex.id
  route_table_id = aws_route_table.playground-rt.id
}

resource "aws_route_table_association" "database-associartion" {
  subnet_id      = aws_subnet.subnet2-ex.id
  route_table_id = aws_route_table.playground-rt.id
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.subnet2-ex.id

  tags = {
    Name = "MyNATGateway"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id # NAT Gateway ID
  }

  tags = {
    Name = "라우팅 테이블"
  }
}

resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.subnet2-in.id
  route_table_id = aws_route_table.playground-rt.id

}

