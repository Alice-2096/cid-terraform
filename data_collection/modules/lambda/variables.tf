variable "multi_account_role_name" {
  description = "Name of the IAM role deployed in all accounts which can retrieve AWS Data."
  type        = string
}

variable "destination_bucket" {
  description = "Name of the S3 Bucket to be created to hold data information"
  type        = string
}

variable "destination_bucket_arn" {
  description = "ARN of the S3 Bucket that exists or needs to be created to hold rightsizing information"
  type        = string
}

variable "resource_prefix" {
  description = "This prefix will be placed in front of all roles created. Note you may wish to add a dash at the end to make more readable"
  type        = string
}

variable "cid_data_name" {
  description = "The name of what this cid is doing."
  type        = string
}

variable "database_name" {
  description = "Name of the Athena database to be created to hold lambda information"
  type        = string
  default     = "optimization_data"
}

variable "glue_role_arn" {
  description = "Arn for the Glue Crawler role"
  type        = string
}
