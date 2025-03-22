terraform {
  backend "s3" {
    bucket         = "eks-terraform-AccID-backend"       
    key            = "eks-cluster/terraform.tfstate"
    region         = "us-east-2"                    
    # dynamodb_table = ""    
    encrypt        = true
  }
}