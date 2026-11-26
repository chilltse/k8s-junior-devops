# 05｜持久化存储、StatefulSet 与批处理

## 1. 容器里的数据在哪里

容器可写层不保证跨容器重建保留。Pod 的 `emptyDir` 从 Pod 分配到节点开始存在，容器重启后通常保留，Pod 删除后消失。ConfigMap 和 Secret 是配置类 volume，不能作为业务数据库。`hostPath` 将节点路径映射进 Pod，会绑定节点且有安全风险，不应当作通用生产存储。

持久化有三层：PV 是集群中实际存储资源的 API 表示；PVC 是命名空间中的存储申请；StorageClass 描述动态 provision 的驱动和参数（例如云磁盘、文件系统、回收策略）。CSI 是 Kubernetes 与存储驱动的接口。动态供应时，PVC 按 class 请求容量，驱动创建后端卷与 PV，绑定后由 kubelet/CSI 协调挂载到 Pod。`WaitForFirstConsumer` 允许先考虑 Pod 调度的拓扑，再供应卷。

| accessMode | 含义 |
|---|---|
| RWO | ReadWriteOnce，一个节点可读写挂载，可能被同节点多个 Pod 使用 |
| ROX | ReadOnlyMany，多节点只读 |
| RWX | ReadWriteMany，多节点读写 |
| RWOP | ReadWriteOncePod，受支持的 CSI 卷限制为单 Pod 使用 |

具体模式依驱动，不能仅凭字段认为后端一定支持。`reclaimPolicy: Delete` 通常在 PVC/PV 释放后删除后端卷；Retain 需要管理员后续回收。PVC 不等于备份，也不保证数据可跨故障域恢复。

## 2. StatefulSet 实战：Redis 持久化

StatefulSet 给每个副本稳定的 ordinal 名称和按模板生成的 PVC，结合 headless Service 可获得稳定 DNS。它不是数据库复制协议，不会替你做 Redis 主从、选主或备份。本例只运行一个教学 Redis，无认证，不暴露集群外。

```bash
source scripts/common.sh
k get storageclass
k apply -f k8s/optional/storage.yaml
k -n devops-lab rollout status sts/lab-store --timeout=180s
k -n devops-lab get sts,pod,pvc
k get pv
k -n devops-lab exec lab-store-0 -- redis-cli SET lesson durable
k -n devops-lab exec lab-store-0 -- redis-cli GET lesson
k -n devops-lab delete pod lab-store-0
k -n devops-lab rollout status sts/lab-store --timeout=180s
k -n devops-lab exec lab-store-0 -- redis-cli GET lesson
```

如果 Pod 被删除但 PVC 保留，预期 GET 仍返回 durable，Pod 名仍为 lab-store-0（UID 改变）。`volumeClaimTemplates` 为各 ordinal 创建独立 PVC；相同 StatefulSet 的多个副本不会自动共享同一数据库。kind 通常提供 local-path 类型存储；若无默认 StorageClass，PVC 会 Pending，需要安装兼容 provisioner 或指定 class。不要把本地路径卷当跨节点高可用磁盘。

定位存储异常：`k -n devops-lab describe pvc data-lab-store-0`、`k get pv -o wide`、`k -n devops-lab describe pod lab-store-0`。Pending 查 class、provisioner、拓扑和容量；ContainerCreating 查 attach/mount、权限；应用运行但不能写入查 `id`、挂载路径、文件权限与只读设置。不要随意删除 PVC 来解决 mount 错误。

生产数据库通常优先考虑托管服务、经过验证的 Operator、备份与定期恢复演练。备份设计需明确 RPO（允许丢失多少时间的数据）与 RTO（允许恢复多久），并验证应用一致性；快照不自动等于跨区域可恢复备份。

## 3. Job / CronJob 实验

Deployment 维持持续服务；Job 管理任务成功完成次数；CronJob 按 schedule 创建 Job。任务可能重复或漏执行，业务要幂等；`concurrencyPolicy: Forbid` 只约束同一 CronJob 创建的并发 Job。`backoffLimit` 控制失败重试，`activeDeadlineSeconds` 限制 Job 总执行时间。CronJob schedule 默认按控制器时间解释，可用 `.spec.timeZone` 明确时区（受支持版本）。

```bash
k apply -f k8s/optional/jobs.yaml
k -n devops-lab wait --for=condition=complete job/check-api --timeout=120s
k -n devops-lab logs job/check-api
k -n devops-lab get cronjob,job
k -n devops-lab create job manual-check --from=cronjob/check-api-periodic
k -n devops-lab wait --for=condition=complete job/manual-check --timeout=120s
k -n devops-lab logs job/manual-check
k -n devops-lab patch cronjob check-api-periodic -p '{"spec":{"suspend":true}}'
```

预期健康检查成功；暂停 CronJob 不会自动终止已存在的 Job。手工触发时要考虑重复执行的副作用。迁移数据任务应记录任务 ID、重试策略及幂等键；不要把无限循环任务当 Job。

清理：`k delete -f k8s/optional/jobs.yaml --ignore-not-found`、`k -n devops-lab delete job manual-check --ignore-not-found`。存储可保留至综合实验；若确认只含实验数据，先 `k delete -f k8s/optional/storage.yaml`，再单独删除 `k -n devops-lab delete pvc data-lab-store-0`，注意数据可能永久删除。

## 4. 验收

- [ ] 画出 Pod → PVC → PV → 实际存储的关系并解释生命周期。
- [ ] 删除 Redis Pod 后验证数据，解释为何不能据此声称高可用。
- [ ] 能区别 Pending PVC、mount 失败、容器权限问题。
- [ ] 手工执行和暂停 CronJob，说明重试与幂等性。
