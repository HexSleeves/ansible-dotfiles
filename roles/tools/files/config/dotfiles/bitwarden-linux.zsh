# Bitwarden CLI helper functions for Linux
# Manages authentication and session persistence via pass (GPG password manager)

# Only load on Linux
[[ "$OSTYPE" == linux* ]] || return 0

# Check if bw is installed
command -v bw >/dev/null 2>&1 || return 0

# Check if pass is installed
command -v pass >/dev/null 2>&1 || {
    echo "pass not installed. Run 'sudo apt install pass' or equivalent." >&2
    return 0
}

# Helper: Get secret from pass
_bw_pass_get() {
    local path="$1"
    pass show "bitwarden/$path" 2>/dev/null
}

# Helper: Set secret in pass
_bw_pass_set() {
    local path="$1"
    local secret="$2"
    # Use echo to pipe secret to pass insert
    echo "$secret" | pass insert -f "bitwarden/$path" 2>/dev/null
}

# Helper: Delete secret from pass
_bw_pass_delete() {
    local path="$1"
    pass rm -f "bitwarden/$path" 2>/dev/null || true
}

# Setup Bitwarden API credentials interactively
bw-setup() {
    echo "Bitwarden API Key Setup"
    echo "======================="
    echo ""
    echo "Get your API key from: https://vault.bitwarden.com/#/settings/security/security-keys"
    echo ""

    # Check if pass is initialized
    if [[ ! -d "$HOME/.password-store" ]]; then
        echo "Error: pass is not initialized."
        echo "Run 'pass init <your-gpg-key-id>' first."
        return 1
    fi

    read -r "client_id?Enter your Bitwarden Client ID: "
    read -rs "client_secret?Enter your Bitwarden Client Secret: "
    echo ""

    if [[ -n "$client_id" ]] && [[ -n "$client_secret" ]]; then
        _bw_pass_set "BW_CLIENTID" "$client_id"
        _bw_pass_set "BW_CLIENTSECRET" "$client_secret"
        echo "API credentials stored in pass."
        echo ""
        echo "Now run 'bw-login' to authenticate."
    else
        echo "Setup cancelled."
        return 1
    fi
}

# Login to Bitwarden using API key from pass
bw-login() {
    local client_id client_secret

    client_id=$(_bw_pass_get "BW_CLIENTID")
    client_secret=$(_bw_pass_get "BW_CLIENTSECRET")

    if [[ -z "$client_id" ]] || [[ -z "$client_secret" ]]; then
        echo "API credentials not found in pass. Run 'bw-setup' first."
        return 1
    fi

    export BW_CLIENTID="$client_id"
    export BW_CLIENTSECRET="$client_secret"

    local status
    status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")

    if [[ "$status" == "unauthenticated" ]]; then
        echo "Logging in to Bitwarden..."
        if bw login --apikey; then
            echo "Login successful. Run 'bw-unlock' to unlock your vault."
        else
            echo "Login failed."
            return 1
        fi
    else
        echo "Already logged in. Status: $status"
        if [[ "$status" == "locked" ]]; then
            echo "Run 'bw-unlock' to unlock your vault."
        fi
    fi
}

# Unlock Bitwarden vault and store session in pass
bw-unlock() {
    local client_id client_secret session

    # Load API credentials
    client_id=$(_bw_pass_get "BW_CLIENTID")
    client_secret=$(_bw_pass_get "BW_CLIENTSECRET")

    if [[ -n "$client_id" ]] && [[ -n "$client_secret" ]]; then
        export BW_CLIENTID="$client_id"
        export BW_CLIENTSECRET="$client_secret"
    fi

    # Check status
    local status
    status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")

    if [[ "$status" == "unauthenticated" ]]; then
        echo "Not logged in. Running login first..."
        bw-login || return 1
    fi

    if [[ "$status" == "unlocked" ]]; then
        echo "Vault already unlocked."
        return 0
    fi

    echo "Unlocking Bitwarden vault..."
    session=$(bw unlock --raw 2>/dev/null)

    if [[ -n "$session" ]]; then
        export BW_SESSION="$session"
        _bw_pass_set "BW_SESSION" "$session"
        echo "Vault unlocked. Session stored in pass."
        bw sync >/dev/null 2>&1 && echo "Vault synced."
    else
        echo "Failed to unlock vault."
        return 1
    fi
}

# Lock Bitwarden vault and clear session
bw-lock() {
    bw lock >/dev/null 2>&1
    unset BW_SESSION
    _bw_pass_delete "BW_SESSION"
    echo "Bitwarden vault locked. Session cleared."
}

# Show Bitwarden status
bw-status() {
    local client_id session status_json status email

    client_id=$(_bw_pass_get "BW_CLIENTID")
    session=$(_bw_pass_get "BW_SESSION")

    echo "Bitwarden Status"
    echo "================"

    # Check API credentials
    if [[ -n "$client_id" ]]; then
        echo "API Key:     Configured (in pass)"
    else
        echo "API Key:     Not configured (run 'bw-setup')"
    fi

    # Check session
    if [[ -n "$session" ]]; then
        echo "Session:     Stored in pass"
    else
        echo "Session:     Not stored"
    fi

    # Check BW_SESSION env var
    if [[ -n "$BW_SESSION" ]]; then
        echo "BW_SESSION:  Set in environment"
    else
        echo "BW_SESSION:  Not set"
    fi

    # Get actual status from bw
    echo ""
    status_json=$(bw status 2>/dev/null || echo '{"status":"error"}')
    status=$(echo "$status_json" | jq -r '.status' 2>/dev/null || echo "error")
    email=$(echo "$status_json" | jq -r '.userEmail // empty' 2>/dev/null)

    echo "Vault Status: $status"
    [[ -n "$email" ]] && echo "User Email:   $email"
}

# Initialize Bitwarden session from pass (called on shell startup)
bw-init() {
    local session client_id client_secret

    # Load session from pass
    session=$(_bw_pass_get "BW_SESSION")

    if [[ -n "$session" ]]; then
        export BW_SESSION="$session"

        # Verify session is still valid
        local status
        status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "error")

        if [[ "$status" == "unlocked" ]]; then
            # Session is valid
            return 0
        elif [[ "$status" == "locked" ]]; then
            # Session expired, clear it
            unset BW_SESSION
            _bw_pass_delete "BW_SESSION"
        fi
    fi

    # Load API credentials for potential login
    client_id=$(_bw_pass_get "BW_CLIENTID")
    client_secret=$(_bw_pass_get "BW_CLIENTSECRET")

    if [[ -n "$client_id" ]] && [[ -n "$client_secret" ]]; then
        export BW_CLIENTID="$client_id"
        export BW_CLIENTSECRET="$client_secret"
    fi
}

# Auto-initialize on shell startup (silent)
bw-init 2>/dev/null
