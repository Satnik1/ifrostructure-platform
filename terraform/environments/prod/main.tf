terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token = var.token
  cloud_id = var.cloud_id
  folder_id = var.folder_id
  zone = "ru-central1-a"
}

module "network" {
  source = "../../modules/network"
  environment = "prod"
  cidr = "192.168.20.0/24"
}

module "app_vm" {
  source = "../../modules/vm"
  environment = "prod"
  vm_name = "machine"
  vm_count = 1
  vm_role = "app"
  subnet_id = module.network.subnet_id
}

module "monitoring_vm" {
  source = "../../modules/vm"
  environment = "prod"
  vm_name = "machine"
  vm_role = "monitoring"
  vm_count = 1
  subnet_id = module.network.subnet_id
}

module "app_balancer" {
  source = "../../modules/balancer"
  environment = "prod"
  subnet_id = module.network.subnet_id   
  target_ips = module.app_vm.instance_ips
}

module "dns" {
  source = "../../modules/dns"
  environment = "prod"
  lb_external_ip = module.app_balancer.external_ip
}
