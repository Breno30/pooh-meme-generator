resource "aws_dynamodb_table" "project_table" {
  name         = local.dynamodb_table_name
  attribute {
    name = "input_text"
    type = "S"
  }
  hash_key     = "input_text"
  read_capacity  = 5
  write_capacity = 5
}