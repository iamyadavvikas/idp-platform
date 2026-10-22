# Interview Preparation Guide

## Project Overview (2-minute pitch)

> "I built a production-grade Internal Developer Platform targeting Azure (90%) with AWS/GCP support. The platform enables developers to self-service deployments via GitOps — they push YAML, Flux handles the rest. Key differentiators: cloud-agnostic Terraform modules, Flux v2 GitOps (chosen for Azure Arc integration), Flagger progressive delivery with Prometheus-backed auto-rollback, External Secrets with Workload Identity, and Backstage developer portal with scaffolding templates. The demo shows a Go microservice that canaries through 5 traffic steps and auto-rolls back at 15% error rate."

---

## Technical Deep Dives

### 1. Cloud-Agnostic Architecture

**Q: How did you design for multiple clouds?**

**A**: "I created a module abstraction layer where each module (networking, kubernetes, secrets, dns, identity) has a common interface defined in the root module. The `cloud_provider` variable selects the implementation — `azure/`, `aws/`, or `gcp/` subdirectories. All modules share the same input variables and output schema. Currently Azure is fully implemented with AKS, VNet, Key Vault, Private DNS, Workload Identity. AWS has EKS, VPC, Secrets Manager, IRSA as reference. GCP has stubs."

**Follow-up**: "Show me the networking module structure."
```
modules/networking/
├── main.tf           # Routes to ./azure, ./aws, ./gcp
├── variables.tf      # Common inputs: cidr_block, az_count, tags
├── outputs.tf        # Common outputs: vpc_id, subnet_ids, nat_ids
├── azure/main.tf     # VNet, subnets, NAT Gateway, Private Endpoints
├── aws/main.tf       # VPC, IGW, NAT, VPC Endpoints
└── gcp/main.tf       # Stub
```

### 2. Why Flux over ArgoCD?

**Q: ArgoCD is more popular. Why Flux?**

**A**: "Three specific reasons for Azure-first:
1. **Azure Arc native** - Flux is Microsoft's recommended GitOps controller for Arc-enabled Kubernetes clusters
2. **Simpler architecture** - No Redis, no separate Application controller, no repo-server. Kustomize and Helm controllers are built-in
3. **Image Automation** - Flux Image Reflector + Image Automation Controller replaces the manual `kustomize edit set image` pattern required with ArgoCD. Images pushed to ACR are automatically detected and GitOps manifests updated."

**Follow-up**: "What about ArgoCD's UI?"
"Flux has a read-only UI via Weave GitOps or you can run the Flux dashboard. For developers, Backstage provides the UI layer with embedded ArgoCD/Flux status, so the GitOps controller UI is less critical."

### 3. Progressive Delivery with Flagger

**Q: How does your canary deployment work?**

**A**: "Flagger creates a primary and canary Deployment. It uses a Kubernetes Service with two subsets (primary/canary) and manipulates weights via Cilium/NGINX/Envoy. The canary spec defines 5 steps: 10% → 25% → 50% → 75% → 100%, each with 30s analysis window. At each step, Flagger queries Prometheus:
- Request success rate ≥ 99% (2m window)
- Request duration P99 ≤ 500ms (2m window)

If either breaches, Flagger automatically rolls back. The demo app exposes `/metrics` with configurable error rate, and the Flagger canary watches `http_requests_total`."

**Follow-up**: "What if Prometheus is down?"
"Flagger treats missing metrics as failed analysis after threshold failures. You configure `failureThreshold` (default 3). If Prometheus is unreachable, the canary pauses and alerts fire. In production, you'd run HA Prometheus with Thanos/Cortex for durability."

### 4. Secrets Management

**Q: How do secrets work without storing in Git?**

**A**: "Azure Key Vault is the source of truth. External Secrets Operator (ESO) runs in-cluster and watches `ClusterSecretStore` and `ExternalSecret` resources. ESO uses Workload Identity — each service account has a federated identity credential pointing to a user-assigned managed identity with `Key Vault Secrets User` role. ESO polls Key Vault every 30s and creates native Kubernetes Secrets. Applications consume secrets via standard volume mounts or env vars. Rotation in Key Vault propagates automatically."

