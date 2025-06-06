# Contributing to WordPress Docker Stage

Thank you for your interest in contributing to WordPress Docker Stage! This project helps WordPress developers create local staging environments quickly and reliably.

## 🚀 **Quick Development Setup**

1. **Fork** this repository on GitHub
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/WordpressStage.git
   cd WordpressStage
   ```
3. **Create** a feature branch:
   ```bash
   git checkout -b feature/amazing-feature
   ```
4. **Test** your changes:
   ```bash
   ./init.sh
   # Test with various WordPress backup files
   ```
5. **Commit** your changes:
   ```bash
   git add .
   git commit -m "Add amazing feature: brief description"
   ```
6. **Push** to your fork:
   ```bash
   git push origin feature/amazing-feature
   ```
7. **Submit** a Pull Request with a clear description

## 🎯 **Ways to Contribute**

### 🐛 **Bug Fixes**
- Fix import issues with specific WordPress versions
- Resolve Docker compatibility problems
- Improve error handling and user feedback
- Fix platform-specific issues (macOS, Linux, Windows WSL2)

### 🔧 **New Features**
- Support for additional PHP/MySQL versions
- Integration with popular WordPress tools
- Performance optimizations
- New plugin management features
- Enhanced URL migration capabilities

### 📚 **Documentation**
- Improve README.md clarity and completeness
- Add troubleshooting guides for specific scenarios
- Create video tutorials or guides
- Translate documentation to other languages
- Add code comments and inline documentation

### 🧪 **Testing**
- Test on different operating systems
- Test with various WordPress site types and sizes
- Create automated test cases
- Performance testing and benchmarking
- Edge case testing (large databases, complex plugins)

### 🌐 **Platform Support**
- Windows improvements (beyond WSL2)
- ARM architecture optimizations
- Cloud deployment adaptations
- CI/CD integration examples

## 🧪 **Testing Guidelines**

### **Required Testing**
Before submitting a PR, please test:

1. **Basic functionality** on your platform:
   ```bash
   ./init.sh
   # Verify WordPress loads at localhost:8080
   # Verify phpMyAdmin loads at localhost:8082
   ```

2. **Different WordPress backup sizes**:
   - Small site (<10MB database)
   - Medium site (50-100MB database)
   - Large site (>100MB database)

3. **URL migration** with real WordPress data:
   - Test production → localhost URL replacement
   - Verify images and links work correctly
   - Check serialized data handling

4. **Plugin disable functionality**:
   - Test with sites that have security plugins
   - Test with sites that have cache plugins
   - Verify disabled plugins don't interfere

### **Cross-Platform Testing**
We especially need testing on:
- **macOS** (Intel and Apple Silicon)
- **Linux** (Ubuntu, Debian, CentOS, etc.)
- **Windows WSL2** (Ubuntu, Debian distributions)

### **Performance Testing**
For performance-related changes:
- Measure import times for different database sizes
- Monitor memory usage during import
- Test with resource-constrained environments

## 📋 **Code Standards**

### **Shell Scripts**
- Use `#!/bin/bash` shebang
- Include error handling with `set -e` where appropriate
- Use meaningful variable names
- Add comments for complex logic
- Test with `shellcheck` before submitting

### **Docker Configuration**
- Follow Docker best practices
- Use specific version tags when possible
- Optimize for build speed and image size
- Ensure compatibility with older Docker versions

### **Documentation**
- Use clear, concise language
- Include code examples for new features
- Update README.md for user-facing changes
- Add inline comments for complex code

## 🔍 **Development Tips**

### **Local Development Workflow**
```bash
# 1. Make your changes
vim scripts/import.sh

# 2. Test with a real WordPress backup
./stop-and-clean.sh  # Clean previous test
./init.sh            # Test your changes

# 3. Check logs if issues occur
docker-compose logs -f

# 4. Test cleanup functionality
./stop-and-clean.sh
```

### **Debugging Import Issues**
```bash
# Check database import progress
docker-compose exec db mysql -uroot -proot -e "SHOW PROCESSLIST;"

# Check WordPress file extraction
ls -la data/wordpress/

# Check container health
docker-compose ps
docker-compose logs [service-name]
```

### **Testing Different Scenarios**
```bash
# Test different PHP versions
echo "PHP_VERSION=7.4" > .env
./init.sh

# Test different MySQL versions  
echo "MYSQL_VERSION=5.7" >> .env
./init.sh

# Test with custom ports
echo "WEB_PORT=8090" >> .env
echo "PMA_PORT=8091" >> .env
./init.sh
```

## 📝 **Pull Request Guidelines**

### **PR Title Format**
Use descriptive titles with prefixes:
- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation changes
- `test:` for testing improvements
- `refactor:` for code refactoring
- `perf:` for performance improvements

Examples:
- `feat: add support for PHP 8.2`
- `fix: resolve MySQL connection timeout on slow systems`
- `docs: improve troubleshooting guide for port conflicts`

### **PR Description Template**
```markdown
## 🎯 **What this PR does**
Brief description of the changes.

## 🔧 **Type of change**
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that causes existing functionality to not work)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Refactoring (no functional changes)

## 🧪 **Testing**
- [ ] Tested on macOS
- [ ] Tested on Linux
- [ ] Tested on Windows WSL2
- [ ] Tested with small WordPress sites (<10MB)
- [ ] Tested with large WordPress sites (>100MB)
- [ ] Tested URL migration functionality
- [ ] Tested plugin disable functionality

## 📋 **Checklist**
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes

## 📸 **Screenshots/Logs**
If applicable, add screenshots or log outputs.
```

## 🚨 **Reporting Issues**

### **Before Creating an Issue**
1. Check existing issues for duplicates
2. Test with the latest version
3. Try the troubleshooting steps in README.md
4. Gather relevant system information

### **Issue Templates**
Use the provided issue templates:
- **Bug Report**: For reproducible problems
- **Feature Request**: For new functionality ideas
- **Question**: For usage questions and support

## 🏷️ **Labels and Milestones**

### **Priority Labels**
- `priority: critical` - Blocking issues, security vulnerabilities
- `priority: high` - Important bugs, popular feature requests
- `priority: medium` - Standard improvements
- `priority: low` - Nice-to-have features

### **Type Labels**
- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Improvements or additions to docs
- `question` - Further information is requested
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention is needed

## 🎉 **Recognition**

Contributors will be:
- Listed in the README.md contributors section
- Credited in release notes for significant contributions
- Given collaborator access for ongoing contributors
- Featured in social media posts for major contributions

## 📞 **Getting Help**

- **Questions**: Create a [Question issue](https://github.com/maxabba/WordpressStage/issues/new?template=question.md)
- **Discussion**: Use [GitHub Discussions](https://github.com/maxabba/WordpressStage/discussions)
- **Real-time chat**: Join our [Discord server](https://discord.gg/wordpressdocker) (if available)

## 📜 **Code of Conduct**

This project adheres to a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

---

**Thank you for contributing to WordPress Docker Stage!** 🎉

Your contributions help thousands of WordPress developers create better staging environments and ship higher quality websites.