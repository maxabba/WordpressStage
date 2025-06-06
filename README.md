# WordPress Docker Development Environment - Automated Local Staging & Testing

![WordPress](https://img.shields.io/badge/WordPress-6.7+-blue.svg)
![Docker](https://img.shields.io/badge/Docker-24.0+-blue.svg)
![PHP](https://img.shields.io/badge/PHP-7.4%20|%208.1%20|%208.2-blue.svg)
![MySQL](https://img.shields.io/badge/MySQL-8.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**WordPress Docker Stage** is a complete, production-ready Docker development environment that automatically imports existing WordPress sites from backup files. Designed for developers, agencies, and WordPress professionals who need reliable local staging environments for WordPress development, testing, and debugging.

## 🎯 **What is WordPress Docker Stage?**

WordPress Docker Stage is an automated Docker-based local development environment that eliminates the complexity of setting up WordPress staging sites. Simply provide your WordPress backup files (ZIP + SQL), and the system automatically:

- **Extracts and configures** your WordPress files
- **Imports your database** with error handling for corrupted backups
- **Migrates URLs** from production to local development
- **Disables problematic plugins** that interfere with development
- **Configures a complete LEMP stack** (Linux, Nginx, MySQL, PHP)

Perfect for WordPress developers, web agencies, freelancers, and anyone who needs to quickly spin up local WordPress environments for development, testing, debugging, or client site management.

## 🚀 **Key Features & Benefits**

### ⚡ **One-Command WordPress Setup**
- **Zero configuration required** - just run `./init.sh`
- **Automatic file detection** in `input_data/` folder
- **Interactive setup wizard** with smart defaults
- **Complete automation** from backup to running site

### 🔧 **Production-Ready Development Stack**
- **WordPress** (Latest version with PHP-FPM)
- **MySQL 8.0** with optimized configuration
- **Nginx** web server with WordPress-optimized rules
- **phpMyAdmin** for database management
- **WP-CLI** for command-line WordPress management

### 🛡️ **Smart Plugin Management**
Automatically disables development-hostile plugins:
- **Security plugins** (Wordfence, Really Simple SSL, etc.)
- **Cache plugins** (WP Rocket, W3 Total Cache, etc.)
- **CDN plugins** (Cloudflare, MaxCDN, etc.)
- **Optimization plugins** (Smush, Autoptimize, etc.)
- **Backup plugins** that can interfere with local development

### 🌐 **Seamless URL Migration**
- **Automatic domain replacement** from production to localhost
- **Database-wide search & replace** with 30,000+ URL updates
- **Handles complex WordPress serialized data**
- **Manual fallback methods** for problematic imports

### 🏗️ **Multi-Site & Team Development**
- **Run multiple WordPress sites** simultaneously
- **Port conflict resolution** with automatic port management
- **Team-friendly configuration** with `.env` files
- **Apple Silicon (M1/M2) optimized** for Mac developers

### 📊 **Advanced Import Capabilities**
- **Handles large databases** (100MB+ SQL files)
- **Error-tolerant imports** (continues despite duplicate entries)
- **Automatic wp-config.php fixing** for Docker environment
- **Database validation** and health checks

## 📋 **System Requirements**

### **Required Software**
- **Docker Desktop 4.0+** ([Download here](https://docs.docker.com/desktop/))
- **Docker Compose** (included with Docker Desktop)
- **Git** (for cloning the repository)

### **Supported Operating Systems**
- **macOS** (Intel & Apple Silicon)
- **Linux** (Ubuntu, Debian, CentOS, etc.)
- **Windows** with WSL2 (Windows Subsystem for Linux)

### **Hardware Recommendations**
- **RAM**: 4GB minimum, 8GB+ recommended
- **Storage**: 2GB free space per WordPress site
- **CPU**: Any modern processor (optimized for multi-core)

## 🚀 **Quick Start Guide**

### **Step 1: Clone the Repository**
```bash
git clone https://github.com/maxabba/WordpressStage.git
cd WordpressStage
```

### **Step 2: Prepare Your WordPress Backup**
1. **WordPress Files**: Place your WordPress ZIP backup in `input_data/`
2. **Database Dump**: Place your SQL database export in `input_data/`

```
input_data/
├── your-wordpress-site.zip     # Complete WordPress file backup
└── your-database-dump.sql      # MySQL database export
```

### **Step 3: Run the Automated Setup**
```bash
chmod +x init.sh
./init.sh
```

The interactive setup will guide you through:
- **Project configuration** (name, ports, PHP version)
- **Automatic file detection** from `input_data/`
- **URL migration setup** (production → localhost)
- **Complete environment provisioning**

### **Step 4: Access Your WordPress Site**
- **WordPress Frontend**: [http://localhost:8080](http://localhost:8080)
- **WordPress Admin**: [http://localhost:8080/wp-admin](http://localhost:8080/wp-admin)
- **phpMyAdmin**: [http://localhost:8082](http://localhost:8082)

## 🏗️ **Architecture & Technology Stack**

### **Container Services**
```yaml
WordPress Containers:
├── 🌐 Nginx (Web Server)           # Port 8080
├── 🐘 PHP-FPM (WordPress Engine)   # Internal
├── 🗄️ MySQL 8.0 (Database)        # Port 3306 (internal)
├── 📊 phpMyAdmin (DB Management)   # Port 8082
└── ⚡ WP-CLI (Command Line Tools)  # On-demand
```

### **File Structure**
```
WordpressStage/
├── 🚀 init.sh                    # Main setup script
├── 🧹 stop-and-clean.sh         # Environment cleanup
├── 🐳 docker-compose.yml        # Container orchestration
├── ⚙️ .env.example              # Configuration template
├── 📁 configs/
│   ├── nginx/default.conf       # Nginx WordPress configuration
│   └── php/custom.ini           # PHP optimization settings
├── 📁 scripts/
│   ├── import.sh                # WordPress import automation
│   └── disable-dev-plugins.sh   # Plugin management
├── 📁 input_data/               # 📥 Place your backups here
│   ├── *.zip                   # WordPress file backups
│   └── *.sql                   # Database exports
└── 📁 data/                     # 🔒 Generated runtime data
    ├── wordpress/              # WordPress files
    ├── mysql/                  # Database files
    └── imports/                # Import staging
```

## ⚙️ **Configuration Options**

### **Environment Variables**
Create `.env` from template and customize:

```bash
# Project Settings
PROJECT_NAME=my-wordpress-site    # Container prefix
SITE_URL_OLD=https://example.com  # Production URL
SITE_URL_NEW=http://localhost:8080 # Local URL

# Network Ports
WEB_PORT=8080                     # WordPress frontend
PMA_PORT=8082                     # phpMyAdmin interface

# Software Versions
PHP_VERSION=8.1                   # PHP version (7.4, 8.1, 8.2)
MYSQL_VERSION=8.0                 # MySQL version
WORDPRESS_VERSION=latest          # WordPress version

# Database Configuration
DB_NAME=wordpress                 # Database name
DB_USER=wordpress                 # Database user
DB_PASSWORD=wordpress             # Database password
DB_ROOT_PASSWORD=root            # MySQL root password

# Development Settings
WP_DEBUG=true                    # Enable WordPress debugging
WP_DEBUG_LOG=true               # Log errors to file
WP_DEBUG_DISPLAY=false          # Hide errors from frontend
```

### **Interactive Setup Options**
When running `./init.sh`, you'll configure:

1. **Project Name** - Used for container naming and isolation
2. **Port Configuration** - Avoid conflicts with other services
3. **PHP Version** - Match your production environment
4. **URL Migration** - Automatic domain replacement
5. **File Detection** - Automatic backup file discovery

## 🎮 **Usage Commands**

### **Primary Operations**
```bash
# 🚀 Start new WordPress environment
./init.sh

# 🛑 Stop and cleanup environment
./stop-and-clean.sh

# 📊 View container status
docker-compose ps

# 📋 View logs
docker-compose logs -f
```

### **Advanced Docker Commands**
```bash
# Start existing environment
docker-compose up -d

# Stop containers (preserve data)
docker-compose down

# Restart specific service
docker-compose restart nginx

# Access container shell
docker-compose exec wordpress bash
```

### **WP-CLI Operations**
```bash
# WordPress core operations
docker-compose run --rm wpcli core version
docker-compose run --rm wpcli core update

# Plugin management
docker-compose run --rm wpcli plugin list
docker-compose run --rm wpcli plugin activate [plugin-name]

# Database operations
docker-compose run --rm wpcli db check
docker-compose run --rm wpcli search-replace "old-url" "new-url"

# User management
docker-compose run --rm wpcli user list
docker-compose run --rm wpcli user create newuser user@example.com
```

## 🚀 **Advanced Use Cases**

### **Multi-Site Development**
Run multiple WordPress sites simultaneously:

```bash
# Site 1
git clone https://github.com/maxabba/WordpressStage.git site1
cd site1
# Edit .env: PROJECT_NAME=site1, WEB_PORT=8080, PMA_PORT=8082
./init.sh

# Site 2  
git clone https://github.com/maxabba/WordpressStage.git site2
cd site2
# Edit .env: PROJECT_NAME=site2, WEB_PORT=8090, PMA_PORT=8092
./init.sh
```

### **Team Development Workflow**
```bash
# 1. Developer creates environment
./init.sh

# 2. Export configuration for team
cp .env .env.team

# 3. Team members use same configuration
cp .env.team .env
./init.sh
```

### **Production-Like Testing**
```bash
# Match production PHP version
PHP_VERSION=7.4 ./init.sh

# Test with specific WordPress version
WORDPRESS_VERSION=6.2 ./init.sh

# Test with larger memory limits
echo "memory_limit = 512M" >> configs/php/custom.ini
docker-compose restart wordpress
```

## 🛠️ **Customization & Extensions**

### **PHP Configuration**
Edit `configs/php/custom.ini`:
```ini
; Upload limits
upload_max_filesize = 128M
post_max_size = 128M

; Memory and execution
memory_limit = 512M
max_execution_time = 300

; Development settings
display_errors = On
error_reporting = E_ALL
log_errors = On
```

### **Nginx Configuration**
Edit `configs/nginx/default.conf`:
```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;

# Performance optimization
gzip on;
gzip_types text/css application/javascript;

# Custom rewrite rules
location /custom-endpoint {
    try_files $uri $uri/ /index.php?$args;
}
```

### **MySQL Optimization**
Add to `docker-compose.yml` under db service:
```yaml
command: >
  --default-authentication-plugin=mysql_native_password
  --innodb-buffer-pool-size=1G
  --innodb-log-file-size=256M
  --max-connections=200
```

## 🐛 **Troubleshooting Guide**

### **Common Issues & Solutions**

#### **🔌 Port Conflicts**
```bash
# Error: Port 8080 already in use
# Solution: Change ports in .env
WEB_PORT=8090
PMA_PORT=8092
```

#### **💾 Database Import Errors**
```bash
# Error: MySQL connection refused
# Solution: Wait for MySQL to fully start
docker-compose logs db
# Wait for "ready for connections" message

# Error: Duplicate entry in SQL
# Solution: Import continues automatically, this is normal
```

#### **🔑 Permission Issues**
```bash
# Error: WordPress can't write files
# Solution: Fix file permissions
sudo chmod -R 755 data/wordpress
sudo chmod -R 777 data/wordpress/wp-content
```

#### **🌐 URL Not Working**
```bash
# Error: Site shows WordPress installation screen
# Solution: Clear browser cache or try incognito mode
# Or check URL migration:
docker-compose run --rm wpcli option get home
```

#### **🐳 Docker Issues**
```bash
# Error: Docker daemon not running
sudo systemctl start docker  # Linux
# Or start Docker Desktop manually

# Error: Out of disk space
docker system prune -f
./stop-and-clean.sh  # Option 4: Full cleanup + Docker prune
```

### **Performance Optimization**

#### **For Large Sites (1GB+ databases)**
```bash
# Increase MySQL memory
echo "innodb_buffer_pool_size = 2G" >> configs/mysql/custom.cnf

# Increase PHP memory
echo "memory_limit = 1G" >> configs/php/custom.ini
```

#### **For Slow Imports**
```bash
# Disable MySQL logging during import
echo "sql_log_bin = 0" >> configs/mysql/import.cnf
```

## 🔒 **Security & Best Practices**

### **⚠️ Development Environment Notice**
This tool is designed for **local development only**:

- ✅ **Safe for local development and testing**
- ✅ **Isolated Docker containers**
- ✅ **No external network exposure by default**
- ❌ **NOT suitable for production hosting**
- ❌ **Uses default passwords (wordpress/wordpress)**
- ❌ **Debug mode enabled**
- ❌ **Security plugins disabled**

### **🛡️ Security Best Practices**
```bash
# Use different credentials for each project
DB_PASSWORD=$(openssl rand -base64 32)

# Restrict network access
# Add to docker-compose.yml:
networks:
  wordpress-network:
    driver: bridge
    internal: true  # Blocks external access

# Regular cleanup
./stop-and-clean.sh  # Clean unused data
docker system prune  # Remove unused containers
```

## 📊 **Performance Metrics**

### **Typical Performance**
- **Setup Time**: 2-5 minutes (depending on backup size)
- **Database Import**: 30MB/minute average
- **Memory Usage**: 512MB-2GB (depends on site size)
- **Disk Usage**: 500MB + site size

### **Benchmarks**
| Site Size | Database | Import Time | Memory Usage |
|-----------|----------|-------------|--------------|
| Small     | <10MB    | 30s         | 512MB        |
| Medium    | 50MB     | 2min        | 1GB          |
| Large     | 200MB    | 8min        | 2GB          |
| Enterprise| 1GB+     | 30min+      | 4GB+         |

## 🤝 **Contributing & Community**

### **How to Contribute**
1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** changes: `git commit -m 'Add amazing feature'`
4. **Push** to branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

### **Contribution Areas**
- 🐛 **Bug fixes** and performance improvements
- 🔧 **New features** and integrations
- 📚 **Documentation** improvements
- 🧪 **Testing** on different platforms
- 🌐 **Internationalization** (translations)

### **Development Setup**
```bash
# Clone for development
git clone https://github.com/maxabba/WordpressStage.git
cd WordpressStage

# Create development branch
git checkout -b feature/your-feature

# Test your changes
./init.sh
# Test with sample WordPress backup
```

## 📞 **Support & Resources**

### **Getting Help**
- 📖 **Documentation**: This README and inline code comments
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/maxabba/WordpressStage/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/maxabba/WordpressStage/discussions)
- 📧 **Email Support**: Create an issue for private matters

### **Useful Resources**
- [Docker Documentation](https://docs.docker.com/)
- [WordPress Developer Resources](https://developer.wordpress.org/)
- [WP-CLI Commands](https://wp-cli.org/commands/)
- [MySQL 8.0 Reference](https://dev.mysql.com/doc/refman/8.0/en/)

## 🏷️ **Keywords & Tags**

**WordPress Development**: WordPress Docker, WordPress staging, WordPress local development, WordPress backup import, WordPress migration, WordPress development environment

**Docker & DevOps**: Docker WordPress, Docker LEMP stack, containerized WordPress, Docker development, local WordPress hosting, WordPress containers

**Web Development**: PHP development environment, MySQL development, Nginx WordPress, local web development, WordPress testing environment, web development tools

**Automation & Tools**: WordPress automation, database migration, URL replacement, plugin management, WordPress CLI, development workflow

## 📝 **License & Legal**

### **MIT License**
```
Copyright (c) 2024 WordPress Docker Stage

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### **Third-Party Software**
This project uses the following open-source software:
- **WordPress**: GPLv2 License
- **MySQL**: GPL License  
- **Nginx**: BSD-like License
- **PHP**: PHP License
- **Docker**: Apache 2.0 License

---

**Made with ❤️ for the WordPress community**

*WordPress Docker Stage - Simplifying WordPress development, one container at a time.*

[![GitHub stars](https://img.shields.io/github/stars/maxabba/WordpressStage?style=social)](https://github.com/maxabba/WordpressStage)
[![GitHub forks](https://img.shields.io/github/forks/maxabba/WordpressStage?style=social)](https://github.com/maxabba/WordpressStage/fork)
[![GitHub issues](https://img.shields.io/github/issues/maxabba/WordpressStage)](https://github.com/maxabba/WordpressStage/issues)