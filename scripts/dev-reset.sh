#!/usr/bin/env bash
# loops-server/scripts/dev-reset.sh
#
# Full dev environment reset:
#   1. Drop + recreate the dev MySQL database
#   2. Clear Redis caches and sessions
#   3. Run database migrations fresh
#   4. Generate Laravel Passport keys
#   5. Create / ensure a Passport personal-access OAuth client exists
#   6. Seed a dev admin user (idempotent — skips if user already exists)
#   7. Print a fresh API token for looprr
#
# Requires the dev stack to be running:
#   docker compose -f docker-compose.dev.yml up -d
#
# Usage:
#   ./scripts/dev-reset.sh [--token-only]
#
#   --token-only   Skip DB reset; just generate a new API token and print it.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

DC="docker compose -f docker-compose.dev.yml --env-file .env.dev"
APP="$DC exec -T loops"

# Colours
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
step()  { echo -e "\n${CYAN}▶ $*${NC}"; }
ok()    { echo -e "${GREEN}✓ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠ $*${NC}"; }

# ── Guard: stack must be running ──────────────────────────────────────────────
if ! $DC ps loops 2>/dev/null | grep -q "running\|Up"; then
    echo -e "${RED}✗ loops_dev_app is not running. Start it first:${NC}"
    echo "  docker compose -f docker-compose.dev.yml --env-file .env.dev up -d"
    exit 1
fi

# ── Token-only mode ───────────────────────────────────────────────────────────
if [[ "${1:-}" == "--token-only" ]]; then
    step "Minting a new Loops API token for looprr..."
    exec "$SCRIPT_DIR/dev-mint-token.sh"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FULL RESET
# ═══════════════════════════════════════════════════════════════════════════════

step "Fixing node_modules + vendor volume ownership for www-data..."
# Named Docker volumes are populated from the image as root.
# www-data needs write access for npm/composer operations.
$DC exec -T -u root loops chown -R www-data:www-data \
    /var/www/html/node_modules \
    /var/www/html/vendor 2>/dev/null || true
ok "Ownership fixed"

step "Building frontend assets (Vite)..."
$APP npm run build 2>&1 | tail -3
ok "Frontend built → public/build/"

step "Clearing Laravel caches..."
$APP php artisan config:clear  || true
$APP php artisan route:clear   || true
$APP php artisan view:clear    || true
$APP php artisan cache:clear   || true
ok  "Caches cleared"

step "Dropping and recreating dev database..."
# Use root credentials from .env.dev
DB_DATABASE=$(grep '^DB_DATABASE=' .env.dev | cut -d= -f2 | tr -d '"' | tr -d "'")
DB_USERNAME=$(grep '^DB_USERNAME=' .env.dev | cut -d= -f2 | tr -d '"' | tr -d "'")
DB_PASSWORD=$(grep '^DB_PASSWORD=' .env.dev | cut -d= -f2 | tr -d '"' | tr -d "'")
DB_ROOT_PASSWORD=$(grep '^DB_ROOT_PASSWORD=' .env.dev | cut -d= -f2 | tr -d '"' | tr -d "'")

docker compose -f docker-compose.dev.yml --env-file .env.dev exec -T db \
    mysql -u root -p"${DB_ROOT_PASSWORD}" -e \
    "DROP DATABASE IF EXISTS \`${DB_DATABASE}\`; CREATE DATABASE \`${DB_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; GRANT ALL PRIVILEGES ON \`${DB_DATABASE}\`.* TO '${DB_USERNAME}'@'%'; FLUSH PRIVILEGES;"
ok "Database '${DB_DATABASE}' recreated"

step "Running fresh migrations..."
$APP php artisan migrate --force
ok "Migrations complete"

step "Generating Laravel application key (if missing)..."
CURRENT_KEY=$(grep '^APP_KEY=' .env.dev | cut -d= -f2 | tr -d '"' | tr -d "'" | xargs)
if [[ -z "$CURRENT_KEY" ]]; then
    GENERATED_KEY=$($APP php artisan key:generate --show --no-interaction)
    # Write key back into .env.dev
    sed -i "s|^APP_KEY=.*|APP_KEY=${GENERATED_KEY}|" .env.dev
    ok "App key generated and written to .env.dev"
else
    ok "App key already present"
fi

step "Generating Passport OAuth keys..."
$APP php artisan passport:keys --force
ok "Passport keys generated"

step "Creating Passport personal-access OAuth client (if missing)..."
# Check if a personal_access client already exists
CLIENT_COUNT=$($APP php artisan tinker --execute="echo \App\Models\Passport\Client::where('personal_access_client', true)->count();" 2>/dev/null | tail -1 || echo "0")
if [[ "$CLIENT_COUNT" == "0" ]]; then
    $APP php artisan passport:client --personal --name="Dev Personal Access" --no-interaction
    ok "Passport personal-access client created"
else
    ok "Passport personal-access client already exists"
fi

step "Creating dev admin user..."
ADMIN_EMAIL="${DEV_ADMIN_EMAIL:-admin@localhost}"
ADMIN_PASSWORD="${DEV_ADMIN_PASSWORD:-password}"
ADMIN_NAME="${DEV_ADMIN_NAME:-Dev Admin}"

$APP php artisan tinker --execute="
\$user = \App\Models\User::firstOrCreate(
    ['email' => '${ADMIN_EMAIL}'],
    [
        'name'              => '${ADMIN_NAME}',
        'username'          => 'admin',
        'password'          => bcrypt('${ADMIN_PASSWORD}'),
        'email_verified_at' => now(),
        'is_admin'          => true,
    ]
);
if (\$user->wasRecentlyCreated) {
    echo 'Admin user created: ' . \$user->email;
} else {
    \$user->update(['is_admin' => true, 'password' => bcrypt('${ADMIN_PASSWORD}')]);
    echo 'Admin user updated: ' . \$user->email;
}
" 2>/dev/null | tail -1
ok "Admin: ${ADMIN_EMAIL} / ${ADMIN_PASSWORD}"

step "Minting looprr API token..."
exec "$SCRIPT_DIR/dev-mint-token.sh"
