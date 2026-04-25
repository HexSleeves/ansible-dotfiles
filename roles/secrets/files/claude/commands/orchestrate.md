---
description: Orchestrate multi-agent workflows for complex tasks
argument-hint: [complex task description]
---

# Orchestrate

Launch the **principal-orchestrator** to coordinate multiple specialized agents for complex, multi-domain tasks.

**Task:** $ARGUMENTS

## When to Use

Use `/orchestrate` when your task:

- Spans multiple domains (frontend, backend, infrastructure)
- Requires multiple types of expertise
- Benefits from parallel execution
- Needs strategic coordination
- Is too complex for a single-pass solution

## Orchestration Flow

```
1. RESEARCH (Parallel)
   ├── web-research-specialist: Best practices
   └── architect-advisor: Design options

2. PLAN
   └── Synthesize research into execution plan

3. EXECUTE (Parallel where possible)
   ├── Implementation tasks
   └── Documentation tasks

4. VALIDATE
   └── quality-guardian: Review all changes
```

## Available Specialist Agents

| Agent | Expertise | Use For |
|-------|-----------|---------|
| `principal-orchestrator` | Coordination | Overall task management |
| `architect-advisor` | System design | Architecture decisions |
| `quality-guardian` | Quality/Security | Reviews, audits, plan validation |
| `refactor-planner` | Code improvement | Refactoring strategy |
| `documentation-architect` | Documentation | Creating docs |
| `web-research-specialist` | Research | External information |

## Orchestration Patterns

### Pattern 1: Feature Development

```
DECOMPOSE -> RESEARCH -> PLAN -> (BACKEND || FRONTEND) -> INTEGRATE -> VALIDATE
```

### Pattern 2: Technical Investigation

```
(EXPLORE || RESEARCH) -> SYNTHESIZE -> RECOMMEND
```

### Pattern 3: Code Improvement

```
ANALYZE -> PLAN -> (REFACTOR || TEST) -> REVIEW -> DOCUMENT
```

### Pattern 4: Production Readiness

```
(SECURITY || QUALITY || PERFORMANCE) -> SYNTHESIZE -> REMEDIATE -> VALIDATE
```

## Example Tasks

```bash
# Complex feature implementation
/orchestrate "Add real-time collaboration with WebSockets, conflict resolution, and presence indicators"

# System-wide improvement
/orchestrate "Improve error handling across all services with proper logging and monitoring"

# Technical migration
/orchestrate "Migrate from REST to GraphQL for the user-facing API"

# Security hardening
/orchestrate "Comprehensive security audit and remediation for authentication flow"

# Performance optimization
/orchestrate "Identify and fix performance bottlenecks in the dashboard"
```

## Orchestration Protocol

The orchestrator will:

1. **Analyze** the task and identify required expertise
2. **Decompose** into parallelizable subtasks
3. **Delegate** to specialist agents
4. **Coordinate** parallel execution
5. **Synthesize** results into coherent output
6. **Validate** completeness and quality

## Output

The orchestration produces:

```markdown
## Orchestration Report: [Task]

### Agents Utilized
[List of agents and their contributions]

### Subtasks Completed
[Checklist of completed work]

### Key Decisions Made
[Strategic decisions and rationale]

### Deliverables
[Concrete outputs produced]

### Follow-up Items
[Remaining work or future considerations]

### Knowledge Captured
[Insights worth remembering]
```

## Comparison with Other Commands

| Command | Use When |
|---------|----------|
| `/dev` | Single-domain feature with clear scope |
| `/orchestrate` | Multi-domain, complex coordination needed |
| `/plan` | Need strategy before implementation |
| `/debug` | Investigating a specific issue |
| `/review` | Evaluating existing code |

## Tips for Best Results

1. **Be Specific** - Describe the end goal clearly
2. **Mention Constraints** - Time, technology, compatibility limits
3. **Indicate Priorities** - What matters most?
4. **Allow Autonomy** - Let the orchestrator coordinate

## Behind the Scenes

The orchestrator uses:

- **TodoWrite** for progress tracking
- **Parallel Task calls** for concurrent execution
- **Context synthesis** for integration
- **Quality gates** for validation

This command embodies the principal engineer mindset: strategic thinking, delegation to specialists, and synthesis of expert contributions.
