---
name: gin-ecs-cheapest-terraform
depth: Standard
keywords: []
description: Stand up a cost-optimized Gin server on ECS, provisioned with Terraform
skeleton: on
---

# gin-ecs-cheapest-terraform scope

Composed custom scope for standing up a Gin (Go) HTTP server on Amazon ECS at
the lowest reasonable cost, with the infrastructure implemented in Terraform.
Standard depth. Runs a focused discovery + design + build spine and skips the
ideation framing and product-discovery ceremony that this well-scoped,
single-intent infrastructure task does not need.

## Why these stages, why skip those

The intent is concrete (a Gin server, on ECS, cheapest, in Terraform), so the
ideation framing stages (market-research, feasibility, scope-definition,
team-formation, rough-mockups) are SKIP. There is no product UI or persona
surface, so user-stories and refined-mockups are SKIP; there is no existing
application to map, so reverse-engineering is SKIP.

EXECUTE covers the spine the task actually needs: intent-capture and
approval-handoff frame and gate the work; practices-discovery and
requirements-analysis pin conventions and acceptance criteria; nfr-requirements
carries the cost-optimization objective that drives the whole design;
units-generation and delivery-planning decompose and sequence the Terraform
work; infrastructure-design produces the ECS + networking topology;
code-generation writes the Terraform (and Gin server) code; build-and-test
verifies it.

## Membership

Composed scope — resolves by `--scope gin-ecs-cheapest-terraform` only and does
not participate in keyword inference (keywords intentionally empty).
Initialization (workspace-scaffold, workspace-detection, state-init),
intent-capture, approval-handoff, practices-discovery, requirements-analysis,
units-generation, delivery-planning, nfr-requirements, infrastructure-design,
code-generation, and build-and-test execute; all other stages skip.
