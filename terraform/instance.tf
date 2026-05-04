resource "aws_security_group" "VM_SG" {
  name        = "VM_SG"
  description = "Allow SSH and HTTP"
  ingress {
    to_port     = 22
    from_port   = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    to_port     = 80
    from_port   = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    to_port     = 8081
    from_port   = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    to_port     = 0
    from_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "EC2_Key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "VM" {
  ami                         = var.AMI
  instance_type               = var.Type
  count                       = var.Count
  key_name                    = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids      = [aws_security_group.VM_SG.id]
  user_data_replace_on_change = true

  tags = {
    name = "VM-${count.index}"
  }

  user_data = <<-EOF
    #!/bin/bash

    adduser testuser --disabled-password --gecos ""
    echo "testuser:testuser" | chpasswd

    echo "testuser ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/testuser
    chmod 440 /etc/sudoers.d/testuser

    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    if [ -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf ]; then
      sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
    fi

    systemctl restart ssh

    mkdir -p /home/testuser/.ssh
    chmod 700 /home/testuser/.ssh
    cp /home/ubuntu/.ssh/authorized_keys /home/testuser/.ssh/authorized_keys
    chmod 600 /home/testuser/.ssh/authorized_keys
    chown -R testuser:testuser /home/testuser/.ssh
  EOF
}

resource "null_resource" "ansible_inevntory" {
  depends_on = [aws_instance.VM]
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOT
      sudo sed -i '/\[webservers\]/,/^$/d' /home/labuser/project/ansible/inventory/hosts.ini
      sudo bash -c 'echo "[webservers]" >> /home/labuser/project/ansible/inventory/hosts.ini'
      %{for ip in aws_instance.VM[*].public_ip ~}
      sudo bash -c 'echo "${ip} ansible_user=testuser ansible_ssh_private_key_file=~/.ssh/id_rsa" >> /home/labuser/project/ansible/inventory/hosts.ini'
      %{endfor ~}
    EOT
  }
}