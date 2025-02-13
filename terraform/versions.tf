terraform {
  required_version = ">=1.5.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.87.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
