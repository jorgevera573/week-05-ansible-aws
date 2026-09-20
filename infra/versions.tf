terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.65"
    }
  }

  # Estado local en infra/terraform.tfstate (backend por defecto).
  # Está excluido de Git: ver .gitignore en la raíz del repositorio.
}
