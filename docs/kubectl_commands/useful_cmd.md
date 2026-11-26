下面是 Kubernetes 日常开发、DevOps、SRE 最常用的 `kubectl` 命令，按照实际使用场景分类。Kind、Minikube、GKE 都适用。

## **1. 集群管理（Cluster）**

| 命令                                | 作用              |
| --------------------------------- | --------------- |
| `kubectl cluster-info`            | 查看集群信息          |
| `kubectl get nodes`               | 查看所有节点          |
| `kubectl get nodes -o wide`       | 查看节点 IP、系统等详细信息 |
| `kubectl describe node NODE`      | 查看节点详细状态        |
| `kubectl top nodes`               | 查看节点 CPU、内存使用率  |
| `kubectl version`                 | 查看客户端和服务端版本     |
| `kubectl config get-contexts`     | 查看已配置的集群        |
| `kubectl config current-context`  | 查看当前连接的集群       |
| `kubectl config use-context NAME` | 切换集群            |

## **2. 查询资源（Get）**

```
kubectl get pods
kubectl get deployments
kubectl get replicasets
kubectl get services
kubectl get namespaces
kubectl get configmaps
kubectl get secrets
kubectl get ingress
kubectl get pv
kubectl get pvc
kubectl get all
```

常用缩写：

| 完整名称                   | 缩写     |
| ---------------------- | ------ |
| pods                   | po     |
| deployments            | deploy |
| replicasets            | rs     |
| services               | svc    |
| namespaces             | ns     |
| configmaps             | cm     |
| nodes                  | no     |
| persistentvolumeclaims | pvc    |

常用查询参数：

```
# 查看所有 Namespace 下的 Pod
kubectl get pods -A

# 查看指定 Namespace
kubectl get pods -n kube-system

# 查看更多信息，包括所在 Node
kubectl get pods -o wide

# 持续观察资源变化
kubectl get pods -w

# 输出完整 YAML
kubectl get pod nginx -o yaml

# 输出 JSON
kubectl get pod nginx -o json

# 按标签筛选
kubectl get pods -l app=nginx

# 查看支持的所有资源类型
kubectl api-resources
```

注意：`kubectl get all` 并不是真的查询全部资源类型。

## **3. 创建、更新、删除资源**

```
# 声明式创建或更新
kubectl apply -f deployment.yaml

# 应用目录下的配置文件
kubectl apply -f ./manifests/

# 查看即将发生的配置变化
kubectl diff -f deployment.yaml

# 创建资源
kubectl create -f deployment.yaml

# 删除资源
kubectl delete -f deployment.yaml

# 删除指定 Pod
kubectl delete pod POD_NAME

# 删除 Deployment
kubectl delete deployment nginx

# 在线编辑资源配置
kubectl edit deployment nginx
```

最常用的是 `apply`，类似于 Terraform 的 `terraform apply`。

## **4. Deployment 管理**

```
# 创建一个包含三个副本的 Deployment
kubectl create deployment nginx \
  --image=nginx:alpine \
  --replicas=3

# 扩容
kubectl scale deployment nginx --replicas=5

# 缩容
kubectl scale deployment nginx --replicas=1

# 更新镜像
kubectl set image deployment/nginx nginx=nginx:1.28

# 查看滚动更新状态
kubectl rollout status deployment/nginx

# 查看历史版本
kubectl rollout history deployment/nginx

# 回滚到上一版本
kubectl rollout undo deployment/nginx

# 回滚到指定版本
kubectl rollout undo deployment/nginx --to-revision=2

# 滚动重启
kubectl rollout restart deployment/nginx
```

Rolling Update：逐步替换旧版本 Pod，减少服务中断。

## **5. Pod 调试（非常重要）**

这是 SRE 日常排查问题最常用的一组命令。

```
# 查看 Pod 的详细信息
kubectl describe pod POD_NAME

# 查看日志
kubectl logs POD_NAME

# 实时追踪日志，类似 tail -f
kubectl logs -f POD_NAME

# 查看上一次崩溃的容器日志
kubectl logs POD_NAME --previous

# 查看最近 100 行日志
kubectl logs POD_NAME --tail=100

# 查看最近一小时的日志
kubectl logs POD_NAME --since=1h

# 查看指定容器的日志
kubectl logs POD_NAME -c CONTAINER_NAME

# 进入容器
kubectl exec -it POD_NAME -- /bin/bash

# 如果容器没有 bash
kubectl exec -it POD_NAME -- /bin/sh

# 在容器内执行单条命令
kubectl exec POD_NAME -- ls /app

# 查看集群事件
kubectl get events -A

# 按创建时间排序事件
kubectl get events -A --sort-by=.metadata.creationTimestamp
```

### **常见故障排查流程**

## **6. Service 和网络管理**

```
# 查看 Service
kubectl get svc

# 查看 Service 详情
kubectl describe svc nginx

# 创建 ClusterIP Service
kubectl expose deployment nginx \
  --port=80 --type=ClusterIP

# 创建 NodePort Service（使用不同名称）
kubectl expose deployment nginx \
  --name=nginx-nodeport \
  --port=80 --type=NodePort

# 查看 Service 对应的后端
kubectl get endpointslices

# 查看 Ingress
kubectl get ingress

# 端口转发
kubectl port-forward svc/nginx 8080:80

# 直接转发到 Pod
kubectl port-forward pod/POD_NAME 8080:80
```

