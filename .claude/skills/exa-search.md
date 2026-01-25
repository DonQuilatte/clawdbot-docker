---
name: exa-search
description: AI-powered web search using Exa API for documentation, research, and code context. Use when you need real-time web search, finding similar pages, or researching companies/technologies.
---

# Exa Search Skill

AI-powered search engine optimized for LLMs and developers.

## When to Use This Skill

- Finding up-to-date documentation and API references
- Researching technologies, libraries, or frameworks
- Finding similar pages to a given URL
- Code context and examples from the web
- Company research and LinkedIn profiles
- Deep research with comprehensive results

## Available Exa Tools

### Web Search
```bash
# Basic search
web_search_exa(query="Docker security best practices", numResults=10)

# With date filtering
web_search_exa(query="Claude API updates", startPublishedDate="2025-01-01")

# Domain-specific search
web_search_exa(query="node.js containerization", includeDomains=["docker.com", "nodejs.org"])
```

### Code Context
```bash
# Find code examples
get_code_context_exa(query="Docker compose health check examples")

# Find implementation patterns
get_code_context_exa(query="seccomp profile for Node.js containers")
```

### Crawling
```bash
# Get full content from a URL
crawling_exa(url="https://docs.docker.com/compose/")
```

### Company Research
```bash
# Research a company
company_research_exa(query="Anthropic AI")
```

### Deep Researcher
```bash
# Start comprehensive research
deep_researcher_start(query="Container security hardening techniques")

# Check research status
deep_researcher_check(researchId="...")
```

## MCP Configuration

### Remote Server (Recommended)
```json
{
  "mcpServers": {
    "exa": {
      "type": "http",
      "url": "https://mcp.exa.ai/mcp?exaApiKey=YOUR_EXA_API_KEY"
    }
  }
}
```

### Local Server (npx)
```json
{
  "mcpServers": {
    "exa": {
      "command": "npx",
      "args": ["-y", "exa-mcp-server", "tools=web_search_exa,get_code_context_exa,crawling_exa"],
      "env": {
        "EXA_API_KEY": "your-api-key"
      }
    }
  }
}
```

## Context7 Libraries

| Library | ID | Snippets |
|---------|-----|----------|
| Exa Docs | `/websites/exa_ai` | 1,572 |
| Exa API | `/llmstxt/exa_ai_llms_txt` | 1,458 |

## Example Workflows

### Research Docker Security
```
1. web_search_exa("Docker container security 2025")
2. get_code_context_exa("seccomp profile examples")
3. crawling_exa("https://docs.docker.com/engine/security/")
```

### Find Similar Documentation
```
1. find_similar_exa(url="https://docs.docker.com/compose/")
2. Analyze related documentation sources
```

## API Key Setup

1. Get API key from https://exa.ai
2. Set environment variable: `export EXA_API_KEY="your-key"`
3. Or include in MCP URL: `https://mcp.exa.ai/mcp?exaApiKey=YOUR_KEY`
