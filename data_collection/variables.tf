locals {
  resource_prefix = "CID-DC-"
}


variable "management_account_id" {
  description = "List of Payer IDs you wish to collect data for."
  type        = string
}

variable "enabled_regions" {
  type        = string
  description = "List of regions to collect data from."
  default     = "us-east-1"
}
