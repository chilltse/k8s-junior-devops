# 06｜权限、安全与隔离

## 1. 认证、鉴权、准入

请求到 API Server 后，authentication 确定是谁（证书、OIDC、ServiceAccount token 等）；authorization 确定是否允许该 API 操作；admission 可在对象持久化前进行校验/变更。RBAC 是常用鉴权机制，不控制普通应用 HTTP 流量。ServiceAccount 是集群内工作负载身份，不等于 Linux 进程 UID；Pod 的 securityContext 是运行时权限控制。

Role 定义命名空间内权限；ClusterRole 可以定义集群资源权限或可复用的 namespaced 权限；RoleBinding 在指定 namespace 内授予权限（可以引用 ClusterRole）；ClusterRoleBinding 赋予集群范围权限。RBAC 权限是叠加允许，没有普通 deny 规则；不要随手授予 cluster-admin，也不要给读日志的 Agent 修改 Deployment 或访问 Secret 的权限。

## 2. RBAC 最小权限实验

```bash
source scripts/common.sh
k apply -f k8s/optional/rbac.yaml
SA=system:serviceaccount:devops-lab:incident-reader
k auth can-i list pods -n devops-lab --as="$SA"
k auth can-i get pods --subresource=log -n devops-lab --as="$SA"
k auth can-i delete pods -n devops-lab --as="$SA"
k auth can-i list secrets -n devops-lab --as="$SA"
k auth can-i list pods -n kube-system --as="$SA"
```

预期 yes/yes/no/no/no。`--as` 是 impersonation，需当前身份有 impersonate 权限；本地 kind admin 一般具备。日志可能含敏感信息，即使是只读也要脱敏、审计、限制 namespace。生产里为 CI、监控、排障 Agent 分别建身份，使用短期凭证或 workload identity，避免长期静态 token。不要导出 kubeconfig 到公共仓库。

## 3. Secret 不是加密文件

`data` 使用 base64 编码，不是加密；`stringData` 可直接提交明文。实际集群需启用合适的 etcd 加密、最小 RBAC、密钥轮换、审计；更常见的做法是结合外部 Secret Manager/External Secrets/CSI 等组件。环境变量可能被调试工具、崩溃信息或进程泄露；不要在日志打印 secret。

以下仅生成无价值教学占位符：

```bash
k -n devops-lab create secret generic fake-credential --from-literal=API_TOKEN=demo-not-a-real-secret
k -n devops-lab describe secret fake-credential
# 不打印内容；只确认 Secret key 存在
k -n devops-lab get secret fake-credential -o jsonpath='{.metadata.name}'; echo
k -n devops-lab delete secret fake-credential
```

在 PodSpec 内可以 `env.valueFrom.secretKeyRef` 注入，或通过只读 volume 挂载。实际凭证避免以命令行参数、shell history、明文 YAML 或 CI log 暴露；密钥应来自受控来源，泄漏要轮换，而非仅删除 Git 文件。

## 4. Pod 安全

基础 Deployment 已设置非 root、禁止提权、删除全部 Linux capabilities、只读根文件系统、默认 seccomp、关闭自动挂载 SA token。为什么？服务只监听 8080，不需要 root 或访问 Kubernetes API。`readOnlyRootFilesystem` 不限制显式可写 volume；若应用需要 `/tmp`，可挂载有容量限制的 emptyDir。

```bash
k -n devops-lab exec deploy/lab-api -- id
k -n devops-lab exec deploy/lab-api -- sh -c 'touch /app/test' || true
k -n devops-lab get deploy lab-api -o yaml
```

预期 uid 10001，写入 /app 失败。Pod Security Admission 可以根据 namespace label 以 enforce/audit/warn 模式检查 Baseline/Restricted 策略。不要直接在主实验 namespace 强制 restricted（调试 Pod、Redis 示例未全部满足）；另建独立 namespace 做实验并验证拒绝原因，再清理。生产镜像还需要扫描 CVE、固定 digest、签名/来源证明、按版本更新，不应把非 root 当作全部安全措施。

## 5. NetworkPolicy

NetworkPolicy 通过 label/namespace/IP 范围限制 Pod ingress/egress，通常工作在 L3/L4，不是 HTTP 路径鉴权。若多个策略选择同一 Pod，允许集合是并集；通信需满足源 Pod egress 与目标 Pod ingress（若对应方向被隔离）。无选择该 Pod 的策略时，该方向通常默认允许。DNS egress 受限时要允许适当的 DNS 服务通信。

**前置**：先确认集群 CNI 能执行 NetworkPolicy；默认 kind 网络随版本变化，不能仅凭 apply 成功认定隔离生效。可按所选 CNI 官方指南另建实验集群，不要覆盖现有生产 CNI。下列实验既可验证是否真的执行策略，也可在支持的环境里学习。

```bash
k -n devops-lab run allowed --image=busybox:1.36 --labels=access=api --restart=Never --command -- sleep 3600
k -n devops-lab run denied --image=busybox:1.36 --restart=Never --command -- sleep 3600
k -n devops-lab wait --for=condition=Ready pod/allowed pod/denied --timeout=120s
k -n devops-lab exec denied -- wget -T 3 -qO- http://lab-api/
k apply -f k8s/optional/networkpolicy.yaml
# 等待网络策略收敛，分别重复几次
k -n devops-lab exec allowed -- wget -T 3 -qO- http://lab-api/
k -n devops-lab exec denied -- wget -T 3 -qO- http://lab-api/ || true
k delete -f k8s/optional/networkpolicy.yaml
k -n devops-lab delete pod allowed denied
```

若 supported CNI 正常执行，allowed 成功、denied 失败；若两者都成功，先检查 CNI 能力与 policy selector，而不是声称隔离完成。该策略也会阻止未被允许的监控和入口 Pod 访问，所以实验后必须移除。不要用 port-forward 验证普通 Pod 网络策略，因为流量路径不同。

## 6. 验收

- [ ] 创建只读身份并用正反命令证明边界。
- [ ] 解释 Secret 的 base64 与加密区别，说明如何避免 CI 泄漏。
- [ ] 证明非 root 和只读文件系统生效。
- [ ] 能验证 NetworkPolicy 是否真的阻断流量，理解 CNI 依赖。
