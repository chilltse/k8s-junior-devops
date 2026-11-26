# 08｜可观测性：Metrics、Logs、Events、Alerting

## 1. 监控应该回答什么问题

Metrics 用数值时间序列表示变化；Logs 表示离散事件；Traces 关联跨服务请求路径；Kubernetes Events 记录近期调度、拉镜像、探针等事件（通常有保留期限，不能替代长期审计）。三者互补。初级 SRE 要以用户影响为起点，而不是 CPU 超过某个数字就认定事故。

RED：Rate（请求速率）、Errors（错误）、Duration（耗时）。USE：Utilization（利用率）、Saturation（饱和度）、Errors（资源错误）。Google SRE 四个黄金信号：latency、traffic、errors、saturation。SLI 是测量指标，SLO 是目标，例如 30 天 99.9% 成功请求；error budget 是允许的失败比例（0.1%，假设定义清楚且按请求计）。SLA 是对客户的协议，不能把 SLO 直接等同赔偿承诺。

## 2. 无外部组件的基本观察

```bash
source scripts/common.sh
bash scripts/smoke.sh
k -n devops-lab get pods -o wide
k -n devops-lab logs -l app=lab-api --prefix=true --tail=50
k -n devops-lab get events --sort-by=.metadata.creationTimestamp
k -n devops-lab top pods  # 已装 metrics-server 才可用
k -n devops-lab port-forward svc/lab-api 8080:80
# 另终端
curl http://127.0.0.1:8080/
curl -i http://127.0.0.1:8080/error
curl http://127.0.0.1:8080/metrics
```

代码记录结构化 JSON 日志（route、status、pod、duration_ms）；不要在日志记录 token、密码或完整用户敏感输入。stdout/stderr 适合容器日志采集；`kubectl logs --previous` 只能读上一次已终止容器实例且日志仍可访问时的数据。生产通常用 Fluent Bit/Vector 等采集，汇入 Loki/Elastic/云日志，设置保留、采样和权限。

## 3. 安装 kube-prometheus-stack（可选，较耗资源）

Prometheus 定期 scrape 指标并保存时间序列，Grafana 查询展示，Alertmanager 路由和聚合告警；kube-state-metrics 将 Kubernetes 对象状态转换为指标，node-exporter 提供节点指标。Prometheus Operator 通过 CRD 管理配置，例如 ServiceMonitor 与 PrometheusRule。Metrics Server 不等于 Prometheus。

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo prometheus-community/kube-prometheus-stack --versions | head
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --kube-context kind-junior-devops -n monitoring --create-namespace \
  -f k8s/optional/monitoring-values.yaml --wait --timeout 10m
