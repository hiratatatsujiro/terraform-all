terraform {
  #tfstateファイルをS3に配置する(配置先のS3は事前に作成済み)
  backend "s3" {
    bucket         = "hirata-automation-terraform-bucket-990209979466"
    region         = "us-east-1"
    key            = "automation/terraform/terraform.tfstate"
    dynamodb_table = "hirata-automation-sessionlocl-dynamodb"
  }
}