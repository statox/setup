# immich_ml_orchestrator

Deploys a cron-driven bash script to panda that scales the on-demand
`immich-machine-learning` ECS Fargate service (provisioned by Terraform in
`statox-provisioning/terraform/immich/ml_worker.tf`) up when Immich has
failed Smart Search / Face Detection / Duplicate Detection jobs, and back
down after 10 minutes of no such failures.

The orchestrator runs every 5 minutes via cron: it polls Immich's job
counts, scales the ECS service (0 -> 1) via `aws ecs update-service` when
Smart Search/Face Detection/Duplicate Detection jobs have failures, waits
for the task to be running, resolves its public IP and updates the
`immich-ml.statox.fr` Route53 record to point at it, then re-triggers
those jobs. It scales back down (1 -> 0) after `IDLE_GRACE_SECONDS` of no
pending failures, and also force-scales down after `MAX_SCALED_UP_SECONDS`
as a cost safety net regardless of state. Logs are appended to
`/home/immich/ml_orchestrator/orchestrator.log` on panda.

## Required variables

- `immich_ml_orchestrator_immich_url` - same value as `immich_ui_domain`'s
  `https://` URL, e.g. `https://immich.statox.fr`.
- `immich_ml_orchestrator_immich_api_key` - an Immich API key with
  `job.read`/`job.create`/`job.update` scope, generated once manually in
  Immich's Account Settings.
- `immich_ml_orchestrator_aws_access_key_id` /
  `immich_ml_orchestrator_aws_secret_access_key` - the
  `immich-ml-orchestrator` IAM user's access key, from Terraform's
  `immich_ml_orchestrator_access_key` output.
- `immich_ml_orchestrator_ecs_cluster` / `immich_ml_orchestrator_ecs_service`
  / `immich_ml_orchestrator_route53_zone_id` - from Terraform's
  `immich_ml_ecs_cluster_name` / `immich_ml_ecs_service_name` /
  `immich_ml_route53_zone_id` outputs.
- `immich_ml_orchestrator_ml_dns_name` (optional, default
  `immich-ml.statox.fr`) - the DNS name the orchestrator updates on every
  scale-up. Must match whatever is set as Immich's ML Settings URL below.

## One-time manual step (not automated by this role)

After `terraform apply`, confirm the Cloudflare -> Route53 NS delegation
for `immich-ml.statox.fr` has propagated (e.g. `dig NS immich-ml.statox.fr`),
then open Immich's admin Machine Learning Settings and set the URL to
`http://immich-ml.statox.fr:3003`. This is permanent and is never touched
by the orchestrator script - only the DNS record's target IP changes,
automatically, on every scale-up.
