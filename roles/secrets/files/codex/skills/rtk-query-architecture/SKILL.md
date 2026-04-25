---
name: rtk-query-architecture
description: Design, implement, and review RTK Query data layers with consistent endpoint contracts, cache tagging, invalidation strategy, and error handling. Use when adding or changing RTK Query endpoints, fixing stale-data bugs, reviewing API integration PRs, or creating tests for query/mutation behavior.
---

# RTK Query Architecture

Implement RTK Query work with contract-first typing, explicit cache tags, and deterministic tests.

## Workflow

1. Define endpoint contract first.
2. Add or update endpoint with typed `query`, `transformResponse`, and `providesTags`/`invalidatesTags`.
3. Verify cache lifecycle for create/update/delete flows.
4. Add tests for success, error, and cache invalidation behavior.
5. Run project tests and lint before finalizing.

## Implementation Rules

- Type raw API responses and transformed output separately.
- Keep `transformResponse` pure and resilient to missing fields.
- Use stable tag IDs (`LIST` plus entity IDs) and invalidate only what changed.
- Avoid duplicating normalization logic across endpoints; share helpers when shape repeats.
- Prefer endpoint-local helpers for serialization/parsing over component-level data massaging.

## Review Checklist

Use `references/review-checklist.md` for a line-by-line PR review pass.

## Test Expectations

- Assert that mutation invalidates the expected tag set.
- Assert refetch occurs for dependent queries after mutation.
- Assert error paths preserve typed error objects and do not throw in `transformResponse`.
- Add regression tests for any stale-data bug found in review or UAT.
