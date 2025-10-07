# MCP Configuration

## Available Servers
- **filesystem**: File operations, directory management
- **git**: Git operations, version control
- **playwright**: Browser automation, E2E testing
- **firecrawl**: Web scraping, content extraction
- **context7**: Documentation and library references

## Server Usage Patterns
- Use `filesystem` for file operations over basic Read/Write
- Use `git` for all version control operations
- Use `playwright` for browser testing and automation
- Use `firecrawl` for web research and data extraction
- Use `context7` for up-to-date library documentation

## Recommended Workflows
- File management: `mcp__filesystem__*` tools
- Git operations: `mcp__git__*` tools
- Testing: `mcp__playwright__*` for E2E
- Research: `mcp__firecrawl__*` for web content
- Documentation: `mcp__context7__*` for library refs