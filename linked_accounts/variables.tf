variable "data_collection_account_id" {
  description = "AccountId of where the collector is deployed"
  type        = string
}

variable "include_ta_module" {
  description = "Collects AWS Trusted Advisor recommendations data"
  type        = string
  default     = "no"
}

variable "include_inventory_collector_module" {
  description = "Collects data about AMIs, EBS volumes, and snapshots"
  type        = string
  default     = "no"
}

variable "include_ecs_chargeback_module" {
  description = "Collects data on ECS Tasks costs"
  type        = string
  default     = "no"
}

variable "include_rds_utilization_module" {
  description = "Collects RDS CloudWatch metrics from your accounts"
  type        = string
  default     = "no"
}

variable "include_budgets_module" {
  description = "Collects budgets from your accounts"
  type        = string
  default     = "no"
}

variable "include_transit_gateway_module" {
  description = "Collects TransitGateway from your accounts"
  type        = string
  default     = "no"
}
