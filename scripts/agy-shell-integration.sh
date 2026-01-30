# AGY Shell Integration - Auto-detect projects
# Source this file in ~/.zshrc: source ~/Development/Projects/dev-infra/scripts/agy-shell-integration.sh

# Auto-engage when entering a project directory
agy_auto_engage() {
    local current_dir="$PWD"
    local projects_dir="$HOME/Development/Projects"
    
    # Only trigger in project directories
    if [[ "$current_dir" == "$projects_dir"/* ]]; then
        # Check if this is a project (has .envrc or scripts/project-setup.sh)
        if [ -f ".envrc" ] || [ -f "scripts/project-setup.sh" ]; then
            local project_name
            project_name=$(basename "$current_dir")
            
            # Check if we haven't already notified for this project in this session
            if [[ "${AGY_LAST_PROJECT:-}" != "$project_name" ]]; then
                export AGY_LAST_PROJECT="$project_name"
                
                echo ""
                echo "📍 Project detected: $project_name"
                echo "💡 Quick commands:"
                echo "   agy              # Start Claude locally"
                echo "   agy -r \"task\"    # Run task on TW Mac"
                echo "   agy -r status    # View all remote jobs"
                echo ""
            fi
        fi
    fi
}

# Hook into directory changes (zsh only, works in interactive shells)
if [[ -n "$ZSH_VERSION" ]] && [[ -o interactive ]]; then
    autoload -U add-zsh-hook 2>/dev/null
    if [[ $? -eq 0 ]]; then
        add-zsh-hook chpwd agy_auto_engage
    fi
fi

# Convenience aliases
alias a='agy'
alias agys='agy -r status'
