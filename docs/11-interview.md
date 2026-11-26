# 11｜面试与速查手册

练习方式：每题先用 60–90 秒回答，再执行一条能证明回答的命令。不要仅背关键词。以下为课程自测，并非特定公司真实面试题。

## 1. 常见面试题与答题要点

| 问题 | 应答关键点 |
|---|---|
| K8s 和 Docker 区别？ | 镜像/容器运行与分布式期望状态编排；CRI/containerd |
| apply 后发生什么？ | API Server→etcd→controller→scheduler→kubelet→runtime→readiness |
| Pod 删除后为何重建？ | controller 根据期望副本调谐；裸 Pod 不一定重建 |
| Deployment 和 StatefulSet？ | 无状态副本与稳定身份/PVC；不等于自动数据库 HA |
| DaemonSet 用在哪？ | 按符合条件的节点运行，日志采集、节点指标等 |
| Service 怎么发现 Pod？ | label selector→EndpointSlice→数据面；DNS 名指向 Service |
| DNS 正常但请求失败？ | 查看 ready endpoint、targetPort、Pod 监听、策略、应用日志 |
| NodePort、LoadBalancer、Ingress？ | 节点端口、外部 LB 实现、L7 路由声明与 controller |
| CNI、CSI、CRI？ | 网络、存储、容器运行时的接口/实现 |
| requests 和 limits？ | 调度请求、CPU 节流、内存 OOM，非实际用量等价 |
| 为什么 Pending？ | 先 PodScheduled；资源、taint、affinity、PVC、镜像准备 |
| CrashLoopBackOff 如何处理？ | describe、previous logs、exit code、最近变更，不等于根因 |
| Running 但不 Ready？ | readiness、依赖与流量资格，不等于重启 |
| liveness 检查数据库好吗？ | 易引发级联重启；区分进程存活和依赖可用 |
| CPU 60% HPA 的分母？ | CPU request；缺指标/request 影响控制 |
| 滚动更新为何失败？ | 新 Pod readiness、资源、镜像、progress deadline；旧版可能服务 |
| rollback 能恢复 DB 吗？ | 不能保证；仅回退模板/应用，外部状态需方案 |
| ConfigMap 更新为何没生效？ | env 固定于启动；volume 最终更新，应用仍需重读 |
| Secret 是加密的吗？ | base64 非加密；etcd 加密、RBAC、轮换、外部凭证管理 |
| PVC 删除危险？ | reclaim policy 与后端存储生命周期；先备份验证 |
| Role 和 ClusterRole？ | 权限范围与 binding 授权范围；SA 是身份 |
| NetworkPolicy 无效？ | 先确认 CNI 支持，再看 selector、方向与测试路径 |
| PDB 能防节点宕机？ | 主要约束自愿驱逐，不能保证非自愿中断 |
| GitOps 和 CI/CD？ | Git 期望状态与持续调谐；CI 构建验证，CD 交付 |
| Prometheus 与 metrics-server？ | 时序监控告警与资源指标 API 用途不同 |
| P95 和平均延迟？ | 尾部与均值不同；需 histogram/分布数据估计分位数 |
| 如何设计告警？ | 用户影响、SLI/SLO、可操作性、窗口与噪声控制 |
| 如何排查 503？ | 区分入口/应用返回；请求→路由→endpoint→Pod→依赖 |
| 如何安全维护节点？ | 容量、PDB、数据检查、cordon/drain/uncordon、验证 |
| 多副本等于高可用？ | 不一定；节点/区域/依赖单点、拓扑和容量、实际故障测试 |

## 2. kubectl 速查（先定义安全 context）

```bash
k(){ kubectl --context kind-junior-devops "$@"; }
# 集群视图
k config current-context
k get nodes -o wide
k get pods -A
k api-resources
k explain deployment.spec.strategy
# 应用视图
k -n devops-lab get deploy,rs,pods,svc,endpointslice -o wide
k -n devops-lab get pods -l app=lab-api --show-labels
k -n devops-lab describe deploy lab-api
k -n devops-lab get events --sort-by=.metadata.creationTimestamp
k -n devops-lab logs -l app=lab-api --prefix=true --tail=100
k -n devops-lab exec deploy/lab-api -- id
k -n devops-lab top pods
# 发布
k apply --dry-run=server -k k8s/base
k diff -k k8s/base
k apply -k k8s/base
k -n devops-lab rollout status deploy/lab-api --timeout=120s
k -n devops-lab rollout history deploy/lab-api
k -n devops-lab rollout undo deploy/lab-api
# 网络
k -n devops-lab get endpointslice -l kubernetes.io/service-name=lab-api -o yaml
k -n devops-lab port-forward svc/lab-api 8080:80
# 权限
k auth can-i get pods -n devops-lab
# 采证
bash scripts/collect.sh
```

`config current-context` 反映 kubeconfig 当前默认 context，不代表上面函数会使用它（函数显式传 context）；每次执行前仍需确认目标。`-o jsonpath` 适合提取字段；`-o yaml/json` 看完整对象；`-w` 观察变化，Ctrl-C 退出；`--timeout` 限制等待但不一定取消控制器正在做的操作。

## 3. 英语/日语面试核心表达

英文：I check the rollout status, pod events, and previous container logs before restarting anything. I verify service endpoints and test from inside the cluster. I roll back the application only after assessing impact and the database compatibility.

日语：まずデプロイの状態、Pod のイベント、直前のコンテナログを確認し、原因を切り分けます。次に Service の EndpointSlice とクラスタ内からの疎通を確認します。影響範囲とデータベースの互換性を確認した上で、必要に応じてロールバックします。

表达能力基于实际做过的实验，不背诵成不存在的生产经历。遇到没做过的技术，明确说理解概念、尚未实际操作，再描述如何安全验证。

## 4. 进阶学习顺序

核心能力达标后：Linux/systemd/cgroups 与网络 → 云托管 K8s（GKE/EKS）与 IAM、VPC、LB → Terraform IaC → GitOps → 分布式系统与 SLO → CKA 相关技能（可选）。不要把证书或熟悉命令当作真实运维经验的替代。
