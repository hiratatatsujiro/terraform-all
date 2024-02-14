terraform {
  #AWSプロバイダーのバージョン指定
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.51.0"
    }
  }
}
#AWSプロバイダーの定義
provider "aws" {
  region = "us-east-1"
}
