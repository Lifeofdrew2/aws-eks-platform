variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Short project name, used as a prefix for resource names."
  type        = string
  default     = "demo-platform"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets and nodes across."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "Use 2 or 3 AZs for a multi-AZ deployment."
  }
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheaper, for demos). false = one NAT gateway per AZ (production-grade, no cross-AZ dependency)."
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "EKS control plane version."
  type        = string
  default     = "1.33"
}

variable "api_allowed_cidrs" {
  description = "CIDR ranges allowed to reach the public EKS API endpoint. Restrict to your own IP (x.x.x.x/32)."
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT. SPOT reduces cost for non-production demos."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "ecr_repositories" {
  description = "Container image repositories to create in ECR."
  type        = set(string)
  default     = ["demo-api"]
}
