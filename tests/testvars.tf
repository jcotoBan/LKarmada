output "VMCount" {
  value = var.region-manager-lke-cluster[0].region
}

variable "region-manager-lke-cluster"{}
