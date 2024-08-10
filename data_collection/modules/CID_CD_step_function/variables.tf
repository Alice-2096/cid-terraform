variable "database_name" {
  description = "Name of the Athena database to be created to hold lambda information"
  type        = string
  default     = "optimization_data"
}

variable "destination_bucket" {
  description = "Name of the S3 Bucket to be created to hold data information"
  type        = string
}

variable "destination_bucket_arn" {
  description = "ARN of the S3 Bucket that exists or needs to be created to hold rightsizing information"
  type        = string
}

variable "multi_account_role_name" {
  description = "Name of the IAM role deployed in all accounts which can retrieve AWS Data."
  type        = string
}

variable "account_collector_lambda_arn" {
  description = "ARN of the Account Collector Lambda"
  type        = string 
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function"
  type        = string
}

variable "cid_data_name" {
  description = "The name of what this cf is doing."
  type        = string
  default     = "trusted-advisor"
}

variable "glue_role_arn" {
  description = "ARN for the Glue Crawler role"
  type        = string
}

variable "schedule" {
  description = "EventBridge Schedule to trigger the data collection"
  type        = string
  default     = "rate(14 days)"
}

variable "resource_prefix" {
  description = "This prefix will be placed in front of all roles created. Note you may wish to add a dash at the end to make more readable"
  type        = string
}

variable "lambda_analytics_arn" {
  description = "ARN of lambda for Analytics"
  type        = string
}

variable "account_collector_lambda_arn" { ## ??? 
  description = "ARN of the Account Collector Lambda"
  type        = string
}

variable "code_bucket" {
  description = "Source code bucket"
  type        = string
}

variable "step_function_template" {
  description = "S3 key to the JSON template for the StepFunction"
  type        = string
}


#! have not defined 
variable "step_function_execution_role_arn" {
  description = "Common role for Step Function execution"
  type        = string
}

variable "scheduler_execution_role_arn" {
  description = "Common role for module Scheduler execution"
  type        = string
}
