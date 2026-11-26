# 00｜环境、Linux 与容器基础

前置：了解终端、Git、TCP/IP 基础。即使你已经会 Docker，也建议完成这一章，因为 Kubernetes 里的故障最终仍会落到进程、网络、文件系统或资源。

## 1. 本地工具选择

kind（Kubernetes IN Docker）把每个 Kubernetes 节点运行在容器中；macOS 的 Docker Desktop 又在 Linux VM 中运行这些容器，因此不是直接在 macOS 内核运行 Linux Pod。相比直接学习 kubeadm，kind 更容易反复重建，不需要购买云服务器。三节点集群可练习跨节点调度和 drain，但三节点共享同一台机器与同一 VM，不能代表生产高可用。

Apple Silicon Mac 推荐原生 ARM64 镜像；Linux 推荐 Docker Engine。建议 8 GB 以上内存可尝试核心实验，16 GB 机器体验更好；Docker VM 分配约 4–6 GB 内存、3–4 CPU 给核心实验，监控安装视实际资源提高或单独运行。留 15–25 GB 可用磁盘（估计）。

macOS（已有 Homebrew）：

```bash
brew install kind kubectl helm
brew install --cask docker
open -a Docker
# 等 Docker Desktop 启动完成后执行
docker info
kind version
kubectl version --client
helm version
uname -m
```

Linux：安装适合发行版的 Docker Engine，参照 https://docs.docker.com/engine/install/ ；再按 kind、kubectl、Helm 官方安装页选对应架构二进制，见 references.md。不要用不明脚本装生产工具。kubectl 与 API Server 建议保持支持的版本差（通常相差不超过一个 minor）。

如果 Docker 无法联网，先 `docker pull busybox:1.36` 检查镜像拉取；代理配置可能需要分别设置 Docker Desktop 与 shell，不能只在 shell 设置 HTTP_PROXY 就认为容器已联网。不要通过关闭所有 TLS 验证来解决代理问题。

## 2. 容器从哪来

镜像是只读分层的应用文件与运行环境，容器是镜像的运行实例，加上可写层、网络和资源约束。Linux namespaces 隔离 PID、网络、挂载等视图；cgroups 管理 CPU/内存等资源；容器通常共享宿主 Linux 内核，不等价于虚拟机。Docker 是构建和运行容器的工具；Kubernetes 管理容器化工作负载，节点常用 containerd 通过 CRI 接口供 kubelet 调用。Kubernetes 不要求节点安装 Docker Engine。

在工程根目录执行：

```bash
docker build -t lab-api:v1 app
docker run --rm -d --name junior-api -p 127.0.0.1:18080:8080 lab-api:v1
curl -i http://127.0.0.1:18080/
docker logs junior-api
docker inspect junior-api --format '{{.State.Status}}'
docker exec junior-api id
docker stats --no-stream junior-api
docker stop junior-api
```

解释 Dockerfile：FROM 提供 Python 运行环境；COPY 放入应用；WORKDIR 是工作目录；ENV 设置默认参数；USER 限制进程权限；EXPOSE 是端口说明而不是发布端口；CMD 是默认启动命令。`-p` 将宿主端口映射到容器监听端口。绑定 `127.0.0.1` 避免对外暴露实验服务。

应用代码入口 `app/server.py`：`/` 返回版本与 Pod 名，`/healthz` 只反映进程存活，`/readyz` 反映是否可接请求，`/burn?ms=200` 制造有界 CPU 工作，`/error` 产生故障响应，`/metrics` 导出有限标签的计数器。理解接口设计比背 YAML 更重要。此服务没有生产级安全与性能保证，所有测试只在本地。

## 3. 创建集群及 context

```bash
bash scripts/bootstrap.sh
kubectl config get-contexts
kubectl --context kind-junior-devops cluster-info
kubectl --context kind-junior-devops get nodes -o wide
kubectl --context kind-junior-devops get pods -A
```

预期 3 个 Ready 节点，CoreDNS 等系统 Pod Running。刚启动可能需要一段时间。`kubectl` 通过 kubeconfig 找到 API Server URL、CA 与客户端身份；context 是 cluster、user、namespace 的组合。命名空间并不是 context，也不是权限边界的全部。

从本章开始，每个新终端先在项目根目录进入 Bash（macOS 默认 Zsh，故先执行 `bash`），再执行：

```bash
source scripts/common.sh
# k 是带 --context kind-junior-devops 的 shell 函数
k get nodes
```

该文件只在非交互 Bash 中启用 `set -euo pipefail`，使脚本失败时中止。若使用 Zsh 或不希望 source Bash 脚本，可用 `k(){ kubectl --context kind-junior-devops "$@"; }` 单独定义函数。手工写完整 kubectl 命令也可以。Helm 命令另用 `--kube-context`。不要使用没有 context 的破坏性命令。

## 4. Linux 排查基本功

进入一个工作节点只是为了观察（不是日常修改节点的方式）：

```bash
docker exec junior-devops-worker sh -c 'ps aux | head; df -h; free -m'
docker exec junior-devops-worker crictl ps
k describe node junior-devops-worker
```

`ps` 查进程；`free` 看内存；`df` 看文件系统容量；`crictl` 看 CRI 容器（不是宿主 docker ps）。节点容器内看到的内存可能反映 VM/宿主视角，不等于 Pod limit。生产节点若允许登录，进一步用 `journalctl -u kubelet`、`journalctl -k`、`iostat -xz 1`、`ss -lntp` 检查服务日志、内核 OOM、I/O、监听端口。工具未安装时不要为了排障直接修改生产镜像。

## 5. 验收

- [ ] 不看文档完成镜像构建、本地运行、日志查看和停止。
- [ ] 解释镜像、容器、Pod、Node 的四层关系；为什么 Docker 容器在 Mac 上仍需要 Linux。
- [ ] 能定位当前 context、API Server 与节点；能从 kind 节点看到 CRI 容器。
- [ ] 记录 Docker、kind、kubectl、Kubernetes Server 版本与实际资源分配。

常见失败：Docker daemon 未运行；镜像仓库不可达；CPU 架构不兼容；旧 context/证书；VM 内存不足。先查 `docker info`、`kind get clusters`、`docker ps -a`、`kind export logs --name junior-devops ./evidence/kind`，再决定重建。下一章：[架构](01-architecture.md)。
