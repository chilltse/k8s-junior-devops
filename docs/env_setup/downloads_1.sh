# 更新索引并安装基础依赖
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# 使用官方一键脚本安装 Docker Engine
curl -fsSL https://get.docker.com | sudo sh

# 启动并设置开机自启
sudo systemctl enable --now docker

# 将当前用户加入 docker 组，避免每次执行 docker 或 kind 都要加 sudo
# docker 用户组通常是在安装 Docker 时自动创建的，专门用于管理普通用户访问 Docker 服务的权限。；第一行命令是让当前用户加入docker用户组，通常需要退出登录并重新登录新的组权限才能生效，但是第二行命令执行之后会启动一个新的shell使得用户不用退出重新登录而是直接生效
sudo usermod -aG docker $USER 


# 下面的需要重新执行
