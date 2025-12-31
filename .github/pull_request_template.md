## Description

<!-- Provide a clear and concise description of your changes -->

## Type of Change

<!-- Mark the relevant option with an "x" -->

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Refactoring (no functional changes)
- [ ] CI/CD changes
- [ ] Security fix

## Stack Impact

<!-- Which stack(s) does this PR affect? -->

- [ ] Main Stack (16GB RAM, 100 services)
- [ ] Light Stack (2GB RAM, 13 services)
- [ ] Both stacks

## Testing Done

<!-- Describe the tests you ran and how to reproduce them -->

- [ ] All services start successfully (`make up`)
- [ ] Validation passes (`make validate`)
- [ ] Linting passes (`make lint`)
- [ ] Security scan passes (`make security`)
- [ ] Manual testing completed
- [ ] Tested on native Linux
- [ ] Tested on Termux/Android

### Test Environment

- OS:
- Docker version:
- Docker Compose version:
- Hardware (RAM/CPU):

## Checklist

<!-- Ensure all items are completed before submitting -->

- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings or errors
- [ ] I have updated the CHANGELOG.md (if applicable)
- [ ] I have tested my changes on both stacks (if applicable)
- [ ] All services remain healthy after changes
- [ ] No secrets or sensitive information are exposed
- [ ] Resource limits are appropriate (CPU/memory)
- [ ] Environment variables are documented in .env.example

## Breaking Changes

<!-- If this is a breaking change, describe the impact and migration path -->

## Related Issues

<!-- Link related issues using #issue_number -->

Closes #
Relates to #

## Screenshots/Logs

<!-- If applicable, add screenshots or relevant logs -->

## Additional Notes

<!-- Any additional information that reviewers should know -->
