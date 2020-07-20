provider "aws"{
  profile ="default"
  region ="ap-south-1"
}


resource "tls_private_key" "UDIT" {
  algorithm = "RSA"
}
resource "aws_key_pair" "mykey1"{
  key_name   = "mykey_1"
  public_key = tls_private_key.UDIT.public_key_openssh
}
resource "local_file" "private_key" {
  content  = tls_private_key.UDIT.private_key_pem
  filename = "mykey1.pem"
}

resource "aws_security_group" "Allow_Traffic" {
  name        = "Security_Guard"
  description = "Allow inbound traffic"
  vpc_id      = "vpc-759f821d"

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
     description = "Allow NFS"
     from_port   = 2049
     to_port     = 2049
     protocol    = "tcp"
     cidr_blocks = [ "0.0.0.0/0" ]	
    }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  tags = {
    Name = "Security_Guard"
  }
}






resource "aws_instance" "FIRST_OS" {
  ami           = "ami-0447a12f28fddb066"
  instance_type   = "t2.micro"
  key_name  =  aws_key_pair.mykey1.key_name
  security_groups  = [aws_security_group.Allow_Traffic.name]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.UDIT.private_key_pem
    host     = aws_instance.FIRST_OS.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd git amazon-efs-utils nfs-utils -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
    tags = {
    Name = "TerraFormOS"
  }

}




resource "aws_efs_file_system" "foo" {
  
  creation_token = "foo"

  tags = {
    Name = "foo"
  }
}


resource "aws_efs_mount_target" "mount-target" {

	file_system_id = aws_efs_file_system.foo.id
	subnet_id      = aws_instance.FIRST_OS.subnet_id
  security_groups  = [aws_security_group.Allow_Traffic.id]
  depends_on = [ aws_efs_file_system.foo] 

}


resource "null_resource" "Run_cmds"  {

depends_on = [
    aws_efs_mount_target.mount-target
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.UDIT.private_key_pem
    host     = aws_instance.FIRST_OS.public_ip
  }

provisioner "remote-exec" {
    inline = [
     "sudo mount ${aws_efs_file_system.foo.dns_name}:/  /var/www/html",
     "sudo echo ${aws_efs_file_system.foo.dns_name}:/ /var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
     "sudo git clone https://github.com/Uditanshu0110/EFS_HTML_CODE.git /var/www/html/"
     
    ]
  }
}




output "public_ip"{
value=aws_instance.FIRST_OS.public_ip
}


resource "aws_s3_bucket" "my_first_bucket" {

  bucket = "uditanshuimg"
  acl    = "public-read"


  tags = {
    Name        = "my_first_bucket"
  }

  provisioner "local-exec"{
        command="git clone https://github.com/Uditanshu0110/EFS_HTML_CODE.git UditanshuIMGAGE"
  }
}

resource "aws_s3_bucket_object" "uploadingimages" {
  depends_on=[
      aws_s3_bucket.my_first_bucket
  ]
  key = "TerraForm1.png"
  bucket = aws_s3_bucket.my_first_bucket.bucket
  acl    = "public-read"
  source ="UditanshuIMGAGE/TerraForm1.png"
}

locals {
	s3_origin_id = "S3-${aws_s3_bucket.my_first_bucket.bucket}"
}


resource "aws_cloudfront_distribution" "s3_distribution_network" {
  origin {
    domain_name = aws_s3_bucket.my_first_bucket.bucket_domain_name
   origin_id   = local.s3_origin_id
  }

  enabled     = true
 
 default_cache_behavior {    
     allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id


     forwarded_values {
       query_string = false


       cookies {
         forward = "none"
       }
     }


     viewer_protocol_policy = "allow-all"
    
   }
  


   restrictions {
     geo_restriction {
       restriction_type = "none"
      
     }
    }


   viewer_certificate {
     cloudfront_default_certificate = true
  }
  connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.FIRST_OS.public_ip
        port    = 22
        private_key = tls_private_key.UDIT.private_key_pem
    }
provisioner "remote-exec" {
        inline  = [
            "sudo su << EOF",
            "echo \"<img src='my_first_bucket'>\" >> /var/www/html/udit.html",
            "EOF"
        ]
  
  }
}