**Follow-up**: "What about secret rotation?"
"Key Vault supports automatic rotation for keys/certificates. For passwords, you'd use Key Vault rotation policies or a separate rotation controller. ESO detects changes on next poll (30s default) and updates the K8s Secret. Pods using volume mounts get updates automatically; env var consumers need restart (use Reloader)."

### 5. Workload Identity vs IRSA

**Q: How is Azure Workload Identity different from AWS IRSA?**

**A**: "Conceptually identical — both use OIDC federation between Kubernetes service accounts and cloud IAM. Key differences:
- **IRSA**: Requires IAM OIDC provider per cluster, IAM role with trust policy referencing service account
- **Workload Identity**: Uses Azure AD App Registration + Federated Identity Credential. The credential specifies `subject: system:serviceaccount:ns:name` and `issuer: <AKS OIDC URL>`. No per-cluster OIDC provider needed — AKS exposes OIDC endpoint natively.
- **Managed Identity**: Azure uses User-Assigned Managed Identity as the backing identity (like IAM role), then federates K8s SA to it."

### 6. Service Mesh: Why Cilium?

**Q: Istio is the standard. Why Cilium?**

**A**: "Cilium uses eBPF in the kernel, not sidecars:
- **Performance**: No sidecar overhead (2-3x throughput, 10x lower latency)
- **Azure CNI native**: Works with Azure CNI IP allocation, no CNI conflicts
- **NetworkPolicy enforcement**: At kernel level, not iptables
- **Hubble**: Built-in observability (flow logs, service map)
- **Simpler ops**: Single DaemonSet, no control plane components
- **L7 policies**: HTTP/gRPC visibility without sidecars

Trade-off: Istio has richer traffic management (fault injection, retries, timeouts at mesh level). For our platform, Cilium's NetworkPolicy + Flagger's canary analysis via Prometheus covers 90% of needs."

### 7. Backstage Integration

**Q: How does Backstage fit into the platform?**

**A**: "Backstage is the developer-facing layer:
- **Catalog**: Auto-discovers services from GitHub org + Flux Kustomizations + K8s resources (annotated with `backstage.io/kubernetes-id`)
- **Templates**: `Go Microservice (IDP Standard)` scaffolds repo with Dockerfile, Helm charts, Flux Kustomization, GitHub Actions CI/CD, Terraform, docs
- **TechDocs**: MkDocs builds on push, publishes to S3/Azure Blob, renders in Backstage
- **Plugins**: Embedded Grafana dashboards, Loki logs, Flux status, GitHub Actions runs, K8s resources — all in the service page

The template enforces standards: resource limits, health probes, NetworkPolicies, Workload Identity annotations, Prometheus metrics, Flagger canary."

### 8. Cost Management

**Q: How do you control costs?**

**A**: "Three layers:
1. **Shift-left**: Infracost runs on every Terraform PR, posts cost breakdown as comment. Dev/stage use spot instances (~70% compute savings). Prod shows reserved instance pricing.
2. **Runtime**: Backstage service page shows estimated monthly cost per environment (from Infracost + Azure Pricing API)
3. **Governance**: Future — Azure Budgets with alerts, quota limits per namespace, automated scaling policies

Total estimated: ~$142/mo dev + ~$332/mo stage + ~$323/mo prod = ~$797/mo across 3 environments."

### 9. CI/CD Pipeline

**Q: Walk me through the pipeline.**

**A**: 
```
PR (Terraform)          → terraform fmt/validate/plan + Infracost → PR comment
Merge to main (Terraform) → terraform apply (dev→stage→prod)
PR (App code)           → golangci-lint, go test, build, cosign sign, SBOM
Merge to main (App)     → Push to ACR → Flux Image Reflector detects → 
                          ImagePolicy updates → ImageAutomation commits 
                          new image tag to Git → Flux syncs → 
                          Flagger canary starts
```

### 10. Disaster Recovery

**Q: What's your DR strategy?**

**A**: "Current: Velero backups to Azure Blob (daily, 7d retention). Restore tested quarterly.
Future: Cross-region DR with AKS in paired region, Geo-redundant Key Vault, PostgreSQL geo-replica, ACR geo-replication. RPO: 24h (Velero), RTO: <2h (manual failover). Automated failover would require Cluster API + GitOps promotion."

