locals {
  resource_prefix = "CID-DC-"
}


variable "management_account_id" {
  description = "List of Payer IDs you wish to collect data for."
  type        = string
}
