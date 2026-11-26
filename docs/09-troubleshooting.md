# 09｜故障排查与节点维护：SRE 核心技能

## 1. 标准排查顺序（先证据、再动作）

收到“服务不通”不要先 delete pod。明确时间、namespace、受影响用户、错误比例、最近发布。先从用户请求和 Service 路径确认影响，再沿 Deployment/Pod/Node 查原因。生产上先控制影响（回滚/限流/切流等需授权），再做长期根因修复。保存时间戳与变更记录。区分观察、假设、结论。

```bash
source scripts/common.sh
k get nodes -o wide
k -n devops-lab get deploy,rs,pods,svc,endpointslice -o wide
k -n devops-lab get events --sort-by=.metadata.creationTimestamp
k -n devops-lab describe deploy lab-api
k -n devops-lab logs -l app=lab-api --prefix=true --tail=100
bash scripts/collect.sh
```

Pod phase（Pending/Running/Succeeded/Failed/Unknown）与 `kubectl get pods` 的 STATUS 展示不同；CrashLoopBackOff 是退避状态提示，不是 Pod phase，也不是根因。`Running` 不代表 Ready。`describe` 汇总事件与容器状态；日志帮助确认应用问题；events 有保留时间且可能合并。不要把无日志当成应用没错误。

## 2. 故障实战矩阵（逐个做，不要同时注入）

### A. CrashLoopBackOff

```bash
k apply -f k8s/faults/crash.yaml
k -n devops-lab get pod fault-crash -w
# 观察重启后 Ctrl-C
k -n devops-lab describe pod fault-crash
k -n devops-lab logs fault-crash --previous
k -n devops-lab delete pod fault-crash
```

根因：启动命令主动退出 1，日志显示缺少配置。重启次数随时间增加。真实修复：检查 entrypoint、env、挂载、依赖和进程退出码；修复配置或回滚镜像，而不是把重启次数清零。`--previous` 仅当存在上一实例时有结果。

### B. ImagePull / ErrImageNeverPull

```bash
k apply -f k8s/faults/image.yaml
k -n devops-lab describe pod fault-image
k -n devops-lab delete pod fault-image
# 第二种：允许拉取一个故意不存在的公共镜像 tag
k -n devops-lab run pull-failure --image=busybox:devops-lab-nonexistent-tag-987654 --restart=Never
k -n devops-lab describe pod pull-failure
k -n devops-lab delete pod pull-failure
```

前者 `Never` 且节点无镜像，预期 ErrImageNeverPull；后者常先 ErrImagePull 再 ImagePullBackOff（也取决于仓库网络/权限）。查镜像 tag/digest、Registry DNS/TLS、imagePullSecrets、架构以及节点镜像缓存。`docker images` 是宿主机镜像列表，不是 kind 节点 containerd 列表。可以 `docker exec junior-devops-worker crictl images` 查节点。

### C. OOMKilled

```bash
k apply -f k8s/faults/oom.yaml
k -n devops-lab get pod fault-oom -w
# Ctrl-C
k -n devops-lab describe pod fault-oom
k -n devops-lab get pod fault-oom -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}'; echo
k -n devops-lab delete pod fault-oom
```

预期 OOMKilled 或内存限制相关终止，示例分配 128Mi 远超 32Mi 限制。Exit 137 通常提示 SIGKILL，不足以单独证明 OOM；结合 terminated.reason、节点压力和内核日志。修复可能是优化内存、降低并发或调整限制；盲目增大 limit 会把问题转移到节点。

### D. Pending / FailedScheduling

```bash
k apply -f k8s/faults/pending.yaml
k -n devops-lab describe pod fault-pending
k describe node junior-devops-worker
k -n devops-lab delete pod fault-pending
```

核对请求与 allocatable、taints、node affinity、PVC。Pending 也可能是已调度但容器仍在准备；先看 PodScheduled condition 与 events，避免误判。

### E. Service selector / targetPort

按第 03 章两种故障操作，不看答案：先 DNS、再 EndpointSlice、再直连 Pod。证明失败发生在 Service 选择或端口层，修复后从 Pod 内访问 Service。不要用单次 port-forward 成功作为端到端恢复证明。

### F. Readiness 失败

