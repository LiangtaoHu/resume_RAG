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

// NAT gateway might be useless, we can just replace with an ALB for our usecase of user initated connections
# resource "aws_nat_gateway" "nat_gw" {
#     vpc_id = aws_vpc.chatbot_vpc.id
#     availability_mode = "regional"
#     # Automatic Mode for discovery and allocation of EIPs to subnets/AZs
# }

// Add public subnets for ALB, Internet Gateway, etc.
resource "aws_subnet" "subnets" {
    for_each = tomap({
        private-subnet-1a = ["192.168.0.0/26", "us-east-1a"]
        private-subnet-1b = ["192.168.1.0/26", "us-east-1b"]
        private-subnet-1c = ["192.168.2.0/26", "us-east-1c"]
        public-subnet-1a = ["192.168.3.0/26", "us-east-1a"]
        public-subnet-1b = ["192.168.4.0/26", "us-east-1b"]
    })
    vpc_id = aws_vpc.chatbot_vpc.id
    cidr_block = each.value[0]
    availability_zone = each.value[1]
    tags = {
        Name = each.key
    }
}

resource "aws_lb" "app_lb" {
    name = "app-lb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.alb_sec.id]
    subnets = [
         for key, subnet in aws_subnet.subnets : subnet.id if length(regexall("^public-subnet", key)) > 0
    ]
    access_logs {
      bucket = aws_s3_bucket.app_lb_bucket.id
      enabled = true
    }
}

/*
Actions user can take:
- Upload resume
    - This would be done with an S3 Presigned URL via ALB to Lambda, this path would be used by the main ASG as well. 
- Converse with chatbot to optimize resume
    - Selecting S3 resume or sending a new one
    - Choose Job Listing or sending a new one
    - Asking and optimizing
- Upload Job listing beforehand
    - Same thing as upload resume but it just takes a link?
*/
resource "aws_lb_target_group" "parse_listing" {
    name = "parse-job-listing"
    port = 80
    protocol = "HTTPS"
    vpc_id = aws_vpc.chatbot_vpc.id
    target_type = "lambda"
}

resource "aws_lb_target_group" "upload_resume" {
    name = "upload-resume"
    port = 80
    protocol = "HTTPS"
    vpc_id = aws_vpc.chatbot_vpc.id
    target_type = "lambda"
}

resource "aws_lb_target_group" "alb_target_group" {
    name = "alb-target-group"
    port = 80
    protocol = "HTTPS"
    vpc_id = aws_vpc.chatbot_vpc.id
    target_type = "instance"
    // Health check?
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.app_lb.arn
    port              = 80
    protocol          = "HTTPS"
  
    default_action {
        type = "authenticate-cognito"
        authenticate_cognito {
          user_pool_arn = aws_cognito_user_pool.user_pool.arn
          user_pool_client_id = aws_cognito_user_pool_client.alb_cog_client.id
          user_pool_domain = aws_cognito_user_pool_domain.alb_cog_domain.domain
        }
    } 
}

resource "aws_lb_listener_rule" "rule_upload_resume" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.upload_resume.arn
    }
    condition {
      path_pattern {
        values = ["/upload-resume"]
      }
    }
}

resource "aws_lb_listener_rule" "rule_parse_listing" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.parse_listing.arn
    }
    condition {
      path_pattern {
        values = ["/parse-listing"]
      }
    }
}

resource "aws_lb_listener_rule" "main" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.alb_target_group.arn
    }
    condition {
      path_pattern {
        values = ["/converse"]
      }
    }
}

resource "aws_autoscaling_attachment" "asg_attachment_alb" {
  autoscaling_group_name = aws_autoscaling_group.ASG.name
  lb_target_group_arn    = aws_lb_target_group.alb_target_group.arn
}

/* 
    When implementing an ASG, we need to keep track of the following information:
        - Name                                                      DONE
        - Max/Min/Desired size                                      DONE but needs clarification
        - Health check                                              DONE but needs clarification
        - Scaling Method
            - Cooldown period
        - Mix of instance types (e.g. spot instances)           
        - Specified Launch Template (Defined in ec2.tf)             
        - Lifehook Cycles?                                          
        - Notifications/Logs/Etc.
        - Remember to make it multi-AZ across our private subnets   DONE
*/
resource "aws_launch_template" "ec2_web_server" {
    name = "web_server_template"
}

resource "aws_autoscaling_group" "ASG" {
    name = "llm_ASG"
    max_size = 3
    min_size = 6
    desired_capacity = 4
    health_check_type = "ELB"
    vpc_zone_identifier = [for subnet in aws_subnet.subnets: subnet.id]
    // We want to have a group of full of ec2 instances on demand, no spot instances or anything for now
    // Launch Template/Config/Mixed instance block
    // No need for lifehook cycles for now
    launch_template {
        id = aws_launch_template.ec2_web_server.id
        version = "$Latest"
    }

    traffic_source {
      identifier = aws_lb.app_lb.arn
      type = "elbv2"
    }
}

resource "aws_security_group" "alb_sec" {
    name = "alb_sec"
    description = "Allow users to send requests to the ALB and send requests to the ec2 instances"
    vpc_id = aws_vpc.chatbot_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_sec_ingress" {
    security_group_id = aws_security_group.alb_sec.id
    cidr_ipv4 = "0.0.0.0/0"
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_sec_egress" {
    security_group_id = aws_security_group.alb_sec.id
    referenced_security_group_id = aws_security_group.ec2_sec.id
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
}

resource "aws_security_group" "ec2_sec" {
    name = "ec2_sec"
    description = "Allow ALB to connect to EC2 instances both inbound and outbound traffic"
    vpc_id = aws_vpc.chatbot_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_ipv4" {
    security_group_id = aws_security_group.ec2_sec.id
    referenced_security_group_id = aws_security_group.alb_sec.id
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
}

resource "aws_vpc_endpoint" "bedrock" {
    vpc_id = aws_vpc.chatbot_vpc.id
    service_name = "com.amazonaws.us-east-1.bedrock-runtime"
    vpc_endpoint_type = "Interface"

    security_group_ids = [] // Change to endpoint security group
    subnet_ids = [] // Who can connect to the vpc endpoint
    private_dns_enabled = true // Explain what this does
}