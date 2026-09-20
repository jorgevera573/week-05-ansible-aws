variable "aws_profile" {
  description = "Perfil de AWS CLI usado por Terraform (configurado en Windows)."
  type        = string
  default     = "master-semana05"
}

variable "aws_region" {
  description = "Región de AWS donde se crean los recursos."
  type        = string
  default     = "us-east-1"
}

variable "allowed_account_id" {
  description = "ID de cuenta AWS permitido. Obtenido con STS, nunca copiado de una conversación."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.allowed_account_id))
    error_message = "allowed_account_id debe ser un ID de cuenta AWS de 12 dígitos."
  }
}

variable "project_name" {
  description = "Nombre corto del proyecto. Se usa como prefijo de los nombres de recurso."
  type        = string
  default     = "master-semana05"
}

variable "environment" {
  description = "Entorno lógico de la práctica."
  type        = string
  default     = "lab"
}

variable "extra_tags" {
  description = "Etiquetas adicionales que se suman a las etiquetas comunes del proyecto."
  type        = map(string)
  default     = {}
}

# --- Red -------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR IPv4 de la VPC propia de la práctica."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR IPv4 de la subred pública."
  type        = string
  default     = "10.20.1.0/24"
}

variable "availability_zone" {
  description = "Zona de disponibilidad. Vacío = se elige la primera disponible de la región."
  type        = string
  default     = ""
}

# --- Instancia -------------------------------------------------------------

variable "instance_type" {
  description = "Tipo de instancia EC2. Genera cargos mientras esté en ejecución."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = <<-EOT
    AMI oficial de Canonical (Ubuntu Server 24.04 LTS, x86_64) que se quiere fijar.
    Vacío = se resuelve la más reciente mediante consulta EC2 filtrada por propietario
    y nombre. Fijarla en terraform.tfvars hace el despliegue reproducible.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.ami_id == "" || can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id debe estar vacío o tener el formato ami-xxxxxxxx."
  }
}

variable "root_volume_size" {
  description = "Tamaño del disco raíz gp3 en GiB."
  type        = number
  default     = 12
}

# --- Acceso SSH ------------------------------------------------------------

variable "ssh_public_key_path" {
  description = <<-EOT
    Ruta a la clave PÚBLICA SSH existente, accesible desde el equipo donde corre
    Terraform (Windows). Solo se importa la clave pública: Terraform nunca genera
    ni almacena la privada.
  EOT
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "Contenido de la clave pública SSH. Alternativa a ssh_public_key_path si la ruta UNC no es legible."
  type        = string
  default     = ""
}

variable "ssh_private_key_path_wsl" {
  description = "Ruta de la clave privada dentro de WSL. Solo se usa para componer el comando SSH de salida."
  type        = string
  default     = "~/.ssh/master-semana05"
}

variable "ssh_allowed_cidr" {
  description = <<-EOT
    CIDR /32 con la IPv4 pública actual del alumno, única origen permitido para SSH.
    No se admite 0.0.0.0/0.
  EOT
  type        = string

  validation {
    condition = (
      can(cidrhost(var.ssh_allowed_cidr, 0)) &&
      var.ssh_allowed_cidr != "0.0.0.0/0" &&
      tonumber(split("/", var.ssh_allowed_cidr)[1]) >= 24
    )
    error_message = "ssh_allowed_cidr debe ser un CIDR IPv4 valido, distinto de 0.0.0.0/0 y con prefijo /24 o mas restrictivo (se recomienda /32)."
  }
}
