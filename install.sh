#!/bin/bash

# KILLER NODES Installation Script
# This script will install KILLER NODES on a fresh Ubuntu server

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[INFO]$(date '+%Y-%m-%d %H:%M:%S')${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]$(date '+%Y-%m-%d %H:%M:%S')${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]$(date '+%Y-%m-%d %H:%M:%S')${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]$(date '+%Y-%m-%d %H:%M:%S')${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   warn "This script should not be run as root. Using sudo where needed."
fi

# Variables
DOMAIN=""
EMAIL=""
DB_ROOT_PASSWORD=""
DB_PASSWORD=""
REDIS_PASSWORD=""

# Function to generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-20
}

# Welcome message
echo -e "${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                              🚀 KILLER NODES 🚀                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  Professional Game Server Management Dashboard                               ║
║  Installation Script                                                        ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if system meets requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check OS
    if ! [ -f /etc/os-release ]; then
        error "Cannot determine OS version. Only Ubuntu 22.04/24.04 LTS supported."
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$NAME" != "Ubuntu" ]]; then
        error "Only Ubuntu is supported. Current OS: $NAME"
        exit 1
    fi
    
    if [[ "$VERSION_ID" != "22.04" ]] && [[ "$VERSION_ID" != "24.04" ]]; then
        warn "This script is tested on Ubuntu 22.04/24.04 LTS. You are running $VERSION_ID"
    fi
    
    # Check RAM
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $RAM_GB -lt 2 ]]; then
        error "Minimum 2GB RAM required. Current: ${RAM_GB}GB"
        exit 1
    fi
    
    success "System requirements met"
}

# Prompt for domain
get_domain() {
    while [[ -z "$DOMAIN" ]]; do
        read -p "Enter your domain name (e.g., killernodes.com): " DOMAIN
        if [[ -z "$DOMAIN" ]]; then
            warn "Domain name is required!"
        fi
    done
}

# Prompt for email
get_email() {
    while [[ -z "$EMAIL" ]]; do
        read -p "Enter your email for SSL certificate (e.g., admin@killernodes.com): " EMAIL
        if [[ -z "$EMAIL" ]]; then
            warn "Email is required for SSL certificate!"
        fi
    done
}

# Generate passwords
generate_passwords() {
    DB_ROOT_PASSWORD=$(generate_password)
    DB_PASSWORD=$(generate_password)
    REDIS_PASSWORD=$(generate_password)
    
    log "Generated secure passwords"
}

# Install system dependencies
install_dependencies() {
    log "Installing system dependencies..."
    
    sudo apt update
    sudo apt install -y \
        curl \
        git \
        wget \
        unzip \
        nginx \
        apache2-utils \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        certbot \
        python3-certbot-nginx \
        mariadb-server \
        redis-server \
        php8.3 \
        php8.3-cli \
        php8.3-common \
        php8.3-mysql \
        php8.3-zip \
        php8.3-gd \
        php8.3-mbstring \
        php8.3-curl \
        php8.3-xml \
        php8.3-bcmath \
        php8.3-json \
        php8.3-ldap \
        php8.3-imagick \
        php8.3-intl \
        php8.3-gmp \
        php8.3-dev \
        supervisor \
        cron \
        jq \
        nodejs \
        npm \
        yarn
    
    # Install Docker
    if ! command -v docker &> /dev/null; then
        log "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        sudo usermod -aG docker $USER
    fi
    
    # Install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    
    success "Dependencies installed"
}

# Clone KILLER NODES repository
clone_repository() {
    log "Cloning KILLER NODES repository..."
    
    if [[ -d "KILLER_NODES" ]]; then
        warn "KILLER NODES directory already exists. Removing..."
        rm -rf KILLER_NODES
    fi
    
    git clone https://github.com/businesspluginshub-creator/KILLERTHEME.git KILLER_NODES
    cd KILLER_NODES
    
    success "Repository cloned"
}

