provider "aws" {
  region = "eu-central-1"
}

resource "aws_security_group" "postgres_opendata" {
  name        = "postgres_opendata"
  description = "Allow only postgres inbound."
  
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "allow_pg_opdendata"
  }
}

resource "aws_security_group" "allow_all_opendata_server" {
  name        = "allow_all_opendata_server"
  description = "Allow all inbound/outbound traffic"
  
  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "allow_all_opendata_server"
  }
}

resource "aws_db_instance" "opendata_db" {
    identifier = "opendata-db"
    availability_zone = "eu-central-1a"    
    allocated_storage = 5
    storage_type = "gp2"    
    engine = "postgres"
    engine_version = "9.6.3"
    instance_class = "db.t2.micro"
    name = "xanadu2"
    port = 5432
    username = "stefan"
    password = "ParadiseByTheDashboardLight"
    multi_az = false
    publicly_accessible = true
    backup_retention_period = "0"
    apply_immediately = "true"
    auto_minor_version_upgrade = false
    vpc_security_group_ids = ["${aws_security_group.postgres_opendata.id}"]    
    skip_final_snapshot = true
}

resource "aws_instance" "opendata_server" {
  ami = "ami-82be18ed" 
  availability_zone = "eu-central-1a"  
  instance_type = "t2.micro"
  key_name = "aws-demo"
  vpc_security_group_ids = ["${aws_security_group.allow_all_opendata_server.id}"]
  
  user_data = <<-EOF
              #!/bin/bash
              yum -y install java-1.8.0
              yum -y remove java-1.7.0-openjdk              
              yum -y install git
              cd /usr/local && \
              curl -L https://services.gradle.org/distributions/gradle-4.2-bin.zip -o gradle-4.2-bin.zip && \
              unzip gradle-4.2-bin.zip && \
              rm gradle-4.2-bin.zip
              export GRADLE_HOME=/usr/local/gradle-4.2
              export PATH=$PATH:$GRADLE_HOME/bin
              git clone https://github.com/edigonzales/opendata-av-ilivalidator.git /tmp/opendata-av-import
              sed -i -e 's/999.999.999.999/${aws_db_instance.opendata_db.address}/g' /tmp/opendata-av-import/gretl/build.gradle
              gradle -p /tmp/opendata-av-import/gretl/ -I /tmp/opendata-av-import/gretl/init.gradle initDatabase

              #/tmp/aws-demo/use_cases/04/av_avdpool_ng/gradlew -p /tmp/aws-demo/use_cases/04/av_avdpool_ng/ initDatabase --no-daemon
              #/tmp/aws-demo/use_cases/04/av_avdpool_ng/gradlew -p /tmp/aws-demo/use_cases/04/av_avdpool_ng/ downloadFiles #unzipFiles importFiles --no-daemon
              # shutdown -h now
              EOF

  tags {
    Name = "opendata_server"
  }
}

output "rds-address" {
  value = "${aws_db_instance.opendata_db.address}"
}
output "ec2-ip" {
  value = "${aws_instance.opendata_server.public_ip}"  
}
