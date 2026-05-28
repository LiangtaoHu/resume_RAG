// Creating the VPC, ASG, EC2 instances, etc. for the user to be able to start and end a conversation with the resume bot
// User connects an EC2 instance which acts like a server for the webpage and conversation holder, automatic disconnect after a timeout or when user disconnects
// Hides behind an API Gateway?? API gateway helps find asg?? will decide later 

/*
    As a reminder, our VPC needs subnets representing AZs, Internet Gateway, NAT Gateway (dont want people just randomly accessing our EC2 instances)
    an ASG (in a private subnet), Load balancer
    routing tables, NACL, sec groups
*/
resource "aws_s3_bucket" "app_lb_bucket" {
    bucket = "liangtaohu-res-app-lb"
}

resource "aws_vpc" "chatbot_vpc" {
    cidr_block = "192.168.0.0/16"
}

resource "aws_internet_gateway" "int_gw" {
    vpc_id = aws_vpc.chatbot_vpc.id
}

resource "aws_nat_gateway" "nat_gw" {
    vpc_id = aws_vpc.chatbot_vpc.id
    availability_mode = "regional"
    # Automatic Mode for discovery and allocation of EIPs to subnets/AZs
}

resource "aws_lb" "app_lb" {
    name = "app_lb"
    internal = false
    load_balancer_type = "application"
    security_groups = []
    subnets = []
    access_logs {
      bucket = aws_s3_bucket.app_lb_bucket.id
      enabled = true
    }
}