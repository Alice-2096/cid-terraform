locals {
  resource_prefix = "CID-DC-"
  ServicesMapPricing = {
    AmazonRDS = {
      path      = "rds"
      partition = [{ Name = "region", Type = "string" }]
      fields = [
        { Type = "string", Name = "sku" },
        { Type = "string", Name = "offertermcode" },
        { Type = "string", Name = "ratecode" },
        { Type = "string", Name = "termtype" },
        { Type = "string", Name = "pricedescription" },
        { Type = "string", Name = "effectivedate" },
        { Type = "string", Name = "startingrange" },
        { Type = "string", Name = "endingrange" },
        { Type = "string", Name = "unit" },
        { Type = "double", Name = "priceperunit" },
        { Type = "string", Name = "currency" },
        { Type = "string", Name = "relatedto" },
        { Type = "string", Name = "leasecontractlength" },
        { Type = "string", Name = "purchaseoption" },
        { Type = "string", Name = "offeringclass" },
        { Type = "string", Name = "product family" },
        { Type = "string", Name = "servicecode" },
        { Type = "string", Name = "location" },
        { Type = "string", Name = "location type" },
        { Type = "string", Name = "instance type" },
        { Type = "string", Name = "current generation" },
        { Type = "string", Name = "instance family" },
        { Type = "string", Name = "vcpu" },
        { Type = "string", Name = "physical processor" },
        { Type = "string", Name = "clock speed" },
        { Type = "string", Name = "memory" },
        { Type = "string", Name = "storage" },
        { Type = "string", Name = "network performance" },
        { Type = "string", Name = "processor architecture" },
        { Type = "string", Name = "storage media" },
        { Type = "string", Name = "volume type" },
        { Type = "string", Name = "min volume size" },
        { Type = "string", Name = "max volume size" },
        { Type = "string", Name = "engine code" },
        { Type = "string", Name = "database engine" },
        { Type = "string", Name = "database edition" },
        { Type = "string", Name = "license model" },
        { Type = "string", Name = "deployment option" },
        { Type = "string", Name = "group" },
        { Type = "string", Name = "group description" },
        { Type = "string", Name = "usagetype" },
        { Type = "string", Name = "operation" },
        { Type = "string", Name = "acu" },
        { Type = "string", Name = "dedicated ebs throughput" },
        { Type = "string", Name = "deployment model" },
        { Type = "string", Name = "enhanced networking supported" },
        { Type = "string", Name = "instance type family" },
        { Type = "string", Name = "normalization size factor" },
        { Type = "string", Name = "pricing unit" },
        { Type = "string", Name = "processor features" },
        { Type = "string", Name = "region code" },
        { Type = "string", Name = "servicename" },
        { Type = "string", Name = "volume name" },
        { Type = "string", Name = "engine media type" }
      ]
    }
    AmazonEC2 = {
      path      = "ec2"
      partition = [{ Name = "region", Type = "string" }]
      fields = [
        { Type = "string", Name = "sku" },
        { Type = "string", Name = "offertermcode" },
        { Type = "string", Name = "ratecode" },
        { Type = "string", Name = "termtype" },
        { Type = "string", Name = "pricedescription" },
        { Type = "string", Name = "effectivedate" },
        { Type = "string", Name = "startingrange" },
        { Type = "string", Name = "endingrange" },
        { Type = "string", Name = "unit" },
        { Type = "double", Name = "priceperunit" },
        { Type = "string", Name = "currency" },
        { Type = "string", Name = "relatedto" },
        { Type = "string", Name = "leasecontractlength" },
        { Type = "string", Name = "purchaseoption" },
        { Type = "string", Name = "offeringclass" },
        { Type = "string", Name = "product family" },
        { Type = "string", Name = "servicecode" },
        { Type = "string", Name = "location" },
        { Type = "string", Name = "location type" },
        { Type = "string", Name = "instance type" },
        { Type = "string", Name = "current generation" },
        { Type = "string", Name = "instance family" },
        { Type = "string", Name = "vcpu" },
        { Type = "string", Name = "physical processor" },
        { Type = "string", Name = "clock speed" },
        { Type = "string", Name = "memory" },
        { Type = "string", Name = "storage" },
        { Type = "string", Name = "network performance" },
        { Type = "string", Name = "processor architecture" },
        { Type = "string", Name = "storage media" },
        { Type = "string", Name = "volume type" },
        { Type = "string", Name = "max volume size" },
        { Type = "string", Name = "max iops/volume" },
        { Type = "string", Name = "max iops burst performance" },
        { Type = "string", Name = "max throughput/volume" },
        { Type = "string", Name = "provisioned" },
        { Type = "string", Name = "tenancy" },
        { Type = "string", Name = "ebs optimized" },
        { Type = "string", Name = "operating system" },
        { Type = "string", Name = "license model" },
        { Type = "string", Name = "group" },
        { Type = "string", Name = "group description" },
        { Type = "string", Name = "transfer type" },
        { Type = "string", Name = "from location" },
        { Type = "string", Name = "from location type" },
        { Type = "string", Name = "to location" },
        { Type = "string", Name = "to location type" },
        { Type = "string", Name = "usagetype" },
        { Type = "string", Name = "operation" },
        { Type = "string", Name = "availabilityzone" },
        { Type = "string", Name = "capacitystatus" },
        { Type = "string", Name = "classicnetworkingsupport" },
        { Type = "string", Name = "dedicated ebs throughput" },
        { Type = "string", Name = "ecu" },
        { Type = "string", Name = "elastic graphics type" },
        { Type = "string", Name = "enhanced networking supported" },
        { Type = "string", Name = "from region code" },
        { Type = "string", Name = "gpu" },
        { Type = "string", Name = "gpu memory" },
        { Type = "string", Name = "instance" },
        { Type = "string", Name = "instance capacity - 10xlarge" },
        { Type = "string", Name = "instance capacity - 12xlarge" },
        { Type = "string", Name = "instance capacity - 16xlarge" },
        { Type = "string", Name = "instance capacity - 18xlarge" },
        { Type = "string", Name = "instance capacity - 24xlarge" },
        { Type = "string", Name = "instance capacity - 2xlarge" },
        { Type = "string", Name = "instance capacity - 32xlarge" },
        { Type = "string", Name = "instance capacity - 4xlarge" },
        { Type = "string", Name = "instance capacity - 8xlarge" },
        { Type = "string", Name = "instance capacity - 9xlarge" },
        { Type = "string", Name = "instance capacity - large" },
        { Type = "string", Name = "instance capacity - medium" },
        { Type = "string", Name = "instance capacity - metal" },
        { Type = "string", Name = "instance capacity - xlarge" },
        { Type = "string", Name = "instancesku" },
        { Type = "string", Name = "intel avx2 available" },
        { Type = "string", Name = "intel avx available" },
        { Type = "string", Name = "intel turbo available" },
        { Type = "string", Name = "marketoption" },
        { Type = "string", Name = "normalization size factor" },
        { Type = "string", Name = "physical cores" },
        { Type = "string", Name = "pre installed s/w" },
        { Type = "string", Name = "processor features" },
        { Type = "string", Name = "product type" },
        { Type = "string", Name = "region code" },
        { Type = "string", Name = "resource type" },
        { Type = "string", Name = "servicename" },
        { Type = "string", Name = "snapshotarchivefeetype" },
        { Type = "string", Name = "to region code" },
        { Type = "string", Name = "volume api name" },
        { Type = "string", Name = "vpcnetworkingsupport" }
      ]
    }
    AmazonElastiCache = {
      path      = "elasticache"
      partition = [{ Name = "region", Type = "string" }]
      fields = [
        { Type = "string", Name = "sku" },
        { Type = "string", Name = "offertermcode" },
        { Type = "string", Name = "ratecode" },
        { Type = "string", Name = "termtype" },
        { Type = "string", Name = "pricedescription" },
        { Type = "string", Name = "effectivedate" },
        { Type = "string", Name = "startingrange" },
        { Type = "string", Name = "endingrange" },
        { Type = "string", Name = "unit" },
        { Type = "double", Name = "priceperunit" },
        { Type = "string", Name = "currency" },
        { Type = "string", Name = "leasecontractlength" },
        { Type = "string", Name = "purchaseoption" },
        { Type = "string", Name = "offeringclass" },
        { Type = "string", Name = "product family" },
        { Type = "string", Name = "servicecode" },
        { Type = "string", Name = "location" },
        { Type = "string", Name = "location type" },
        { Type = "string", Name = "instance type" },
        { Type = "string", Name = "current generation" },
        { Type = "string", Name = "instance family" },
        { Type = "string", Name = "vcpu" },
        { Type = "string", Name = "memory" },
        { Type = "string", Name = "network performance" },
        { Type = "string", Name = "cache engine" },
        { Type = "string", Name = "storage media" },
        { Type = "string", Name = "transfer type" },
        { Type = "string", Name = "usagetype" },
        { Type = "string", Name = "operation" },
        { Type = "string", Name = "region code" },
        { Type = "string", Name = "servicename" },
        { Type = "string", Name = "ssd" }
      ]
    }
    AmazonES = {
      path      = "opensearch"
      partition = [{ Name = "region", Type = "string" }]
      fields = [
        { Type = "string", Name = "sku" },
        { Type = "string", Name = "offertermcode" },
        { Type = "string", Name = "ratecode" },
        { Type = "string", Name = "termtype" },
        { Type = "string", Name = "pricedescription" },
        { Type = "string", Name = "effectivedate" },
        { Type = "string", Name = "startingrange" },
        { Type = "string", Name = "endingrange" },
        { Type = "string", Name = "unit" },
        { Type = "double", Name = "priceperunit" },
        { Type = "string", Name = "currency" },
        { Type = "string", Name = "leasecontractlength" },
        { Type = "string", Name = "purchaseoption" },
        { Type = "string", Name = "offeringclass" },
        { Type = "string", Name = "product family" },
        { Type = "string", Name = "servicecode" },
        { Type = "string", Name = "location" },
        { Type = "string", Name = "location type" },
        { Type = "string", Name = "instance type" },
        { Type = "string", Name = "current generation" },
        { Type = "string", Name = "instance family" },
        { Type = "string", Name = "vcpu" },
        { Type = "string", Name = "storage" },
        { Type = "string", Name = "storage media" },
        { Type = "string", Name = "usagetype" },
        { Type = "string", Name = "operation" },
        { Type = "string", Name = "ecu" },
        { Type = "string", Name = "memory (gib)" },
        { Type = "string", Name = "region code" },
        { Type = "string", Name = "servicename" },
        { Type = "string", Name = "compute type" }
      ]
    }
    AWSComputeSavingsPlan = {
      path      = "computesavingsplan"
      partition = [{ Name = "region", Type = "string" }]
      fields = [
        { Type = "string", Name = "sku" },
        { Type = "string", Name = "ratecode" },
        { Type = "string", Name = "unit" },
        { Type = "string", Name = "effectivedate" },
        { Type = "double", Name = "discountedrate" },
        { Type = "string", Name = "currency" },
        { Type = "string", Name = "discountedsku" },
        { Type = "string", Name = "discountedservicecode" },
        { Type = "string", Name = "discountedusagetype" },
        { Type = "string", Name = "discountedoperation" },
        { Type = "string", Name = "purchaseoption" },
        { Type = "string", Name = "leasecontractlength" },
        { Type = "string", Name = "leasecontractlengthunit" },
        { Type = "string", Name = "servicecode" },
        { Type = "string", Name = "usagetype" },
        { Type = "string", Name = "operation" },
        { Type = "string", Name = "description" },
        { Type = "string", Name = "instance family" },
        { Type = "string", Name = "location" },
        { Type = "string", Name = "location type" },
        { Type = "string", Name = "granularity" },
        { Type = "string", Name = "product family" }
      ]
    }
    RegionNames = {
      path      = "regionnames"
      partition = [{ Name = "partition", Type = "string" }]
      fields = [
        { Type = "string", Name = "region" },
        { Type = "string", Name = "regionname" },
        { Type = "string", Name = "endpoint" },
        { Type = "string", Name = "protocol" }
      ]
    }
    AWSLambda = {
      path      = "lambda"
      partition = [{ Name = "region", Type = "string" }]
      fields = [
        { Type = "string", Name = "sku" },
        { Type = "string", Name = "offerttermcode" },
        { Type = "string", Name = "ratecode" },
        { Type = "string", Name = "termtype" },
        { Type = "string", Name = "pricedescription" },
        { Type = "string", Name = "effectivedate" },
        { Type = "string", Name = "endingrange" },
        { Type = "string", Name = "startingrange" },
        { Type = "string", Name = "unit" },
        { Type = "double", Name = "priceperunit" },
        { Type = "string", Name = "currency" },
        { Type = "string", Name = "relatedto" },
        { Type = "string", Name = "product family" },
        { Type = "string", Name = "servicecode" },
        { Type = "string", Name = "location" },
        { Type = "string", Name = "location type" },
        { Type = "string", Name = "group" },
        { Type = "string", Name = "group description" },
        { Type = "string", Name = "usagetype" },
        { Type = "string", Name = "operation" },
        { Type = "string", Name = "region code" },
        { Type = "string", Name = "servicename" }
      ]
    }
    #   RDSGraviton = {
    #     path      = "rdsgraviton"
    #     partition = [{ Name = "partition", Type = "string" }]
    #     fields = [
    #       { Type = "string", Name = "dbtype" },
    #       { Type = "string", Name = "databaseengine" },
    #       { Type = "string", Name = "instancetype" },
    #       { Type = "string", Name = "graviton_instancetype" }
    #     ]
    #   }
  }
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