---

## Behavioral Questions

### "Tell me about a time you made a wrong architectural decision."

**Answer**: "Initially I used ArgoCD because it's more popular. But deploying to Azure AKS, we hit issues: ArgoCD's Redis dependency added operational complexity, and the manual image update pattern (ArgoCD Image Updater) felt clunky compared to Flux's native Image Automation. We migrated to Flux v2 — it took 2 weeks but simplified operations significantly. Lesson: choose tools that align with your cloud provider's ecosystem, not just popularity."

### "How do you handle platform upgrades?"

**Answer**: "GitOps makes this declarative:
1. **AKS upgrades**: Terraform `kubernetes_version` change → plan → apply → nodes drain/replace gracefully
2. **Flux/Flagger/Cilium**: HelmRelease version bump in Flux repo → Flux applies → controllers rolling restart
3. **Backstage**: Helm chart version bump → rolling deployment
4. **Breaking changes**: Test in dev → stage → prod with canary. Use `flux suspend/resume` for controlled rollout."

### "How do you onboard a new team?"

**Answer**: "Backstage template: 5 minutes to scaffold a production-ready service. The template includes everything — Dockerfile, Helm charts with Flagger canary, GitHub Actions CI/CD, Terraform for infra, docs. Team just fills in name, owner, description. Standards are enforced by default (resource limits, probes, NetworkPolicies, Workload Identity). No platform tickets needed."

---

## Questions to Ask Interviewer

1. **Platform maturity**: "What's your current platform state? Kubernetes? GitOps? Service mesh?"
2. **Team structure**: "Platform team size? Dedicated or embedded? How many developers served?"
3. **Cloud strategy**: "Single cloud or multi-cloud? Any regulatory constraints?"
4. **Pain points**: "What's the biggest developer friction today? Deployment speed? Debugging? Standards?"
5. **Roadmap**: "Backstage? Service mesh? Policy engine? Cost governance?"
6. **Culture**: "How are platform decisions made? Top-down or collaborative? How do you measure platform success?"

---

## Resume Bullet Points (Final Polish)

**Senior Platform Engineer**
- Architected cloud-agnostic IDP on Azure AKS with Terraform, Flux v2, Flagger, Cilium, Backstage
- Designed module abstraction layer supporting Azure/AWS/GCP with shared interfaces
- Implemented progressive delivery: 5-step canary (10→25→50→75→100%) with Prometheus analysis, auto-rollback at 15% error rate (<30s)
- Built developer portal with Backstage: catalog, templates (Go microservice scaffolding in 5 min), TechDocs, embedded Grafana/Loki/Flux
- Secured secrets with External Secrets + Azure Key Vault + Workload Identity (zero static credentials)
- Shift-left cost: Infracost in CI/CD ($797/mo across 3 envs), spot instances for dev/stage (70% savings)
- CI/CD: GitHub Actions → ACR (multi-arch, signed, SBOM) → Flux Image Automation → GitOps deploy

---

## Salary Negotiation Data Points

| Factor | Your Evidence |
|--------|---------------|
| **Cloud expertise** | Azure-first (AKS, Key Vault, Workload Identity, ACR, Front Door) + AWS/GCP patterns |
| **Platform scope** | Full stack: IaC, GitOps, Progressive Delivery, Observability, Secrets, Developer Portal |
| **Architecture** | Cloud-agnostic design, module abstraction, multi-environment promotion |
| **Developer experience** | Backstage templates, self-service, embedded observability |
| **Production readiness** | DR, security (mTLS, NetworkPolicies, IRSA), cost governance, compliance hooks |
| **Open source** | CNCF projects: Flux, Flagger, Cilium, Backstage, External Secrets, Prometheus |

---

## Final Tips

1. **Show, don't just tell**: Have the demo running locally or screenshots/GIFs ready
2. **Admit gaps**: "GCP is stubbed, Crossplane not implemented, Kyverno not added" — shows honesty
3. **Connect to their problems**: "You mentioned slow deployments — our GitOps + Flagger reduces that to <15 min with auto-rollback"
4. **Ask about their stack**: Tailor your examples to their cloud/tools
5. **Be ready to whiteboard**: Draw the architecture diagram from memory