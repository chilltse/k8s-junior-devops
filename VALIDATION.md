# 交付验证记录

已在生成环境实际执行并通过：

- Python 编译与本机 HTTP 冒烟测试：`/`、`/healthz`、`/readyz`（true/false）、`/error`、`/burn`、404、`/metrics`，检查状态码和错误计数。
- 非模板 YAML 文件的语法解析（不是 Kubernetes schema 校验）。
- 全部 Bash 脚本 `bash -n` 语法检查。
- Kustomize resources 路径、Deployment/Service selector 与 named port 一致性检查。

未执行：Docker build、kind 创建与实际集群部署、Kubernetes server dry-run、Helm 渲染、Ingress/HPA/Prometheus 实验、GitHub Actions。生成环境没有 Docker/kind/kubectl/Helm。请在本机按第 00 章启动，然后运行 `bash scripts/deploy.sh` 与 `bash scripts/smoke.sh` 作为第一道实际验收。外部 chart 选项和兼容性以实际版本为准。

课程中标注的命令结果为预期，不是实际生产运行日志；课程不等同于一年真实工作经验。
