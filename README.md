# Kubernetes Junior DevOps 实战工程

目标：用约 4–6 周（每天 2–3 小时，约 60–90 小时）的刻意练习，达到初级 DevOps/SRE 面试及日常 Kubernetes 应用运维所要求的核心理解和操作水平。课程以约一年工作经验岗位为目标，不等价于真实生产值班一年，也不保证求职结果。全部在专用本地 kind 集群完成；需要联网下载工具和镜像，无需云账号。

## 学完要能做什么

- 从代码构建镜像，部署服务，解释 API Server、etcd、Scheduler、Controller、kubelet、CRI/CNI/CSI 的职责。
- 独立写 Deployment、Service、ConfigMap、Secret、Job、CronJob、StatefulSet、PVC、HPA、PDB、RBAC 等常见对象。
- 从 DNS、Service、EndpointSlice、Pod、应用监听端口逐层排查请求失败；区分 Ingress 与 Controller。
- 处理 CrashLoopBackOff、镜像拉取失败、Pending、OOMKilled、探针异常、配置错误和不良发布。
- 使用 Helm、Kustomize、GitHub Actions 完成可重复交付；理解 GitOps 和环境隔离。
- 用 metrics-server、Prometheus、Grafana、日志与事件发现问题，编写 incident runbook，落实最小权限和变更回滚。

## 快速启动（先读第 00 章）

```bash
bash scripts/bootstrap.sh
bash scripts/deploy.sh
bash scripts/smoke.sh
kubectl --context kind-junior-devops -n devops-lab port-forward svc/lab-api 8080:80
# 另一个终端
curl http://127.0.0.1:8080/
```

预期 JSON 包含 `version: v1`、随机 Pod hostname 和 message。port-forward 是调试通道，不是生产接入方式。所有脚本使用固定 context；不要把故障实验复制到生产集群。

## 学习路径

| 章节 | 学习内容 | 建议小时 | 交付物 |
|---|---|---:|---|
| [00](docs/00-environment.md) | 环境、容器与命令行 | 4 | 本地三节点集群 |
| [01](docs/01-architecture.md) | 架构、控制循环、YAML | 5 | 架构与请求路径图 |
| [02](docs/02-workloads.md) | Pod、Deployment、更新、配置 | 7 | API v1/v2 回滚记录 |
| [03](docs/03-networking.md) | Service、DNS、Ingress、网络诊断 | 7 | 网络故障记录 |
| [04](docs/04-resources.md) | Requests/Limits、探针、HPA | 7 | 压测与扩缩容记录 |
| [05](docs/05-storage-jobs.md) | 存储、StatefulSet、Job | 5 | 持久化验证 |
| [06](docs/06-security.md) | RBAC、Secret、NetworkPolicy | 5 | 权限正反验证 |
| [07](docs/07-delivery.md) | Helm、Kustomize、CI/CD、GitOps | 7 | CI 结果与 release 记录 |
| [08](docs/08-observability.md) | Prometheus、Grafana、日志、告警 | 7 | 查询、告警与截图 |
| [09](docs/09-troubleshooting.md) | 故障注入、值班、节点维护 | 8 | 至少 7 个故障报告 |
| [10](docs/10-capstone.md) | 综合考试、项目迁移 | 8 | 可展示工程与 runbook |
| [11](docs/11-interview.md) | 面试题、命令手册 | 4 | 无提示演练 |

总计约 74 小时。每章结束先独立做验收，再看下一章。监控和 Ingress 为可选安装件；资源不足时分开运行。核心实验顺序为 00–07、09–11，再回补 08。

## 工程文件地图

```text
app/                  Python HTTP API + Dockerfile
kind.yaml             一控制面 + 两工作节点
k8s/base/             主应用声明式配置（Kustomize）
k8s/optional/         HPA、PDB、Ingress、RBAC、存储、监控等
k8s/faults/           独立故障 Pod
helm/lab-api/         独立 Helm chart 示例
scripts/              启动、部署、冒烟、负载、复位、收集证据、清理
.github/workflows/    GitHub Actions 临时集群测试
k8s/overlays/         环境差异示例
templates/            事故报告、值班记录、验收表
docs/                 逐章教程
```

## 教学规则

手工命令默认在工程根目录的 Bash 中执行（macOS 默认 Zsh 时先运行 `bash`）。每次先记录现象和预期，不先重启；通过证据提出假设，做最小变更，验证用户路径，再把变更提交 Git。看懂不是做会：每个实验至少做两遍，第二遍不看答案。所有输出示例都是预期示意，不是假造的实际集群运行日志。应用是教学用 HTTP 服务，无认证、无生产级并发防护，不可公网部署。

## 清理

`bash scripts/reset.sh` 恢复基础应用及常见故障状态（不卸载可选组件，不删除 PVC）。`bash scripts/cleanup.sh --yes` 删除整个专用 kind 集群及其数据，确认无需保留后才执行。

## 验证说明

交付时对 Python 应用进行了本地 HTTP 冒烟测试，检查了 YAML 解析、脚本语法及关键引用；交付环境未提供 Docker/kind/kubectl/Helm，未实际执行集群实验或 CI。外部 chart 与工具版本可能变化，安装前查看兼容性，记录实际版本。详见 [参考与边界](docs/references.md) 和 `VALIDATION.md`。
