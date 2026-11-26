# 04｜资源管理、探针、自动扩缩容

## 1. Requests、Limits 与调度

CPU request 100m = 0.1 个 CPU 核；memory 48Mi = 48 × 2^20 bytes。request 主要影响调度和资源竞争（CPU 权重等），不是简单的硬上限；limit 是运行时资源约束。CPU 超限通常被节流（throttling），内存触及 cgroup 限制可能触发 OOM kill。节点也可能因 MemoryPressure 等主动驱逐 Pod，这和容器自身超限不同。调度基于请求量和 Node allocatable，不只看 `top` 实际使用量。

QoS：Guaranteed 通常要求每个容器 CPU/内存 request 与 limit 均设置且相等；BestEffort 无 CPU/内存 request/limit；其他通常 Burstable。QoS 影响节点压力下的驱逐行为，但不代表一定不会被驱逐。PriorityClass、实际使用超出 request 等也有关。

```bash
source scripts/common.sh
k -n devops-lab get deploy lab-api -o jsonpath='{.spec.template.spec.containers[0].resources}'; echo
k describe node junior-devops-worker
k apply -f k8s/faults/pending.yaml
k -n devops-lab describe pod fault-pending
k -n devops-lab delete pod fault-pending
```

预期 Pending，事件包含 FailedScheduling 与 CPU 不足（教学请求 1000 核）。真实问题还可能是 PVC 未绑定、node selector 不匹配、taints 不容忍。

## 2. 三类探针

| 探针 | 目的 | 失败后 |
|---|---|---|
| startup | 应用是否完成初始化 | 达阈值后重启容器（按 restart policy）；成功前不执行其他两类探针 |
| readiness | 是否可以接业务请求 | 标记不就绪，常规 Service 不再路由至该端点 |
| liveness | 是否需要重启进程 | 达阈值后由 kubelet 终止并按策略重启 |

三者都可用 HTTP、TCP、exec 等支持的方式。不要把外部数据库的短暂故障直接作为 liveness 失败，否则所有副本可能同时重启；readiness 也应考虑依赖失败后的降级策略，防止故障扩散。`failureThreshold × periodSeconds` 只提供粗略时间估计，实际还有初始延迟、探针耗时等。

实验：配置让新 Pod readiness 失败但 liveness 正常。

```bash
k -n devops-lab patch configmap lab-api-config -p '{"data":{"APP_READY":"false"}}'
k -n devops-lab rollout restart deploy/lab-api
k -n devops-lab get pods -w
# Ctrl-C 后，观察一个新 Pod 的 Events（旧 Pod 可能仍 Ready）
k -n devops-lab describe deploy lab-api
k -n devops-lab get endpointslice -l kubernetes.io/service-name=lab-api -o yaml
k -n devops-lab rollout status deploy/lab-api --timeout=30s || true
```

预期新的副本 0/1 Ready，restart count 不必增加；maxUnavailable=0 保护旧版，但发布卡住。修复配置后已有 env 不会变：

```bash
k apply -k k8s/base
k -n devops-lab rollout restart deploy/lab-api
k -n devops-lab rollout status deploy/lab-api --timeout=180s
bash scripts/smoke.sh
```

## 3. 安装 metrics-server（HPA 实验依赖）

Metrics Server 聚合 kubelet 的资源指标，提供 metrics.k8s.io API，供 `kubectl top` 与资源型 HPA 使用；不是 Prometheus 的长期时序存储替代。先按 release README 检查与集群版本兼容。这里使用已公开发布的 v0.8.1；若集群不兼容，选择官方匹配版本。

```bash
k apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.1/components.yaml
k -n kube-system rollout status deployment/metrics-server --timeout=120s || true
k -n kube-system logs deploy/metrics-server --tail=30
```

如果在本地 kind 中明确看到 kubelet serving certificate 的 x509 校验错误，可在**仅本地教学集群**临时加入 `--kubelet-insecure-tls`（生产不能用此方式掩盖证书问题）：

```bash
k -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
k -n kube-system rollout status deploy/metrics-server --timeout=180s
k get apiservice v1beta1.metrics.k8s.io
k top nodes
k -n devops-lab top pods
```

指标需要采样时间；若仍 unavailable，检查 APIService describe、metrics-server 日志、节点 kubelet 网络与证书，不要不停追加参数。重复 patch 前确认参数未存在。

## 4. HPA 实验

`k8s/optional/hpa.yaml` 目标 CPU utilization 60%，是实际 CPU usage 除以 CPU request，不是除以 limit 或整机 CPU。如果 2 个副本平均 90%，粗略期望副本数 `ceil(2 × 90/60)=3`；HPA 实际还考虑容忍区间、指标缺失、就绪状态、稳定窗口等。request 不存在时资源利用率可能无法计算。

```bash
k apply -f k8s/optional/hpa.yaml
k -n devops-lab get hpa
bash scripts/load.sh
k -n devops-lab get hpa -w
# 另终端 source scripts/common.sh 后观察
k -n devops-lab top pods
k -n devops-lab get pods -o wide
```

负载发生器在集群内部持续调用 `/burn`，观察几分钟，副本可能增长至 3–5（实际依机器资源）。若不增长，检查 CPU 指标、request、负载 Pod 日志与访问是否成功，尝试适度增加负载并注意本机资源，不强制期待具体副本数。

```bash
k -n devops-lab delete pod loadgen
k -n devops-lab get hpa -w
# 停止 watch 后
k -n devops-lab delete hpa lab-api
k -n devops-lab scale deploy/lab-api --replicas=2
```

HPA 控制副本数而非节点数量；节点扩缩容通常靠云端 autoscaler/Karpenter 等系统；VPA 用于资源建议/调整，可能与 CPU 型 HPA 形成反馈冲突。启用 HPA 后 GitOps 不应反复覆盖 replicas。实际容量需要压测 QPS/延迟/错误率，而非追求 CPU 永远低。

## 5. 验收

- [ ] 用自己的话计算 utilization，说明 requests、limits、QoS、OOM 区别。
- [ ] 观察故障探针如何影响发布和 EndpointSlice。
- [ ] 记录 HPA idle/load/recovery 三阶段的 CPU 与副本数、可能的阻碍。
- [ ] 能解释 HPA 与节点 autoscaling 的关系；为什么增加 Pod 不一定提高吞吐。
