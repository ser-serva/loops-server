#!/usr/bin/env bash
# loops-server/scripts/dev-mint-token.sh
#
# Mints a new Loops personal-access API token for the dev admin user
# and optionally writes it to looprr/.env.
#
# Requires the dev stack to be running:
#   docker compose -f docker-compose.dev.yml up -d
#
# Usage:
#   ./scripts/dev-mint-token.sh [--write-looprr-env]
#
#   --write-looprr-env   Automatically update LOOPS_API_TOKEN in
#                        ../looprr/.env (relative to loops-server/).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

DC="docker compose -f docker-compose.dev.yml"
APP="$DC exec -T loops"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
step() { echo -e "\n${CYAN}▶ $*${NC}"; }
ok()   { echo -e "${GREEN}✓ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }

# ── Guard ─────────────────────────────────────────────────────────────────────
if ! $DC ps loops 2>/dev/null | grep -q "running\|Up"; then
    echo "✗ loops_dev_app is not running. Start with: docker compose -f docker-compose.dev.yml up -d"
    exit 1
fi

ADMIN_EMAIL="${DEV_ADMIN_EMAIL:-admin@localhost}"

step "Minting personal-access token for ${ADMIN_EMAIL}..."

TOKEN=$($APP php artisan tinker --execute="
\$user = \App\Models\User::where('email', '${ADMIN_EMAIL}')->firstOrFail();
\$token = \$user->createToken('looprr-dev', ['video:create', 'video:read', 'user:read']);
echo \$token->accessToken;
" 2>/dev/null | tail -1)

if [[ -z "$TOKEN" || "$TOKEN" == *"Error"* ]]; then
    echo "✗ Failed to mint token. Make sure migrations and passport:keys have been run."
    echo "  Run ./scripts/dev-reset.sh first."
    exit 1
fi

echo ""
ok "Token minted successfully"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "LOOPS_API_TOKEN=${TOKEN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Optional: write to looprr/.env ────────────────────────────────────────────
LOOPRR_ENV="$(dirname "$SCRIPT_DIR")/looprr/.env"

if [[ "${1:-}" == "--write-looprr-env" ]]; then
    if [[ ! -f "$LOOPRR_ENV" ]]; then
        warn "looprr/.env not found at $LOOPRR_ENV — token not written"
    else
        # Replace or append LOOPS_API_TOKEN
        if grep -q '^LOOPS_API_TOKEN=' "$LOOPRR_ENV"; then
            sed -i "s|^LOOPS_API_TOKEN=.*|LOOPS_API_TOKEN=${TOKEN}|" "$LOOPRR_ENV"
        else
            echo "LOOPS_API_TOKEN=${TOKEN}" >> "$LOOPRR_ENV"
        fi
        ok "LOOPS_API_TOKEN written to ${LOOPRR_ENV}"
        echo ""
        warn "Restart looprr backend to pick up the new token:"
        echo "  docker compose -f docker-compose.dev.yml restart backend  (in looprr/)"
    fi
else
    echo "To write this token to looprr/.env automatically, run:"
    echo "  ./scripts/dev-mint-token.sh --write-looprr-env"
    echo ""
    echo "Or set it manually:"
    echo "  # in looprr/.env:"
    echo "  LOOPS_API_TOKEN=${TOKEN}"
fi
