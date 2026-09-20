output "instance_id" {
  description = "ID de la instancia EC2 creada."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "IPv4 publica estable (Elastic IP) a la que debe apuntar el registro DNS A."
  value       = aws_eip.web.public_ip
}

output "public_dns" {
  description = "Nombre DNS publico asociado a la Elastic IP (si AWS lo proporciona)."
  value       = aws_eip.web.public_dns
}

output "instance_public_dns" {
  description = "Nombre DNS publico de la instancia segun EC2 (puede estar vacio hasta asociar la EIP)."
  value       = aws_instance.web.public_dns
}

output "ssh_user" {
  description = "Usuario del sistema para las AMI de Ubuntu."
  value       = "ubuntu"
}

output "ssh_command_wsl" {
  description = "Comando SSH listo para ejecutar desde Ubuntu WSL."
  value       = "ssh -i ${var.ssh_private_key_path_wsl} ubuntu@${aws_eip.web.public_ip}"
}

output "ami_id" {
  description = "AMI realmente utilizada. Anotarla para reproducibilidad."
  value       = local.ami_id
}

output "ami_name" {
  description = "Nombre de la AMI resuelta por la consulta EC2 (vacio si se fijo ami_id manualmente)."
  value       = var.ami_id != "" ? "(fijada en variables)" : data.aws_ami.ubuntu_2404.name
}

output "availability_zone" {
  description = "Zona de disponibilidad utilizada."
  value       = local.availability_zone
}

output "security_group_id" {
  description = "ID del security group aplicado a la instancia."
  value       = aws_security_group.web.id
}

output "vpc_id" {
  description = "ID de la VPC propia de la practica."
  value       = aws_vpc.this.id
}
