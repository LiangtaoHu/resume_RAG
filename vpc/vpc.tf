// Creating the VPC and VPC Endpoints to access AWS Bedrock and AWS OpenSearchServerless

resource "aws_s3_bucket" "app_lb_bucket" {
    bucket = "liangtaohu-res-app-lb"
}

resource "aws_vpc" "chatbot_vpc" {
    cidr_block = "192.168.0.0/16"
}

resource "aws_internet_gateway" "int_gw" {
    vpc_id = aws_vpc.chatbot_vpc.id
}

resource "aws_vpc_endpoint" "bedrock" {
    vpc_id = aws_vpc.chatbot_vpc.id
    service_name = "com.amazonaws.us-east-1.bedrock-runtime"
    vpc_endpoint_type = "Interface"

    security_group_ids = [] // Change to endpoint security group
    subnet_ids = [] // Who can connect to the vpc endpoint
    private_dns_enabled = true // Explain what this does
}