按第 04 章配置 APP_READY=false 并触发发布，观察新 Pod 0/1 Ready、旧版仍处理请求；检查探针事件与 EndpointSlice ready 条件。恢复 ConfigMap 并重启，验证发布完成。区别应用不可用和发布未完成。

### G. 错误版本发布与回滚

先确认基础版正常，设置不存在的镜像（此处只针对教学 Deployment）：

```bash
k -n devops-lab set image deploy/lab-api api=lab-api:invalid-release
k -n devops-lab rollout status deploy/lab-api --timeout=40s || true
k -n devops-lab get pods
k -n devops-lab describe deploy lab-api
k -n devops-lab rollout history deploy/lab-api
k -n devops-lab rollout undo deploy/lab-api
k -n devops-lab rollout status deploy/lab-api --timeout=180s
bash scripts/smoke.sh
```

旧副本可能仍 Ready，故发布失败不等于全站中断。检查线上成功率和版本，而非仅看新副本状态。回滚后同步修复 Git 中的错误，否则下一次 GitOps 会重新部署坏版本。

## 3. 节点维护：cordon、drain、uncordon、PDB

cordon 将 Node 标为不可调度（现有 Pod 不因此被驱逐）；drain 通过 eviction 等机制迁移可驱逐 Pod，为维护做准备；uncordon 恢复调度。PDB 约束自愿 disruption，不保证节点宕机或直接删除 Pod 时可用；Deployment 自身滚动更新主要受 rollout strategy 控制。DaemonSet Pod 通常不通过普通 drain 删除。emptyDir 数据可能丢失，生产不能盲目使用 `--delete-emptydir-data` 或 `--force`。

在执行前确保只有无状态教学工作负载需要迁移；若前面 Redis 仍运行，请先按第 05 章停止 StatefulSet（本地卷可能限制调度），停止监控等可选组件或使用新集群。以下命令只在自己的 kind 集群：

```bash
k apply -f k8s/optional/pdb.yaml
k -n devops-lab get pods -o wide
k -n devops-lab get pdb
k cordon junior-devops-worker
k get nodes
k drain junior-devops-worker --ignore-daemonsets --timeout=120s
# 若因 emptyDir、PDB、裸 Pod 等阻塞，先检查实际提示，不强制删除
k -n devops-lab get pods -o wide
k uncordon junior-devops-worker
k -n devops-lab rollout status deploy/lab-api --timeout=180s
bash scripts/smoke.sh
k delete -f k8s/optional/pdb.yaml
```

若 drain 遇到只包含教学数据的 emptyDir，确认损失可接受后才重试加 `--delete-emptydir-data`；若是裸 Pod，先删除对应测试 Pod，不用 `--force` 跳过安全检查。即使 drain 失败，也需要 uncordon 恢复节点。两个副本可能在同一节点；生产使用 topologySpreadConstraints/podAntiAffinity 分散故障域，配合 PDB 和足够冗余容量，不能只看 replicas 数字。

## 4. 节点异常进阶

Node NotReady、DiskPressure、MemoryPressure 时先看 `describe node` 中 Conditions、taints、allocatable、events；对比其他节点和受影响 Pod。kind 可用 `docker logs junior-devops-worker`、`docker exec junior-devops-worker journalctl -u kubelet --no-pager -n 100`（具体节点工具取决镜像）检查 kubelet；生产托管节点的权限与操作方式不同，遵守运维流程。`kubectl debug node/...` 可能授予较大宿主访问能力，不要随意在生产使用；精简容器没有 shell 时可考虑授权后的 ephemeral debug container。

## 5. 事故报告

用 `templates/incident.md` 每次写：症状、影响、时间线、证据、根因、缓解、验证、预防。不要把“重启解决”写作根因。将事件采集保存在 evidence/，脱敏后只提交必要材料。排障动作与业务修复都要验证副作用，例如恢复后是否还有高延迟、数据一致性问题。

## 6. 验收

- [ ] 7 类故障各独立完成，不看答案复做至少 5 类，每类 10–15 分钟内定位到证据。
- [ ] 不使用无 context 的删除、无授权生产变更或盲目强制 drain。
- [ ] 实际执行 cordon/drain/uncordon，证明节点恢复与服务可用。
- [ ] 至少写 3 份完整 incident report，并能口述根因与预防措施。
