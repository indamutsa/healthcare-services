# Code Review Hooks

## Automated Review Checklist

### Security Checks
- No hardcoded secrets or API keys
- Proper input validation
- SQL injection prevention
- XSS protection in frontend

### Performance Checks
- No unnecessary re-renders in React
- Proper async/await usage
- Database query optimization
- Bundle size considerations

### Code Quality
- TypeScript strict mode compliance
- Proper error handling
- Test coverage for new features
- Documentation for complex logic

### Deployment Readiness
- Environment variables properly configured
- Docker builds successfully
- All tests passing
- No console.log statements in production

## Trigger Conditions
- Before pull request creation
- On pull request update
- Before deployment