创建临时容器进行网络测试：

```
kubectl run network-test \
  --image=busybox \
  --rm -it \
  --restart=Never -- sh
```

进入后：

```
nslookup nginx
wget -O- http://nginx
```

## **7. Namespace 管理**

```
# 查看 Namespace
kubectl get ns

# 创建 Namespace
kubectl create namespace dev

# 在指定 Namespace 部署应用
kubectl apply -f deployment.yaml -n dev

# 设置当前 Context 的默认 Namespace
kubectl config set-context --current --namespace=dev

# 删除 Namespace 及其中的资源
kubectl delete namespace dev
```

## **8. Node 运维管理**

```
# 禁止新的 Pod 调度到指定节点
kubectl cordon NODE_NAME

# 驱逐节点上的普通工作负载
kubectl drain NODE_NAME --ignore-daemonsets

# 恢复节点调度
kubectl uncordon NODE_NAME

# 添加节点标签
kubectl label node NODE_NAME workload=backend

# 删除节点标签
kubectl label node NODE_NAME workload-

# 添加污点，限制 Pod 调度
kubectl taint nodes NODE_NAME dedicated=backend:NoSchedule

# 移除污点
kubectl taint nodes NODE_NAME dedicated:NoSchedule-
```

| 操作         | 已有 Pod      | 新 Pod |
| ---------- | ----------- | ----- |
| `cordon`   | 保留          | 禁止调度  |
| `drain`    | 驱逐符合条件的 Pod | 禁止调度  |
| `uncordon` | 不受影响        | 允许调度  |

`drain` 常用于节点维护、系统升级、服务器下线。它可能受到 PodDisruptionBudget、本地数据等限制。

## **9. 资源监控**

需要提前安装 Metrics Server。

```
# 查看节点资源使用情况
kubectl top nodes

# 查看 Pod 资源使用情况
kubectl top pods

# 查看所有 Namespace
kubectl top pods -A

# 按 CPU 使用量排序
kubectl top pods -A --sort-by=cpu

# 按内存使用量排序
kubectl top pods -A --sort-by=memory

# 查看 Pod 内各容器的资源使用情况
kubectl top pods --containers
```

## **10. 权限管理（RBAC）**

```
kubectl get serviceaccounts

kubectl get roles -A

kubectl get rolebindings -A

kubectl get clusterroles

kubectl get clusterrolebindings

# 检查当前用户是否有删除 Pod 的权限
kubectl auth can-i delete pods

# 查看当前用户的所有权限
kubectl auth can-i --list

# 检查指定 ServiceAccount 的权限
kubectl auth can-i get pods \
  --as=system:serviceaccount:default:agent
```

这部分对你的 Agentic DevOps 工程尤其重要，因为不能直接给 Agent 无限的集群管理权限。

## **11. 学会使用 kubectl 自带文档**

不需要死记硬背所有 YAML 字段。

```
kubectl --help

kubectl get --help

kubectl explain deployment

kubectl explain deployment.spec

kubectl explain deployment.spec.template.spec

kubectl explain pod --recursive
```

还可以自动生成 YAML 模板，而不真正创建资源：

```
kubectl create deployment nginx \
  --image=nginx:alpine \
  --replicas=3 \
  --dry-run=client \
  -o yaml > deployment.yaml
```

## **12. 设置命令行快捷方式**

在 GCP 的 Bash 终端执行：

```
echo 'alias k=kubectl' >> ~/.bashrc

echo 'source <(kubectl completion bash)' >> ~/.bashrc

echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc

source ~/.bashrc
```

之后就可以使用：

```
k get po -A
k get no
k get svc
k describe po POD_NAME
k logs -f POD_NAME
k exec -it POD_NAME -- sh
```

## **13. 建议你现在完成的实操练习**

### **Kubectl 基础实战**

0/12 完成

创建 Deployment

kubectl create deployment nginx --image=nginx:alpine --replicas=3

观察 Pod 调度

kubectl get pods -o wide

扩容到 5 个副本

kubectl scale deployment nginx --replicas=5

创建 Service

kubectl expose deployment nginx --port=80

访问应用

kubectl port-forward svc/nginx 8080:80

查看应用日志

kubectl logs deployment/nginx

删除一个 Pod，观察自愈

kubectl delete pod POD_NAME

制造镜像拉取故障

kubectl set image deployment/nginx nginx=nginx:nonexistent-tag

排查故障

kubectl describe pod POD_NAME

执行版本回滚

kubectl rollout undo deployment/nginx

模拟节点维护

kubectl cordon NODE_NAME

恢复节点

kubectl uncordon NODE_NAME

**对于初级 DevOps/SRE 面试，优先熟练掌握这 12 个子命令：**

```
get          查询资源
describe     查看详细状态
apply        创建或更新
delete       删除资源
logs         查看日志
exec         进入容器
scale        扩缩容
rollout      发布与回滚
top          资源监控
port-forward 端口转发
cordon       禁止节点调度
drain        节点维护
```

尤其是 `get → describe → logs → events → exec` 这一套故障排查流程，需要练习到不用查文档就能操作。