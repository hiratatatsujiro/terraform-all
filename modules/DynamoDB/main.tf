resource "aws_dynamodb_table" "dynamodb" {
  name           = "hirata-automation-sessionlocl-dynamodb"  # テーブル名を指定
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 5
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "hirata-automation-sessionlocl-dynamodb"
  }
}