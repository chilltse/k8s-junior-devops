# 02｜Pod、Deployment、配置与发布回滚

## 1. Pod 是什么

Pod 是调度的最小单元，内部容器通常共享网络 namespace、IP、端口空间，可通过 localhost 通信；可显式共享 volume。Pod 不是镜像，不保证永久存在。多容器 Pod 常用 sidecar 提供代理、日志处理等紧密协作能力；init container 在普通应用容器启动前依次完成任务（普通 init 语义），不能把任意两个业务服务塞进同一 Pod，否则无法独立扩缩容和发布。

常用工作负载：Deployment 管理无状态副本；StatefulSet 管理稳定身份与存储；DaemonSet 为符合条件的节点放置 Pod（例如节点日志采集）；Job 执行有限任务；CronJob 按计划创建 Job。裸 Pod 适合调试而不是长期业务服务。

## 2. 逐行读 Deployment

打开 `k8s/base/deployment.yaml`。`selector.matchLabels` 必须与 `template.metadata.labels` 匹配，Deployment 创建后 selector 不可随意修改。顶层 metadata labels 只是 Deployment 的标签，不会自动成为 Pod 标签。`replicas` 是期望副本数，`template.spec.containers` 才是容器描述。`containerPort` 是声明，不会把端口发布到宿主机；进程要真正监听 `0.0.0.0:8080`。

`imagePullPolicy: IfNotPresent` 优先用节点缓存；kind 的 Docker 镜像仓库和节点 containerd 镜像库不同，故必须 `kind load docker-image`。生产使用唯一 tag 或 digest，不覆盖已发布 tag，否则各节点可能缓存不同版本。

```bash
source scripts/common.sh
bash scripts/deploy.sh
k -n devops-lab get pod -l app=lab-api -o wide
k -n devops-lab describe deploy lab-api
k -n devops-lab logs deploy/lab-api --tail=20
k -n devops-lab exec deploy/lab-api -- python -c 'import os; print(os.getenv("APP_MESSAGE"))'
```

`logs deploy/...` 默认可能只选一个 Pod，排查所有副本使用 `logs -l app=lab-api --prefix=true --tail=100`。`exec` 是容器内执行命令，不是 SSH 节点。多容器使用 `-c` 指定容器。调试期间不要直接改容器文件代替正式发布。

## 3. 滚动更新实验

Deployment 的 RollingUpdate 创建新 ReplicaSet 并逐步缩小旧 ReplicaSet。maxSurge=1 允许临时超出目标 1 个副本；maxUnavailable=0 试图维持目标可用副本数，新版本必须 readiness 成功才逐步移除旧版。资源不足时可能卡住。`minReadySeconds` 让 Pod 持续 Ready 一段时间才计作 Available；`progressDeadlineSeconds` 超时会标记未能推进，并不自动回滚。

```bash
docker build -t lab-api:v2 app
kind load docker-image lab-api:v2 --name junior-devops
# 同时改变镜像 tag 与应用版本环境变量；一次 patch，避免触发两次发布
k -n devops-lab patch deploy lab-api --type=strategic -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","image":"lab-api:v2","env":[{"name":"APP_VERSION","value":"v2"}]}]}}}}'
k -n devops-lab rollout status deployment/lab-api --timeout=180s
k -n devops-lab rollout history deploy/lab-api
k -n devops-lab get rs
bash scripts/smoke.sh
```

预期 API 显示 v2；这里 v1/v2 代码相同，版本与镜像 tag 只是为了演练发布机制。在第二终端观察 `k -n devops-lab get pods -w`。如果需要检查发布期间可用性，从集群内连续调用 Service，而不是把 port-forward 当负载均衡测试。

```bash
k -n devops-lab rollout undo deploy/lab-api
k -n devops-lab rollout status deploy/lab-api
bash scripts/smoke.sh
```

预期返回 v1。rollback 恢复 Pod template，不保证恢复数据库 schema、ConfigMap 或外部状态。生产发布应保证向后兼容，数据库迁移常用 expand/migrate/contract；回滚应用可能无法回滚已写数据。`rollout history` 取决于旧 ReplicaSet 保留情况。

## 4. ConfigMap 与 Secret

配置与镜像分离。ConfigMap 用于非敏感参数，Secret 用于敏感信息（见第 06 章）；都可通过 env、envFrom 或 volume 注入。env 在容器启动时确定，ConfigMap 修改不自动更新现有进程环境；以普通 projected volume 挂载的文件通常最终更新（subPath 例外），应用仍需支持重读。

```bash
k -n devops-lab patch configmap lab-api-config --type=merge -p '{"data":{"APP_MESSAGE":"updated config"}}'
bash scripts/smoke.sh  # 旧 message
k -n devops-lab rollout restart deploy/lab-api
k -n devops-lab rollout status deploy/lab-api
bash scripts/smoke.sh  # 新 message
```

Helm 可将配置 checksum 加入 Pod template annotation 来触发更新；Kustomize 的 configMapGenerator 可生成带哈希名称的 ConfigMap 并更新引用。避免在一个命名空间出现相同名字、不同所有权的对象。恢复基础配置时须显式重启，因为配置不是 Pod template 的一部分：

```bash
k apply -k k8s/base
k -n devops-lab rollout restart deploy/lab-api
k -n devops-lab rollout status deploy/lab-api
```

## 5. SIGTERM 与优雅退出

删除 Pod 时系统开始终止流程；如果配置 preStop，会执行该 hook，运行时向主进程发送终止信号，超过 grace period 可能强制结束。端点更新、流量摘除和进程关闭存在异步竞态，不承诺零请求丢失。应用要停止接受新流量、处理进行中请求、及时退出；健康检查和 LB 也要配合。阅读 Python server 的 SIGTERM handler（简化示例，不是完整请求排空实现）。

## 6. 验收

- [ ] 从空白写出一个 2 副本 Deployment（不复制）并验证 selector。
- [ ] 解释 Pod、ReplicaSet、Deployment 关系；执行发布、历史查看、回滚。
- [ ] 观察配置变更前后 env；说明为何 rollout undo 不会恢复 ConfigMap。
- [ ] 写一份变更前检查、变更中验证、变更后回滚条件的 checklist。
