variable "project_name" {} # export TF_VAR_project_name=project001
variable "environment" {}
variable "rds_password" {}
variable "route53_domain" {}
variable "region" {}

# Default...

variable "key_pair_name" {} # set by create.bash
variable "ssh_public_key" {} # set by create.bash
variable "secret_key_base" {} # set by create.bash

variable "redis" {
  default = false
}

variable "root_volume_encrypted" {
  default = false
}

variable "aws_elasticache_parameter_group_redis_family" {
  default = "redis4.0"
}

variable "aws_elasticache_parameter_group_redis_parameter" {
  default = []
}

variable "elasticache_cluster_redis_engine" {
  default = "redis"
}

variable "elasticache_cluster_redis_engine_version" {
  default = "4.0.10"
}

variable "elasticache_cluster_redis_node_type" {
  default = "cache.t2.micro"
}

variable "elasticache_cluster_redis_num_cache_nodes" {
  default = 1
}

variable "elasticache_cluster_redis_security_group_ids" {
  default = ""
}

variable "docker_image" {
  default = "latest"
}

variable "retention_in_days" {
  default = 30
}

variable "container_memory_limit" {
  default = 256
}

variable "application_port" {
  default = 3000
}

variable "date" {} # set by create.bash

variable "vpc_cidr_block" {
  default = "10.1.0.0/16"
}

variable "public_subnets" {
  default = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
}

variable "private_subnets" {
  default = ["10.1.100.0/24", "10.1.101.0/24", "10.1.102.0/24"]
}

variable "family" {
  default = "postgres10"
}

variable "parameters" {
  default = []
}

variable "allocated_storage" {
  default = 10
}

variable "storage_type" {
  default = "gp2"
}

variable "engine" {
  default = "postgres"
}

variable "engine_version" {
  default = "10.6"
}

variable "instance_class" {
  default = "db.t2.micro"
}

variable "backup_retention_days" {
  default = 30
}

variable "copy_tags_to_snapshot" {
  default = true
}

variable "ec2_instance_type" {
  default = "t2.micro"
}

variable "bastion_instance_type" {
  default = "t2.micro"
}

variable "enable_monitoring" {
  default = true
}

variable "volume_type" {
  default = "gp2"
}

variable "volume_size" {
  default = 8
}

variable "min_size" {
  default = 1
}

variable "max_size" {
  default = 1
}

variable "desired_capacity" {
  default = 1
}

variable "health_check_grace_period" {
  default = 300
}

variable "desired_count" {
  default = 1
}

variable "health_check_grace_period_seconds" {
  default = 50
}

variable "deployment_minimum_healthy_percent" {
  default = 50
}

variable "target_group_path" {
  default = "/okcomputer/all.json"
}

variable "target_group_status" {
  default = "200"
}

variable "target_group_timeout" {
  default = 3
}

variable "target_group_interval" {
  default = 5
}

variable "target_group_healthy" {
  default = 5
}

variable "target_group_unhealthy" {
  default = 5
}