# Configure environment
configure_environment() {
    log "Configuring environment..."
    
    # Copy example env file
    cp .env.example .env
    
    # Update environment variables
    sed -i "s/APP_URL=.*/APP_URL=$DOMAIN/" .env
    sed -i "s/MARIADB_ROOT_PASSWORD=.*/MARIADB_ROOT_PASSWORD=$DB_ROOT_PASSWORD/" .env
    sed -i "s/MARIADB_DATABASE=.*/MARIADB_DATABASE=killernodes_v3/" .env
    sed -i "s/MARIADB_USER=.*/MARIADB_USER=killernodes_v3/" .env
    sed -i "s/MARIADB_PASSWORD=.*/MARIADB_PASSWORD=$DB_PASSWORD/" .env
    sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=$REDIS_PASSWORD/" .env
    
    success "Environment configured"
}

# Build applications
build_applications() {
    log "Building applications..."
    
    # Build frontend
    log "Building frontend..."
    cd frontend
    yarn install
    yarn build
    cd ..
    
    # Build backend
    log "Building backend..."
    cd backend
    composer install
    cd ..
    
    success "Applications built"
}

# Start services
start_services() {
    log "Starting services..."
    
    # Start Docker services
    docker-compose up -d
    
    # Wait for services to be ready
    log "Waiting for services to start..."
    sleep 30
    
    # Run initial setup
    log "Running initial setup..."
    php killernodes migrate
    php killernodes makeAdmin
    
    success "Services started"
}

# Setup SSL
setup_ssl() {
    log "Setting up SSL certificate..."
    
    # Request SSL certificate
    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL
    
    # Reload nginx
    sudo systemctl reload nginx
    
    success "SSL certificate configured"
}

# Setup cron jobs
setup_cron() {
    log "Setting up cron jobs..."
    
    # Add cron job for KILLER NODES
    (crontab -l 2>/dev/null; echo "* * * * * /usr/bin/php /var/www/killernodes-v3/backend/killernodes cron:run >> /dev/null 2>&1") | crontab -
    
    success "Cron jobs configured"
}

# Create backup script
create_backup_script() {
    log "Creating backup script..."
    
    BACKUP_SCRIPT="/usr/local/bin/killernodes-backup.sh"
    cat > $BACKUP_SCRIPT << EOF
#!/bin/bash
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/killernodes"
mkdir -p \$BACKUP_DIR

# Backup database
mysqldump -u killernodes_v3 -p'$DB_PASSWORD' killernodes_v3 > \$BACKUP_DIR/database_\$DATE.sql

# Backup configuration
tar -czf \$BACKUP_DIR/config_\$DATE.tar.gz /var/www/killernodes-v3/backend/.env /var/www/killernodes-v3/backend/storage/

echo "Backup created: \$BACKUP_DIR/\$DATE"
EOF
    
    chmod +x $BACKUP_SCRIPT
    
    # Add to cron
    (crontab -l 2>/dev/null; echo "0 2 * * * $BACKUP_SCRIPT") | crontab -
    
    success "Backup script created"
}

# Display completion message
display_completion_message() {
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                           🎉 INSTALLATION COMPLETE 🎉                         ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}║  Your KILLER NODES installation is ready!                                    ║${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}║  Access URL: https://$DOMAIN                                               ║${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}║  Important Information:                                                      ║${NC}"
    echo -e "${GREEN}║  - Database Root Password: $DB_ROOT_PASSWORD                    ║${NC}"
    echo -e "${GREEN}║  - Database Password: $DB_PASSWORD                                ║${NC}"
    echo -e "${GREEN}║  - Redis Password: $REDIS_PASSWORD                                ║${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}║  Useful Commands:                                                            ║${NC}"
    echo -e "${GREEN}║  - View logs: docker-compose logs -f                                       ║${NC}"
    echo -e "${GREEN}║  - Restart: docker-compose restart                                         ║${NC}"
    echo -e "${GREEN}║  - Backup: $BACKUP_SCRIPT                                    ║${NC}"
    echo -e "${GREEN}║                                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "\n${YELLOW}Please note down your passwords and store them securely!${NC}"
}

# Main execution
main() {
    log "Starting KILLER NODES installation..."
    
    check_requirements
    get_domain
    get_email
    generate_passwords
    install_dependencies
    clone_repository
    configure_environment
    build_applications
    start_services
    setup_ssl
    setup_cron
    create_backup_script
    display_completion_message
    
    success "KILLER NODES installation completed successfully!"
}

# Run main function
main "$@"