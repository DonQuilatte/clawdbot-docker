#!/bin/bash
# Smart Task Dispatcher - Intelligently routes tasks to TW Mac
# Analyzes task complexity and current load before dispatching

TW_CONTROL="$HOME/bin/tw"
HANDOFF_DIR="$HOME/tw-mac/handoffs"
LOG_FILE="$HOME/.claude/tw-mac/dispatcher.log"

mkdir -p "$(dirname "$LOG_FILE")" "$HANDOFF_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check TW Mac availability and load
check_tw_capacity() {
    local ACTIVE_SESSIONS=$("$TW_CONTROL" run 'tmux list-sessions 2>/dev/null | wc -l' 2>/dev/null || echo "99")
    local CPU_IDLE=$("$TW_CONTROL" run "top -l 1 | grep 'CPU usage' | awk '{print \$7}' | tr -d '%'" 2>/dev/null || echo "0")

    # Max 5 concurrent sessions, and CPU idle > 20%
    if [ "$ACTIVE_SESSIONS" -lt 5 ] && [ "${CPU_IDLE%.*}" -gt 20 ]; then
        echo "available"
    else
        echo "busy"
    fi
}

# Estimate task complexity (simple heuristic)
estimate_complexity() {
    local TASK="$1"
    local COMPLEXITY=1

    # Keywords that increase complexity
    [[ "$TASK" =~ (refactor|rewrite|redesign|architect) ]] && ((COMPLEXITY+=2))
    [[ "$TASK" =~ (test|tests|testing) ]] && ((COMPLEXITY+=1))
    [[ "$TASK" =~ (review|audit|analyze) ]] && ((COMPLEXITY+=1))
    [[ "$TASK" =~ (document|documentation) ]] && ((COMPLEXITY+=1))
    [[ "$TASK" =~ (all|entire|full|complete) ]] && ((COMPLEXITY+=1))

    echo "$COMPLEXITY"
}

# Dispatch task with smart routing
dispatch() {
    local TASK="$1"
    local PRIORITY="${2:-normal}"
    local SESSION_PREFIX="${3:-task}"

    local CAPACITY=$(check_tw_capacity)
    local COMPLEXITY=$(estimate_complexity "$TASK")

    log "Task: $TASK"
    log "Complexity: $COMPLEXITY, TW Mac: $CAPACITY, Priority: $PRIORITY"

    if [ "$CAPACITY" = "busy" ] && [ "$PRIORITY" != "high" ]; then
        log "TW Mac busy, queuing task"
        queue_task "$TASK" "$PRIORITY"
        return 1
    fi

    # Create handoff
    local TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    local SESSION="${SESSION_PREFIX}-${TIMESTAMP}"
    local HANDOFF_FILE="$HANDOFF_DIR/handoff-$TIMESTAMP.md"

    cat > "$HANDOFF_FILE" << EOF
# Dispatched Task

**ID:** $TIMESTAMP
**Priority:** $PRIORITY
**Complexity:** $COMPLEXITY/5
**Dispatched:** $(date)

## Task

$TASK

## Instructions

1. Complete the task as specified
2. Log progress to /tmp/task-$TIMESTAMP.log
3. Write summary to ~/handoffs/response-$TIMESTAMP.md

EOF

    # Start session
    "$TW_CONTROL" run "tmux new-session -d -s $SESSION 'claude'" 2>/dev/null
    sleep 2
    "$TW_CONTROL" run "tmux send-keys -t $SESSION 'Read ~/handoffs/handoff-$TIMESTAMP.md and complete the task' Enter" 2>/dev/null

    log "Dispatched to session: $SESSION"
    echo "$SESSION"
}

# Queue task for later execution
queue_task() {
    local TASK="$1"
    local PRIORITY="$2"
    local QUEUE_FILE="$HOME/.claude/tw-mac/task-queue.txt"

    echo "$PRIORITY|$(date +%s)|$TASK" >> "$QUEUE_FILE"
    log "Task queued: $TASK"
}

# Process queued tasks
process_queue() {
    local QUEUE_FILE="$HOME/.claude/tw-mac/task-queue.txt"

    if [ ! -f "$QUEUE_FILE" ]; then
        return
    fi

    local CAPACITY=$(check_tw_capacity)
    if [ "$CAPACITY" = "busy" ]; then
        return
    fi

    # Get highest priority task
    local NEXT_TASK=$(sort -t'|' -k1,1r -k2,2n "$QUEUE_FILE" | head -1)

    if [ -n "$NEXT_TASK" ]; then
        local TASK=$(echo "$NEXT_TASK" | cut -d'|' -f3-)
        local PRIORITY=$(echo "$NEXT_TASK" | cut -d'|' -f1)

        # Remove from queue
        grep -v "^$NEXT_TASK$" "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"

        log "Processing queued task: $TASK"
        dispatch "$TASK" "$PRIORITY" "queued"
    fi
}

# Main
case "$1" in
    dispatch)
        shift
        dispatch "$@"
        ;;
    queue)
        shift
        queue_task "$1" "${2:-normal}"
        ;;
    process)
        process_queue
        ;;
    status)
        echo "TW Mac Capacity: $(check_tw_capacity)"
        echo "Active Sessions: $("$TW_CONTROL" run 'tmux list-sessions 2>/dev/null | wc -l' || echo 0)"
        echo "Queued Tasks: $(wc -l < "$HOME/.claude/tw-mac/task-queue.txt" 2>/dev/null || echo 0)"
        ;;
    *)
        echo "Usage: $0 {dispatch|queue|process|status} [task] [priority]"
        echo ""
        echo "Commands:"
        echo "  dispatch 'task description' [high|normal|low]"
        echo "  queue 'task description' [priority]"
        echo "  process  - Process queued tasks"
        echo "  status   - Show dispatcher status"
        ;;
esac
