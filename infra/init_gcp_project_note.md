# gcloud 初始化
gcloud auth login


gcloud projects list


gcloud config set project 484284974913
gcloud auth application-default set-quota-project 484284974913

让 Terraform、Python SDK 等程序获得 ADC 凭证
gcloud auth application-default login

批量开启（启用）两个核心云服务 API。GCP 默认关闭大部分 API，必须在创建对应资源前手动启用：
            compute.googleapis.com（Compute Engine API）： 开启虚拟机（VM 实例）、VPC 网络、防火墙规则、磁盘和负载均衡器等基础计算资源的操作权限。
            iap.googleapis.com（Identity-Aware Proxy API）： 开启身份感知代理服务。在 K8s 或虚拟机运维场景中，它最常用于免公网 IP 安全连接内网虚拟机（即通过 gcloud compute ssh --tunnel-through-iap 建立 SSH 隧道，既安全又省去配置跳板机的麻烦）。
gcloud services enable \
  compute.googleapis.com \
  iap.googleapis.com




  # terraform 初始化
  cd infra
  touch main.tf
touch variables.tf
touch outputs.tf
touch terraform.tfvars


terraform init
terraform fmt
terraform validate
terraform plan
terraform apply