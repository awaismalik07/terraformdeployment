#Backend to be used to store the tfstate file for remote access
#and dynamodb table for locking/unlocking. specify bucket name and dynamodb table name.
#dynamodb table must have LoackID as partition key.
terraform {
  backend "s3" {
    bucket         = "awais-terraform-state-bucket"
    key            = "global/terraform.tfstate"     
    region         = "us-east-1"           
    dynamodb_table = "awais-terra-locks"                
    encrypt        = true                     
  }
}
