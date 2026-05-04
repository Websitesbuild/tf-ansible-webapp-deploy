output "public_ip" {
  value = aws_instance.VM[*].public_ip
}