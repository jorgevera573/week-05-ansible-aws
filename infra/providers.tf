provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Cinturón de seguridad: si las credenciales resueltas no pertenecen a esta
  # cuenta, Terraform aborta antes de tocar nada.
  allowed_account_ids = [var.allowed_account_id]

  default_tags {
    tags = local.common_tags
  }
}
