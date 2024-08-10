variable "data_collection_account_id" {
  description = "AccountId of where the collector is deployed"
  type        = string
}

variable "include_compute_optimizer_module" {
  description = "Collects AWS Compute Optimizer service recommendations"
  type        = bool
  default     = true
}

variable "include_cost_anomaly_module" {
  description = "Collects AWS Cost Explorer Cost Anomalies Recommendations"
  type        = bool
  default     = true
}

variable "include_rightsizing_module" {
  description = "Collects AWS Cost Explorer Rightsizing Recommendations"
  type        = bool
  default     = true
}

variable "include_backup_module" {
  description = "Collects TransitGateway from your accounts"
  type        = bool
  default     = true
}

variable "include_cost_optimization_hub_module" {
  description = "Collects CostOptimizationHub Recommendations from your accounts"
  type        = bool
  default     = true
}

variable "include_health_events_module" {
  description = "Collects AWS Health Events from your accounts"
  type        = bool
  default     = true
}

variable "include_license_manager_module" {
  description = "Collects Marketplace Licensing Information from your accounts"
  type        = bool
  default     = true
}
