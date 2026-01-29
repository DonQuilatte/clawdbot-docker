#!/bin/bash
# Implementation dispatcher for TW Mac distributed development
# Usage: ./implement-phase.sh <phase> [task]
# Example: ./implement-phase.sh 1 1.1
#          ./implement-phase.sh 2

set -e

PLAN_FILE="$(dirname "$0")/IMPLEMENTATION-PLAN.md"
PHASE="$1"
TASK="$2"

usage() {
    echo "TW Mac Implementation Dispatcher"
    echo ""
    echo "Usage: $0 <phase> [task]"
    echo ""
    echo "Phases:"
    echo "  1    Environment Synchronization Scripts"
    echo "  2    Context Handoff System"
    echo "  3    Orchestration Skills"
    echo "  4    CLAUDE.md Rules"
    echo "  5    Health Monitor Integration"
    echo "  6    Testing"
    echo ""
    echo "Examples:"
    echo "  $0 1        # Implement all of Phase 1"
    echo "  $0 1 1.1    # Implement only Task 1.1"
    echo "  $0 all      # Implement everything"
    echo ""
    echo "Tasks will be dispatched to Claude Code for implementation."
}

dispatch_local() {
    local instruction="$1"
    echo "═══════════════════════════════════════"
    echo "Dispatching to local Claude Code..."
    echo "═══════════════════════════════════════"
    echo ""
    echo "Instruction:"
    echo "$instruction"
    echo ""
    echo "Run this command to start implementation:"
    echo ""
    echo "claude \"$instruction\""
}

dispatch_tw() {
    local instruction="$1"
    local session="impl-$(date +%H%M%S)"
    echo "═══════════════════════════════════════"
    echo "Dispatching to TW Mac..."
    echo "═══════════════════════════════════════"
    echo ""
    echo "Starting session: $session"

    ~/bin/tw run "tmux new-session -d -s $session 'claude'"
    sleep 2
    ~/bin/tw run "tmux send-keys -t $session '$instruction' Enter"

    echo ""
    echo "Monitor with: ~/bin/tw run 'tmux capture-pane -t $session -p | tail -50'"
    echo "Attach with:  ~/bin/tw run 'tmux attach -t $session'"
}

if [ -z "$PHASE" ]; then
    usage
    exit 1
fi

case "$PHASE" in
    1|1.1)
        dispatch_local "Read $PLAN_FILE and implement Phase 1, Task 1.1: Create the tw-env-sync script at ~/bin/tw-env-sync exactly as specified. Make it executable."
        ;;
    1.2)
        dispatch_local "Read $PLAN_FILE and implement Phase 1, Task 1.2: Create the tw-sync-config script at ~/bin/tw-sync-config exactly as specified. Make it executable."
        ;;
    2|2.1)
        dispatch_local "Read $PLAN_FILE and implement Phase 2, Task 2.1: Create the tw-handoff script at ~/bin/tw-handoff exactly as specified. Make it executable."
        ;;
    2.2)
        echo "Task 2.2 must be implemented ON TW Mac"
        dispatch_tw "Read ~/Development/Projects/clawdbot/infrastructure/tw-mac/IMPLEMENTATION-PLAN.md and implement Phase 2, Task 2.2: Create the read-handoff script at ~/bin/read-handoff exactly as specified. Make it executable."
        ;;
    2.3)
        echo "Task 2.3 must be implemented ON TW Mac"
        dispatch_tw "Read ~/Development/Projects/clawdbot/infrastructure/tw-mac/IMPLEMENTATION-PLAN.md and implement Phase 2, Task 2.3: Create the report-back script at ~/bin/report-back exactly as specified. Make it executable."
        ;;
    3|3.1)
        dispatch_local "Read $PLAN_FILE and implement Phase 3, Task 3.1: Create the /tw-task skill at ~/.claude/commands/tw-task.md exactly as specified."
        ;;
    3.2)
        dispatch_local "Read $PLAN_FILE and implement Phase 3, Task 3.2: Create the /tw-status skill at ~/.claude/commands/tw-status.md exactly as specified."
        ;;
    3.3)
        dispatch_local "Read $PLAN_FILE and implement Phase 3, Task 3.3: Create the /tw-collect skill at ~/.claude/commands/tw-collect.md exactly as specified."
        ;;
    4|4.1)
        dispatch_local "Read $PLAN_FILE and implement Phase 4, Task 4.1: Append the distributed development rules to ~/.claude/CLAUDE.md as specified. Do not overwrite existing content."
        ;;
    4.2)
        echo "Task 4.2 must be implemented ON TW Mac"
        dispatch_tw "Read ~/Development/Projects/clawdbot/infrastructure/tw-mac/IMPLEMENTATION-PLAN.md and implement Phase 4, Task 4.2: Create the TW Mac specific CLAUDE.md at ~/.claude/CLAUDE.md exactly as specified."
        ;;
    5|5.1)
        dispatch_local "Read $PLAN_FILE and implement Phase 5, Task 5.1: Update infrastructure/tw-mac/tw-health-monitor.sh to add the config sync check function as specified."
        ;;
    6|6.1)
        dispatch_local "Read $PLAN_FILE and implement Phase 6, Task 6.1: Create the sync tests at tests/tw-mac/integration/test-env-sync.sh exactly as specified. Make it executable."
        ;;
    all)
        echo "Full implementation requested"
        echo ""
        echo "This will implement all phases sequentially."
        echo "Press Ctrl+C to cancel, or Enter to continue..."
        read

        dispatch_local "Read $PLAN_FILE and implement ALL tasks in the following order: Phase 1 (all), Phase 2.1, Phase 3 (all), Phase 4.1, Phase 5.1, Phase 6.1. Create all scripts and skills exactly as specified."

        echo ""
        echo "After local tasks complete, run TW Mac tasks:"
        echo "  ./implement-phase.sh 2.2"
        echo "  ./implement-phase.sh 2.3"
        echo "  ./implement-phase.sh 4.2"
        ;;
    *)
        echo "Unknown phase: $PHASE"
        usage
        exit 1
        ;;
esac

echo ""
echo "═══════════════════════════════════════"
echo "Implementation dispatched"
echo "═══════════════════════════════════════"
