
variable "destination_bucket" {
  description = "Name of the S3 Bucket to be created to hold data information"
  type        = string
}

variable "destination_bucket_arn" {
  description = "ARN of the S3 Bucket that exists or needs to be created to hold rightsizing information"
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
  description = "Arn of lambda for Analytics"
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

variable "step_function_execution_role_arn" {
  description = "Common role for Step Function execution"
  type        = string
}

variable "scheduler_execution_role_arn" {
  description = "Common role for module Scheduler execution"
  type        = string
}
