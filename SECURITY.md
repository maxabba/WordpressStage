# Security Policy

## 🛡️ **Supported Versions**

We actively support and provide security updates for the following versions:

| Version | Supported          | End of Support |
| ------- | ------------------ | -------------- |
| 1.x.x   | ✅ Active support  | TBD            |
| < 1.0   | ❌ No longer supported | 2024-01-01 |

## 🚨 **Reporting Security Vulnerabilities**

We take security seriously. If you discover a security vulnerability, please follow these steps:

### **DO NOT** create a public GitHub issue for security vulnerabilities.

### **Instead, please:**

1. **Email us privately** at: `security@[your-domain].com`
2. **Use the subject line**: `[SECURITY] WordPress Docker Stage - [Brief Description]`
3. **Include the following information**:
   - Description of the vulnerability
   - Steps to reproduce the issue
   - Potential impact and attack scenarios
   - Any proof-of-concept code (if applicable)
   - Your contact information

### **Response Timeline**

- **Initial Response**: Within 48 hours
- **Confirmation/Triage**: Within 1 week
- **Fix Development**: Within 2 weeks (depending on complexity)
- **Public Disclosure**: After fix is released and users have time to update

## 🔒 **Security Considerations**

### **⚠️ Development Environment Only**

**IMPORTANT**: This tool is designed exclusively for local development environments. It includes several security trade-offs that make it unsuitable for production use:

#### **Known Security Limitations**
- **Default Credentials**: Uses `wordpress/wordpress` for database access
- **Debug Mode Enabled**: WordPress debug information is exposed
- **Security Plugins Disabled**: Automatically disables security-focused plugins
- **Permissive File Permissions**: Sets liberal file permissions for development ease
- **No HTTPS by Default**: Uses HTTP for local development
- **No Firewall Configuration**: Docker containers use default networking

### **🛡️ Security Best Practices for Users**

#### **Network Security**
```bash
# Limit network exposure (add to docker-compose.yml)
networks:
  wordpress-network:
    driver: bridge
    internal: true  # Prevents external network access
```

#### **Credential Security**
```bash
# Use unique passwords for each project
DB_PASSWORD=$(openssl rand -base64 32)
DB_ROOT_PASSWORD=$(openssl rand -base64 32)
```

#### **File Security**
```bash
# Regularly clean up unused environments
./stop-and-clean.sh

# Remove sensitive data from backups before import
# Remove production API keys, credentials, etc.
```

#### **Host Security**
- Keep Docker Desktop updated to the latest version
- Don't expose Docker daemon to network
- Use Docker Desktop security features
- Regularly update base Docker images

### **🔍 Common Security Issues**

#### **Port Exposure**
```bash
# Problem: Ports accessible from network
# Solution: Bind to localhost only
ports:
  - "127.0.0.1:8080:80"  # Instead of "8080:80"
```

#### **Data Persistence**
```bash
# Problem: Sensitive data in volumes
# Solution: Regular cleanup
docker-compose down -v  # Removes volumes
./stop-and-clean.sh     # Full cleanup
```

#### **Container Privileges**
```bash
# Problem: Containers running as root
# Solution: Use specific user (advanced users)
user: "1000:1000"  # Add to services in docker-compose.yml
```

## 🧪 **Security Testing**

### **Automated Security Scanning**

We use the following tools to scan for security issues:
- **Docker Scout**: Container vulnerability scanning
- **Hadolint**: Dockerfile security linting
- **ShellCheck**: Shell script security analysis
- **GitHub Security Advisories**: Dependency vulnerability monitoring

### **Manual Security Review**

Regular security reviews include:
- Dockerfile security best practices
- Docker Compose configuration security
- Shell script injection vulnerability testing
- Default credential auditing
- Network exposure assessment

## 📋 **Security Checklist for Contributors**

When contributing code, please verify:

- [ ] **No hardcoded secrets** in code or configuration
- [ ] **Input validation** for user-provided data
- [ ] **Safe shell script practices** (proper quoting, validation)
- [ ] **Minimal file permissions** where possible
- [ ] **Container security** best practices
- [ ] **Documentation** of security implications

## 🚫 **Out of Scope**

The following are **not considered security vulnerabilities** for this project:

1. **Production deployment issues** - This tool is not designed for production
2. **WordPress core vulnerabilities** - Use latest WordPress and security plugins in production
3. **Plugin vulnerabilities** - We disable plugins specifically to avoid these issues
4. **Docker security issues** - Use Docker security features and keep Docker updated
5. **Host OS vulnerabilities** - Keep your operating system updated

## 📚 **Security Resources**

### **Docker Security**
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Docker Bench Security](https://github.com/docker/docker-bench-security)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)

### **WordPress Security**
- [WordPress Security Guide](https://wordpress.org/support/article/hardening-wordpress/)
- [OWASP WordPress Security](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/01-Information_Gathering/02-Fingerprint_Web_Application_Framework)

### **Container Security**
- [NIST Container Security Guide](https://csrc.nist.gov/publications/detail/sp/800-190/final)
- [Snyk Container Security](https://snyk.io/learn/container-security/)

## 🏆 **Responsible Disclosure**

We appreciate security researchers and developers who responsibly disclose vulnerabilities. Security contributors will be:

- **Credited** in the security advisory (unless they prefer to remain anonymous)
- **Listed** in our Hall of Fame
- **Eligible** for bug bounty programs (if implemented)

## 📞 **Contact**

For security-related questions or concerns:
- **Email**: `security@[your-domain].com`
- **PGP Key**: Available on request
- **Response Time**: Within 48 hours

---

**Remember**: This is a development tool. Never use it in production environments or expose it to the internet.