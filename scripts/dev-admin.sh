#!/usr/bin/env bash
# loops-server/scripts/dev-admin.sh
#
# Manage dev admin user: create, update password, promote to admin.
#
# Usage:
#   ./scripts/dev-admin.sh create  [--email EMAIL] [--password PASS] [--name NAME]
#   ./scripts/dev-admin.sh reset   [--email EMAIL] [--password PASS]
#   ./scripts/dev-admin.sh promote [--email EMAIL]
#   ./scripts/dev-admin.sh info    [--email EMAIL]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

DC="docker compose -f docker-compose.dev.yml"
APP="$DC exec -T loops"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
step() { echo -e "\n${CYAN}▶ $*${NC}"; }
ok()   { echo -e "${GREEN}✓ $*${NC}"; }

ACTION="${1:-help}"
EMAIL="${DEV_ADMIN_EMAIL:-admin@localhost}"
PASSWORD="password"
NAME="Dev Admin"

# Parse flags
shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --email)    EMAIL="$2";    shift 2 ;;
        --password) PASSWORD="$2"; shift 2 ;;
        --name)     NAME="$2";     shift 2 ;;
        *) shift ;;
    esac
done

case "$ACTION" in

create)
    step "Creating user ${EMAIL}..."
    $APP php artisan tinker --execute="
\$exists = \App\Models\User::where('email', '${EMAIL}')->exists();
if (\$exists) { echo 'EXISTS'; exit; }
\App\Models\User::create([
    'name'              => '${NAME}',
    'username'          => strtolower(str_replace(' ', '_', '${NAME}')),
    'email'             => '${EMAIL}',
    'password'          => bcrypt('${PASSWORD}'),
    'email_verified_at' => now(),
    'is_admin'          => true,
]);
echo 'CREATED';
" 2>/dev/null | tail -1
    ok "${EMAIL} / ${PASSWORD}"
    ;;

reset)
    step "Resetting password for ${EMAIL}..."
    $APP php artisan tinker --execute="
\$user = \App\Models\User::where('email', '${EMAIL}')->firstOrFail();
\$user->update(['password' => bcrypt('${PASSWORD}')]);
echo 'Password updated for: ' . \$user->email;
" 2>/dev/null | tail -1
    ok "New password: ${PASSWORD}"
    ;;

promote)
    step "Promoting ${EMAIL} to admin..."
    $APP php artisan tinker --execute="
\$user = \App\Models\User::where('email', '${EMAIL}')->firstOrFail();
\$user->update(['is_admin' => true]);
echo 'Promoted: ' . \$user->email;
" 2>/dev/null | tail -1
    ok "Done"
    ;;

info)
    step "User info for ${EMAIL}..."
    $APP php artisan tinker --execute="
\$user = \App\Models\User::where('email', '${EMAIL}')->firstOrFail();
echo json_encode([
    'id'       => \$user->id,
    'email'    => \$user->email,
    'username' => \$user->username,
    'is_admin' => \$user->is_admin,
    'created'  => \$user->created_at,
], JSON_PRETTY_PRINT);
" 2>/dev/null | tail -n +2
    ;;

*)
    echo "Usage:"
    echo "  $0 create  [--email EMAIL] [--password PASS] [--name NAME]"
    echo "  $0 reset   [--email EMAIL] [--password PASS]"
    echo "  $0 promote [--email EMAIL]"
    echo "  $0 info    [--email EMAIL]"
    exit 1
    ;;
esac
