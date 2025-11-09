# 🤝 Contributing to Homelab Boilerplate

Thank you for your interest in contributing to this homelab boilerplate project!

## Project Philosophy

This project serves multiple purposes:

1. **Personal Documentation** - A comprehensive record of my homelab journey
2. **Boilerplate Template** - A starting point for others building similar infrastructure
3. **Learning Resource** - Educational material for homelab enthusiasts
4. **Community Knowledge** - Shared experiences and solutions

## Ways to Contribute

### 1. 📖 Documentation Improvements

- Fix typos or clarify instructions
- Add missing steps you discovered
- Translate sections (while keeping English as primary)
- Add screenshots or diagrams
- Document your own setup variations

### 2. 🐛 Bug Reports

Found an issue? Please report it with:

- What you were trying to do
- What happened vs. what you expected
- Your environment (Proxmox version, hardware, etc.)
- Steps to reproduce
- Error messages or logs

### 3. 💡 Feature Suggestions

Have ideas for improvements? Open an issue with:

- Clear description of the feature
- Use case or problem it solves
- Proposed implementation (if you have one)

### 4. 🔧 Code Contributions

#### For Infrastructure Code

- Terraform configurations
- Packer templates
- Scripts and automation

**Guidelines**:
- Test changes on your own setup first
- Document why changes were needed
- Keep configurations generic and customizable
- Update relevant documentation

#### For Documentation

- Follow the existing structure and style
- Use clear, beginner-friendly language
- Include examples and code blocks
- Test commands and instructions

### 5. 🌟 Share Your Setup

Customized this boilerplate for your homelab? Share it!

- Fork this repository
- Document your customizations
- Share in GitHub Discussions
- Link to your fork in issues/discussions

Others can learn from your configuration choices.

## Contribution Process

### For Documentation and Minor Changes

1. Fork the repository
2. Create a branch (`git checkout -b docs/improve-gpu-guide`)
3. Make your changes
4. Test if applicable (run commands, verify links)
5. Commit with clear message
6. Push and create a Pull Request

### For Infrastructure Changes

1. Fork the repository
2. Create a branch (`git checkout -b feature/add-monitoring`)
3. Make changes and test on your setup
4. Document the changes in relevant docs
5. Update README if needed
6. Commit and create Pull Request with:
   - Description of changes
   - Why they're beneficial
   - Testing you performed

## Commit Message Guidelines

Use clear, descriptive commit messages:

```
✅ Good:
- "docs: Add YubiKey SSH setup instructions"
- "terraform: Increase default worker RAM to 16GB"
- "fix: Correct Packer boot command for Ubuntu 24.04"

❌ Avoid:
- "update"
- "fix stuff"
- "changes"
```

## Code Style

### Terraform

- Use consistent indentation (2 spaces)
- Add comments for complex configurations
- Use meaningful resource names
- Group related resources together

### Packer

- Follow HCL2 format
- Comment provisioner steps
- Use variables for customizable values

### Documentation

- Use Markdown format
- Include code blocks with syntax highlighting
- Add emoji for visual markers (✅ 🔧 📚 etc.)
- Use tables for structured data
- Include examples

## Questions?

- Open a GitHub Discussion for general questions
- Open an Issue for bugs or specific problems
- Tag appropriately (documentation, terraform, packer, etc.)

## Recognition

Contributors will be:
- Listed in release notes
- Credited in relevant documentation
- Appreciated by the homelab community! 🎉

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Thank You!

Every contribution, no matter how small, helps make this project better for everyone in the homelab community.

---

**Happy Homelabbing!** 🚀
