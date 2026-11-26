terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# 1. 创建独立的 VPC 网络
resource "google_compute_network" "lab" {
  name                    = "devops-vpc"
  auto_create_subnetworks = false
}

# 2. 创建子网
resource "google_compute_subnetwork" "lab" {
  name          = "devops-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.lab.id
}

# 3. 防火墙：仅允许通过 Google IAP 连接 SSH。 source_ranges = ["35.235.240.0/20"]：这是 Google Cloud Identity-Aware Proxy (IAP) TCP 转发服务的官方固定 IP 段。
resource "google_compute_firewall" "ssh" {
  name    = "devops-allow-iap-ssh"
  network = google_compute_network.lab.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["devops-lab"]
}

# 4. 创建虚拟机
resource "google_compute_instance" "lab" {
  name         = "k8s-lab"
  machine_type = var.machine_type
  zone         = var.zone

  # 允许 Terraform 停机调整硬件配置
  allow_stopping_for_update = true

  tags = ["devops-lab"]

  # 系统盘，auto_delete = true 确保销毁虚拟机时同步清理磁盘
  boot_disk {
    auto_delete = true

    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = var.disk_size
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.lab.id

    # 临时公网 IP，用于访问互联网；虽然入站 22 端口被防火墙锁死了，但这个公网 IP 能让虚拟机直接访问外网
    access_config {}
  }

  metadata = {
    block-project-ssh-keys = "true"
  }

  labels = {
    environment = "development"
    purpose     = "kubernetes-learning"
    managed-by  = "terraform"
  }
}