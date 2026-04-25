# RTK Query Review Checklist

## Endpoint Contract
- Verify request params type matches caller usage.
- Verify response type includes nullable/optional fields from backend.
- Verify `transformResponse` output type matches UI consumer expectations.

## Cache and Invalidation
- Verify `providesTags` includes both `LIST` and entity-level tags where needed.
- Verify mutations invalidate only affected entities and dependent lists.
- Verify no broad invalidation causes unnecessary refetch storms.

## Error and Edge Cases
- Verify non-2xx responses map to typed error handling.
- Verify empty arrays, partial objects, and missing nested fields are handled safely.
- Verify optimistic updates (if used) include rollback path.

## Test Coverage
- Verify query success and empty-result test exists.
- Verify mutation success and invalidation test exists.
- Verify mutation failure path test exists.
- Verify bugfix PR includes a targeted regression test.
