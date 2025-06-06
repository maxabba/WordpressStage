---
name: 🐛 Bug Report
about: Create a bug report for WordPress Docker Stage
title: '[BUG] '
labels: 'bug'
assignees: ''
---

## 🐛 **Bug Description**
A clear and concise description of what the bug is.

## 🖥️ **Environment**
- **Operating System**: [e.g. macOS 14.0, Ubuntu 22.04, Windows 11 WSL2]
- **Docker Version**: [e.g. 24.0.7] (run `docker --version`)
- **Docker Compose Version**: [e.g. 2.23.0] (run `docker-compose --version`)
- **WordPress Version**: [e.g. 6.4.2] (if known)
- **PHP Version**: [e.g. 8.1] (from your .env file)
- **MySQL Version**: [e.g. 8.0] (from your .env file)

## 📋 **Steps to Reproduce**
1. Clone the repository
2. Add backup files to `input_data/`
3. Run `./init.sh`
4. Configure with [specific settings]
5. See error

## 📊 **Backup File Details**
- **WordPress ZIP size**: [e.g. 50MB]
- **Database SQL size**: [e.g. 25MB]
- **WordPress version in backup**: [e.g. 6.3.1] (if known)
- **Number of plugins**: [approximate count] (if known)

## ✅ **Expected Behavior**
A clear and concise description of what you expected to happen.

## ❌ **Actual Behavior**
A clear and concise description of what actually happened.

## 📝 **Error Messages**
```bash
# Paste any error messages here
# Include both terminal output and Docker logs if available
```

## 🔍 **Additional Context**
- Did this work before? [Yes/No]
- Have you tried `./stop-and-clean.sh` and starting fresh? [Yes/No]
- Are you running other Docker containers? [Yes/No]
- Any other relevant information

## 📸 **Screenshots/Logs**
If applicable, add screenshots or log outputs to help explain your problem.

```bash
# You can get logs with:
docker-compose logs
# Or logs for specific service:
docker-compose logs db
```

## 🔧 **Attempted Solutions**
List any troubleshooting steps you've already tried:
- [ ] Restarted Docker
- [ ] Ran `./stop-and-clean.sh`
- [ ] Checked file permissions
- [ ] Tried different ports
- [ ] Cleared browser cache
- [ ] Other: [describe]