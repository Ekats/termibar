# Codebase Analysis Commands

This codebase is indexed with mca into a knowledge graph at .mco.db.
Prefer these over grep/search for code analysis — the graph has pre-parsed relationships, call edges, and semantic links.
All read-only queries are safe. Use --db flag for non-code data.

## Search & Discover
```bash
mca search "query"                # FTS5 across all nodes
mca search "query" -t item        # filter: item|category|concept|decision|reference
mca focus "what am I looking for" # entropy-ranked relevant nodes
mca node similar <id>             # semantically similar nodes
```

## Read & Inspect
```bash
mca node get <id>                 # full node content + metadata
mca graph read-content <id>       # node content only, no noise
mca code show <id>                # source code from disk for code nodes
```

## Navigate Relationships
```bash
mca nav edges <id>                # all edges for a node
mca nav tree <id>                 # subtree from a node
mca nav path <from-id> <to-id>   # find paths between nodes
mca graph edges-for-context <id>  # most relevant edges, ranked
mca graph explain-edge <edge-id>  # edge with full context + chain
```

## Structure & Health
```bash
mca nav folder                    # code nodes as folder tree
mca nav ls <id>                   # children of a node
mca graph list-region <id>        # all descendants of a category
mca graph status                  # coverage, coherence, activity
mca code stale                    # code nodes whose files are gone
mca orphans                       # nodes with no parent
mca recent                        # recently modified nodes
```

## Orchestrator (mco)
```bash
mco analyze                       # topology, hubs, bridges, staleness
mco context-for-task <id>         # Dijkstra context expansion
```