k -n monitoring get pods,svc
k get crd | grep monitoring.coreos.com
k apply -f k8s/optional/servicemonitor.yaml
k apply -f k8s/optional/prometheusrule.yaml
```

记录实际 chart version；若资源不足或安装失败，先 `k -n monitoring get pods`、`describe pod`、`get events` 排查，不要无限重装。kind 上某些 control-plane/node-exporter 告警可能由本地拓扑和指标暴露差异造成，不表示业务不可用。查看 ServiceMonitor selector 与 namespaceSelector，确认选中了 devops-lab 中的 Service 和名为 http 的端口。配置已将 Helm 默认 selector 限制放宽，仅适合这个教学集群；生产应限制可被抓取的 namespace 和 selector。

```bash
# 确认实际 Service 名；以下为通常的 chart 默认名
k -n monitoring get svc
k -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
# 另一个终端
k -n monitoring port-forward svc/monitoring-grafana 3000:80
```

浏览器打开 http://127.0.0.1:9090 查看 Prometheus Targets 与 Graph，打开 http://127.0.0.1:3000 查看 Grafana。登录 Grafana 默认用户通常为 admin，使用本地 Secret 中的实验密码（仅自己查看，不截图或分享）：`k -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo`。若名称或字段变化，查看实际 chart 资源。不要设置 `--address 0.0.0.0`。

## 4. PromQL 从零练习

先从客户端持续请求服务，使时间序列有样本（否则部分指标可能尚不存在）。Counter 单调增加但重启归零，rate 会处理常见 reset；Gauge 可上下变化。Histogram 通过 buckets 估计分位数；本教学应用只提供 duration sum/count，能求平均但不能精确计算 P95/P99，切勿拿平均值冒充尾延迟。

```promql
# 抓取成功情况，先检查对应 job/namespace label
up{namespace="devops-lab"}
# 业务请求速率（排除探针）
sum(rate(lab_http_requests_total{route!~"/healthz|/readyz"}[2m]))
# 业务 5xx 错误比例，分母下限避免除零；无流量不应被误判为健康
sum(rate(lab_http_requests_total{route!~"/healthz|/readyz",status=~"5.."}[2m])) / clamp_min(sum(rate(lab_http_requests_total{route!~"/healthz|/readyz"}[2m])), 0.000001)
# 每秒平均耗时（秒），路由维度可拆分
sum(rate(lab_http_request_duration_seconds_sum{route="/"}[2m])) / clamp_min(sum(rate(lab_http_request_duration_seconds_count{route="/"}[2m])), 0.000001)
# 每 Pod CPU（核）
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="devops-lab",container="api"}[5m]))
# 当前内存工作集（MiB）
sum by (pod) (container_memory_working_set_bytes{namespace="devops-lab",container="api"}) / 1024 / 1024
# 期望与实际可用副本差值
kube_deployment_spec_replicas{namespace="devops-lab",deployment="lab-api"} - kube_deployment_status_replicas_available{namespace="devops-lab",deployment="lab-api"}
```

错误比率在没有任何 5xx 系列时可能返回空向量而不是 0，可根据 dashboard 需求使用 `or vector(0)`，但要单独监控无流量/无指标；不能把 absent 当作成功。Grafana 建四个 panel：请求率、5xx 比例、平均耗时、可用副本差。查询需与实际 scrape labels 校准，记录图表单位和采样窗口。

## 5. 告警触发实战

`k8s/optional/prometheusrule.yaml` 监控 2 分钟窗口的业务 5xx 速率 > 0.05/s 并持续 1 分钟。它是方便教学的绝对阈值，不是生产 SLO 告警；生产需结合错误比例、请求量、多个时间窗口 burn rate 与告警路由。告警 pending 表示条件成立但尚未达到 for，firing 表示已达到持续时间。

在 API port-forward 已启动的终端之外：

```bash
# 只向本地练习服务发请求；Ctrl-C 可随时停止
for i in $(seq 1 150); do curl -s -o /dev/null http://127.0.0.1:8080/error; sleep 1; done
```

在 Prometheus Alerts 页面观察 LabApiErrors pending→firing；然后停止制造错误，等待窗口内旧错误逐渐消失。若 alert 未触发，查 Targets、规则是否加载、查询是否有结果；port-forward 所指 Pod 若重建需重新启动。Alertmanager 负责接收路由，但本例未配置真实邮件/Slack/PagerDuty，不能宣称已完成通知交付。

## 6. 验收与清理

- [ ] 解释 metrics/logs/traces/events 四类证据，以及 metrics-server 与 Prometheus 区别。
- [ ] 验证 scrape target、完成四个 Grafana panel、理解指标单位。
- [ ] 制造错误并观察告警恢复；说明低流量和无数据如何处理。
- [ ] 写出可操作的告警 runbook，包含查询、影响判断和升级条件。

停止所有 port-forward。卸载时先 `k delete -f k8s/optional/prometheusrule.yaml -f k8s/optional/servicemonitor.yaml --ignore-not-found`，再 `helm uninstall monitoring --kube-context kind-junior-devops -n monitoring`。部分 CRD/PVC 可能保留，最终可删除专用 kind 集群；不要在共享集群删除公共 CRD。
