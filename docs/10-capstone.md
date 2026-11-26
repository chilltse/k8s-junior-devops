# 10｜综合项目与能力验收

## 1. 目标

你接手一个运行于 Kubernetes 的内部 API。必须交付可重复部署、两副本健康检查、资源限制、可观测性、故障响应和最小权限。它不是把所有 YAML apply 一次的截图项目，而是证明你能在不可预期的状态下找到原因并安全恢复。

核心挑战（约 6–8 小时）：从空 kind 集群开始，独立写 namespace、ConfigMap、Deployment、Service，不照抄本工程；构建镜像、加载镜像、发布与验证；做 v2 更新并回滚；安装 metrics-server 及 HPA；以实际指标验证压测；至少注入 3 个随机故障；配置只读身份并验证无 delete/secret 权限；最后做节点维护和清理。监控扩展：用 Prometheus/Grafana 显示业务错误与可用副本，记录告警生命周期。要求能解释每一步，不只是运行脚本。

## 2. 综合实验评分（100 分）

| 类别 | 分数 | 证据 |
|---|---:|---|
| 架构与资源对象 | 15 | 不看文档画控制面与网络图，解释 ownerReferences |
| 部署与发布 | 20 | 镜像、健康检查、回滚、冒烟结果 |
| 网络与存储 | 15 | DNS、EndpointSlice、端口故障与 PVC 持久化 |
| 资源与稳定性 | 15 | HPA 指标、探针、节点维护、PDB 局限 |
| 安全与交付 | 10 | RBAC 正反验证、Git/CI、Helm |
| 故障排查 | 15 | 3 个陌生故障，每次证据→结论→修复→验证 |
| 可观测性与文档 | 10 | PromQL、告警、runbook、复盘 |

自测 80+ 且无严重安全错误（误操作生产 context、泄漏凭证、盲目删除数据、伪造证据）可认为核心实验已掌握。这个分数是课程自测，不是行业认证；真实团队还会考 Linux、网络、云、IaC、代码、值班沟通与业务理解。

## 3. 将实验迁移到 PianoKT / Agentic DevOps（选做）

不要为了简历把已有 Cloud Run 生产服务强行迁到 GKE。先做独立 kind staging 模拟，采用相同的 API/Worker/Relay 角色，使用假的数据库和对象存储或测试环境。现有系统中的 Cloud Run 自动扩缩容、Pub/Sub、GCS、Supabase 与 Kubernetes 原生组件不是一一等价。

| 原组件角色 | K8s 实验映射 | 注意点 |
|---|---|---|
| API | Deployment + Service + Ingress | readiness、请求超时、JWT、连接池、滚动升级 |
| 异步 Worker | Deployment | 消费幂等、ack 时机、重试、队列积压，不能仅 CPU 扩缩容 |
| 定时 Relay | CronJob 或持续 Deployment | 取决于任务语义；补偿需去重、并发控制 |
| KT 推理服务 | 独立 Deployment + 内部 Service | 模型加载 startup probe、缓存状态、内存与 GPU 资源 |
| GCS/Supabase | 保持外部托管或 mock | workload identity、TLS、备份；不简单换成 PVC |
| 事件与日志 | Prometheus + 日志聚合 | 队列年龄、重试率、错误率、P95、延迟 |

Agentic DevOps 的第一个里程碑应该是只读调查而非自动修复。可以将第 06 章的 ServiceAccount 用于证据读取，Agent 仅通过受限工具获取 Pod status、events、deployment 和脱敏 logs；模型不持有 cluster-admin、shell、任意 URL 或 Secret 权限。先用第 09 章故障生成黄金样本：症状、证据、根因、建议命令、风险和验证。工具输出可能包含不可信指令；不要让 LLM 把日志里的文本作为运维授权。修复建议由人工审批；后续增加 dry-run、命令 allowlist、审计、回滚及独立执行身份。

建议仓库展示：架构图、复现实验、CI 结果、监控截图（脱敏）、至少三份事故报告、实际测量数据与局限。面试可说“在本地多节点集群完成应用交付和故障模拟”，不要说“有一年生产 K8s 值班经验”或“运维过大规模生产集群”，除非确实做过。

## 4. Junior 工作场景补充

真实团队常见日常：早上查告警与变更，PR review Deployment/Helm 变更，验证 staging，协助业务发布，处理失败 Pod/网络/容量，记录 incident，改进 runbook；重要变更由团队流程审核。Kubernetes 管理员还需学习版本升级、etcd 备份/恢复、证书轮换、云 IAM、CSI/CNI 升级、容量与成本、HA control plane、节点池维护。此课程只讲职责边界，不在单机 kind 上伪装生产控制面 HA 演练。

## 5. 最终交付 checklist

- [ ] 从空环境复现，不依赖以前运行的 Pod 和手工补丁。
- [ ] 确认每个命令目标 context，清理本地负载和调试 Pod。
- [ ] CI 绿色与实际运行证据、版本、commit hash 对得上。
- [ ] 没有密钥、PII、生产 URL 或未脱敏日志进入仓库。
- [ ] 能面对陌生故障进行证据式排查，而不是依赖题库。
