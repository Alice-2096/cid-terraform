locals {
  resource_prefix = "CID-DC-"
}

variable "schedule" {
  description = "EventBridge Schedule to trigger the data collection"
  type        = string
  default     = "rate(14 days)"
}

# variable "code_bucket" {
#   description = "Source code bucket"
#   type        = string
# }

# variable "step_function_template" {
#   description = "S3 key to the JSON template for the StepFunction"
#   type        = string
# }
