#!/bin/bash

# RemoteDeploy CLI Deployment Script
# Allows command-line deployment using RemoteDeploy API

set -e

# Default configuration
API_URL="http://localhost:3001/api"
CONFIG_FILE=""
SERVER_NAME=""
REPOSITORY_URL=""
BRANCH="main"
DEPLOY_PATH=""
BACKUP=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_help() {
    cat << EOF
RemoteDeploy CLI Tool

Usage: $0 [OPTIONS]

Options:
    -c, --config FILE       JSON configuration file
    -s, --server NAME       Server name (must exist in RemoteDeploy)
    -r, --repo URL          Repository URL
    -b, --branch BRANCH     Git branch (default: main)
    -p, --path PATH         Deployment path on server
    -n, --no-backup         Skip backup creation
    -u, --url URL           API URL (default: http://localhost:3001/api)
    -h, --help              Show this help message

Examples:
    # Deploy using configuration file
    $0 -c deploy-config.json

    # Quick deployment
    $0 -s "web-server" -r "https://github.com/user/repo.git" -p "/var/www/html"

    # Deploy specific branch without backup
    $0 -s "staging" -r "https://github.com/user/repo.git" -b "develop" -n
EOF
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -s|--server)
            SERVER_NAME="$2"
            shift 2
            ;;
        -r|--repo)
            REPOSITORY_URL="$2"
            shift 2
            ;;
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -p|--path)
            DEPLOY_PATH="$2"
            shift 2
            ;;
        -n|--no-backup)
            BACKUP=false
            shift
            ;;
        -u|--url)
            API_URL="$2"
            shift 2
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

# Check if curl is available
if ! command -v curl &> /dev/null; then
    print_error "curl is required but not installed"
    exit 1
fi

# Check if jq is available (optional but recommended)
if ! command -v jq &> /dev/null; then
    print_warning "jq is recommended for better JSON handling"
fi

# Function to make API requests
api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    if [ -n "$data" ]; then
        curl -s -X "$method" \
             -H "Content-Type: application/json" \
             -d "$data" \
             "$API_URL$endpoint"
    else
        curl -s -X "$method" \
             -H "Content-Type: application/json" \
             "$API_URL$endpoint"
    fi
}

# Get server ID by name
get_server_id() {
    local server_name="$1"
    local servers_response
    
    print_status "Looking up server: $server_name"
    servers_response=$(api_request "GET" "/servers")
    
    if command -v jq &> /dev/null; then
        echo "$servers_response" | jq -r ".[] | select(.name == \"$server_name\") | .id"
    else
        # Fallback without jq (basic parsing)
        echo "$servers_response" | grep -o "\"id\":\"[^\"]*\"" | grep -A1 "\"name\":\"$server_name\"" | head -1 | cut -d'"' -f4
    fi
}

# Deploy using configuration file
deploy_with_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    print_status "Deploying using configuration file: $config_file"
    local config_data=$(cat "$config_file")
    
    local response=$(api_request "POST" "/deploy" "$config_data")
    
    if command -v jq &> /dev/null; then
        local success=$(echo "$response" | jq -r '.success // false')
        local deployment_id=$(echo "$response" | jq -r '.deploymentId // ""')
        
        if [ "$success" = "true" ]; then
            print_success "Deployment started successfully"
            print_status "Deployment ID: $deployment_id"
            monitor_deployment "$deployment_id"
        else
            local error=$(echo "$response" | jq -r '.error // "Unknown error"')
            print_error "Deployment failed: $error"
            exit 1
        fi
    else
        echo "$response"
    fi
}

# Deploy using command line parameters
deploy_with_params() {
    local server_id=$(get_server_id "$SERVER_NAME")
    
    if [ -z "$server_id" ]; then
        print_error "Server not found: $SERVER_NAME"
        exit 1
    fi
    
    print_status "Found server ID: $server_id"
    
    # Create deployment configuration
    local deploy_config=$(cat << EOF
{
    "serverId": "$server_id",
    "repositoryUrl": "$REPOSITORY_URL",
    "branch": "$BRANCH",
    "deployPath": "$DEPLOY_PATH",
    "backupBeforeDeploy": $BACKUP,
    "preDeployCommands": [],
    "postDeployCommands": [],
    "restartServices": [],
    "environmentVariables": {},
    "excludePatterns": [".git", "node_modules", ".env"]
}
EOF
    )
    
    print_status "Starting deployment..."
    local response=$(api_request "POST" "/deploy" "$deploy_config")
    
    if command -v jq &> /dev/null; then
        local success=$(echo "$response" | jq -r '.success // false')
        local deployment_id=$(echo "$response" | jq -r '.deploymentId // ""')
        
        if [ "$success" = "true" ]; then
            print_success "Deployment started successfully"
            print_status "Deployment ID: $deployment_id"
            monitor_deployment "$deployment_id"
        else
            local error=$(echo "$response" | jq -r '.error // "Unknown error"')
            print_error "Deployment failed: $error"
            exit 1
        fi
    else
        echo "$response"
    fi
}

# Monitor deployment progress
monitor_deployment() {
    local deployment_id="$1"
    
    print_status "Monitoring deployment progress..."
    
    while true; do
        local deployments=$(api_request "GET" "/deployments")
        
        if command -v jq &> /dev/null; then
            local deployment=$(echo "$deployments" | jq -r ".[] | select(.id == \"$deployment_id\")")
            local status=$(echo "$deployment" | jq -r '.status')
            local logs=$(echo "$deployment" | jq -r '.logs[]? // empty')
            
            case "$status" in
                "success")
                    print_success "Deployment completed successfully!"
                    if [ -n "$logs" ]; then
                        echo -e "\n${BLUE}Final logs:${NC}"
                        echo "$logs" | tail -5
                    fi
                    exit 0
                    ;;
                "failed")
                    print_error "Deployment failed!"
                    local error=$(echo "$deployment" | jq -r '.error // "Unknown error"')
                    print_error "Error: $error"
                    if [ -n "$logs" ]; then
                        echo -e "\n${RED}Error logs:${NC}"
                        echo "$logs" | tail -10
                    fi
                    exit 1
                    ;;
                "running")
                    echo -n "."
                    ;;
            esac
        fi
        
        sleep 2
    done
}

# Main execution
print_status "RemoteDeploy CLI Tool"

# Check API connectivity
print_status "Checking API connectivity..."
if ! api_request "GET" "/health" > /dev/null; then
    print_error "Cannot connect to RemoteDeploy API at $API_URL"
    print_error "Make sure the RemoteDeploy server is running"
    exit 1
fi
print_success "API connection successful"

# Deploy based on input method
if [ -n "$CONFIG_FILE" ]; then
    deploy_with_config "$CONFIG_FILE"
elif [ -n "$SERVER_NAME" ] && [ -n "$REPOSITORY_URL" ] && [ -n "$DEPLOY_PATH" ]; then
    deploy_with_params
else
    print_error "Insufficient parameters provided"
    print_help
    exit 1
fi