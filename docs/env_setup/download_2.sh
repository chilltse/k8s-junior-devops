

# 自动识别系统架构并下载最新稳定版kubectl
ARCH=$(dpkg --print-architecture)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# 安装kind
ARCH=$(dpkg --print-architecture)
# 获取最新版本号并下载二进制文件
KIND_VER=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VER}/kind-linux-${ARCH}"
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
rm kind

# 安装helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

#  验证安装
docker info
kind version
kubectl version --client
helm version
uname -m