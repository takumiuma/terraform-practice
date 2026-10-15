<!-- INVARIANT: examples are single-line HTML comments so a fresh template parses to total=0 (MEMORY_EMPTY). Do NOT un-comment or split across lines. t100 guards this. -->
> This file is kept up to date automatically while the stage runs. Add observations at the review step, not by editing here directly.

## Interpretations
<!-- example: 2026-05-29T10:14:32Z — chose REST over GraphQL; the consuming team only needs CRUD, revisit if subscriptions land -->

## Deviations
<!-- example: 2026-05-29T10:14:32Z — skipped the optional caching layer the stage prose suggested; the dataset is small enough that it adds risk -->

## Tradeoffs
<!-- example: 2026-05-29T10:14:32Z — picked TDD over BDD this run; the team is unit-first and the domain is well-understood -->

## Open questions

- 2026-08-30 destroy後も残るリソース（ECRイメージ、state）の扱いは要件/設計フェーズで確定予定。intent段階ではassumptionとして保持。
- 2026-08-30 「一番安く」の具体水準（Fargate Spot、最小vCPU/mem、NAT要否、リージョン）はNFR/インフラ設計で詰める。
- 2026-08-30 GitHubリポジトリ・Goアプリ実体は後続フェーズで確定。
<!-- example: 2026-05-29T10:14:32Z — confirm the retention window with compliance before the next stage hardens the schema -->
