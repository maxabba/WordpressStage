# WordPress Docker Stage

A complete Docker-based WordPress development environment that automatically imports existing WordPress sites from ZIP and SQL files. Perfect for staging, development, and testing WordPress sites locally.

## 🚀 Features

- **One-command setup** - Just run `./init.sh` after adding your files
- **Automatic import** - Extracts WordPress files and imports database
- **Development-ready** - Automatically disables problematic plugins (security, cache, etc.)
- **URL migration** - Automatic search-replace for domain changes
- **Multi-site support** - Run multiple WordPress instances simultaneously
- **M1 Mac compatible** - Optimized for Apple Silicon
- **Complete stack** - WordPress, MySQL, Nginx, phpMyAdmin, WP-CLI

## 📋 Prerequisites

- Docker Desktop 4.x or higher
- Docker Compose
- macOS, Linux, or Windows with WSL2

## 🛠️ Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/wordpress-docker-stage.git
   cd wordpress-docker-stage
   ```

2. **Add your WordPress files**
   - Place your WordPress ZIP file in `input_data/`
   - Place your database SQL dump in `input_data/`

3. **Run the initialization script**
   ```bash
   ./init.sh
   ```

4. **Access your site**
   - WordPress: http://localhost:8080
   - phpMyAdmin: http://localhost:8081

That's it! The script will handle everything else automatically.

## 🎯 What Gets Installed

### Docker Services
- **WordPress** (PHP-FPM)
- **MySQL** 8.0
- **Nginx** (Alpine)
- **phpMyAdmin**
- **WP-CLI**

### Automatically Disabled Plugins
The following plugins are automatically disabled to prevent development issues:
- Security plugins (Really Simple SSL, Wordfence, etc.)
- Cache plugins (WP Rocket, W3 Total Cache, etc.)
- CDN plugins
- Image optimization plugins
- Backup plugins
- Update managers

## 📁 Project Structure

```
wordpress-docker-stage/
├── init.sh                 # Main initialization script
├── stop-and-clean.sh      # Cleanup script
├── docker-compose.yml     # Docker configuration
├── docker-compose.override.yml # Auto-disable plugins service
├── configs/
│   ├── nginx/
│   │   └── default.conf   # Nginx configuration
│   └── php/
│       └── custom.ini     # PHP settings
├── scripts/
│   ├── import.sh          # WordPress import script
│   └── disable-dev-plugins.sh # Plugin disable script
├── input_data/            # Place your .zip and .sql files here
└── data/                  # WordPress files and MySQL data (auto-created)
```

## 🔧 Configuration

The `init.sh` script will interactively ask for:
- Project name (for container prefixes)
- WordPress port (default: 8080)
- phpMyAdmin port (default: 8081)
- PHP version (default: 8.1)
- MySQL version (default: 8.0)
- Old domain for URL migration (optional)

### Environment Variables
Copy `.env.example` to `.env` and customize as needed:

```bash
PROJECT_NAME=wp
WEB_PORT=8080
PMA_PORT=8081
PHP_VERSION=8.1
MYSQL_VERSION=8.0
```

## 🎮 Usage

### Start Environment
```bash
./init.sh
```

### Stop Environment
```bash
./stop-and-clean.sh
```

Options:
1. Stop containers only
2. Stop and clean WordPress data
3. Full cleanup (removes everything)
4. Full cleanup + Docker prune

### Manual Operations
```bash
# Start containers
docker-compose up -d

# Stop containers
docker-compose down

# View logs
docker-compose logs -f

# Run WP-CLI commands
docker-compose run --rm wpcli [command]
```

## 🚀 Advanced Usage

### Running Multiple Sites
1. Clone the repository to different folders
2. Change the `PROJECT_NAME` and ports in each `.env`
3. Run `./init.sh` in each folder

### Custom PHP Settings
Edit `configs/php/custom.ini` to modify:
- Upload limits
- Memory limits
- Execution time
- Error reporting

### Custom Nginx Configuration
Edit `configs/nginx/default.conf` for:
- Custom rewrite rules
- Security headers
- Performance optimizations

## 🐛 Troubleshooting

### Port Already in Use
Change the ports in `.env`:
```bash
WEB_PORT=8090
PMA_PORT=8091
```

### Permission Issues
```bash
chmod -R 777 data/wordpress/wp-content
```

### Database Connection Failed
Ensure the database container is running:
```bash
docker-compose ps
docker-compose logs db
```

## 🔒 Security Notes

⚠️ **This setup is for development only!**
- Default passwords are used
- Debug mode is enabled
- Security plugins are disabled
- Do not use in production

## 📝 License

MIT License - feel free to use this for your projects!

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.

## 📞 Support

Create an issue on GitHub for bugs or feature requests.

---

Made with ❤️ for WordPress developers who need quick staging environments.