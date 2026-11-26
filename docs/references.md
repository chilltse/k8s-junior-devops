# 官方资料与适用边界

本教程以稳定 Kubernetes API 为基础，安装部分参考官方资料。不是官方认证课程，也不声称已跑通全部外部组件。工具版本、chart 选项、CNI 行为会随版本变化；记录 `kind version`、`kubectl version`、`helm version` 和 chart version，按兼容矩阵选择，不盲目追 latest。

- kind 快速开始：https://kind.sigs.k8s.io/docs/user/quick-start/
- kind Ingress 与本地 LB：https://kind.sigs.k8s.io/docs/user/ingress/
- 安装 kubectl：https://kubernetes.io/docs/tasks/tools/
- Helm 安装：https://helm.sh/docs/intro/install/
- Kubernetes 集群架构：https://kubernetes.io/docs/concepts/architecture/
- Deployment：https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- Service：https://kubernetes.io/docs/concepts/services-networking/service/
- 网络模型：https://kubernetes.io/docs/concepts/services-networking/
- 探针：https://kubernetes.io/docs/concepts/workloads/pods/probes/
- HPA：https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- 资源管理：https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- 存储：https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- RBAC：https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- NetworkPolicy：https://kubernetes.io/docs/concepts/services-networking/network-policies/
- 应用排障：https://kubernetes.io/docs/tasks/debug/debug-application/
- 集群排障：https://kubernetes.io/docs/tasks/debug/debug-cluster/
- Metrics Server：https://github.com/kubernetes-sigs/metrics-server
- Metrics Server 发布：https://github.com/kubernetes-sigs/metrics-server/releases
- Traefik 安装：https://doc.traefik.io/traefik/setup/kubernetes/
- Prometheus Community Charts：https://prometheus-community.github.io/helm-charts/
- Prometheus 查询：https://prometheus.io/docs/prometheus/latest/querying/basics/
- GitHub Actions kind：https://github.com/helm/kind-action
- GitOps / Argo CD：https://argo-cd.readthedocs.io/en/stable/

教学限制：kind 节点共用宿主机资源，不能模拟真实故障域；未包含商业云真实流量入口、真实密钥、生产数据库、HA control plane、集群升级与灾备实操。故障注入只针对本地专用集群。所有预期输出需由学习者实测记录。
