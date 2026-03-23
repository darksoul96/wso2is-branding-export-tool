#!/bin/bash

# Configuration
BASE_URL="https://localhost:9445"
SCREENS=("login" "sms-otp" "email-otp" "totp" "push-auth" "sign-up" "password-recovery" "password-reset" "password-reset-success" "email-link-expiry" "username-recovery-claim" "username-recovery-channel-selection" "username-recovery-success" "myaccount" "email-template")
AUTH="Basic YWRtaW46YWRtaW4="
FILE_PATH="exports/carbon.super/global.json"
mkdir -p "exports/carbon.super"

# --- Retrieve tenant names ---
TENANT_NAMES=()
TENANT_LIST_RESULTS=$(curl -k -f -s \
    -H "Authorization: ${AUTH}" \
    -H "accept: application/json" \
    "${BASE_URL}/api/server/v1/tenants")

while read -r line; do
    [ -n "$line" ] && TENANT_NAMES+=("$line")
done <<EOF
$(echo "$TENANT_LIST_RESULTS" | jq -r '.tenants[].name')
EOF
# --- END Retrieve tenant names ---


# --- Retrieve email template types IDs and names ---
EMAIL_TEMPLATE_TYPES_IDS=()
EMAIL_TEMPLATE_TYPES_NAMES=()
EMAIL_TEMPLATE_TYPES=$(curl -k -f -s \
    -H "Authorization: ${AUTH}" \
    -H "accept: application/json" \
    "${BASE_URL}/api/server/v1/notification/email/template-types")

while read -r line; do
    [ -n "$line" ] && EMAIL_TEMPLATE_TYPES_IDS+=("$line")
done <<EOF
$(echo "$EMAIL_TEMPLATE_TYPES" | jq -r '.[].id')
EOF

while read -r line; do
    [ -n "$line" ] && EMAIL_TEMPLATE_TYPES_NAMES+=("$line")
done <<EOF
$(echo "$EMAIL_TEMPLATE_TYPES" | jq -r '.[].displayName')
EOF
# --- END Retrieve email template types IDs and names ---


# --- carbon.super global branding options ---
STATUS=$(curl -k -f -s -o "$FILE_PATH" -w "%{http_code}" \
    -H "Authorization: ${AUTH}" \
    -H "accept: application/json" \
    "${BASE_URL}/api/server/v1/branding-preference?type=ORG")

if [ "$STATUS" -eq 200 ]; then
    echo "[OK] Saved carbon.super/global.json"
else
    rm -f "$FILE_PATH"
    echo "[SKIP] carbon.super/global.json returned ${STATUS} (Not configured or error)"
fi
# --- END carbon.super global branding options ---

# --- carbon.super screen branding ---
mkdir -p "exports/carbon.super/screens"
FILE_PATH="exports/carbon.super/screens"

for SCREEN in "${SCREENS[@]}"; do
    STATUS=$(curl -k -f -s -o "$FILE_PATH/${SCREEN}.json" -w "%{http_code}" \
        -H "Authorization: ${AUTH}" \
        -H "accept: application/json" \
        "${BASE_URL}/api/server/v1/branding-preference?type=ORG&locale=en-US&screen=${SCREEN}")

    if [ "$STATUS" -eq 200 ]; then
        echo "[OK] Saved ${FILE_PATH}/${SCREEN}.json"
    else
        rm -f "$FILE_PATH"
        echo "[SKIP] ${FILE_PATH}/${SCREEN}.json returned ${STATUS} (Not configured or error)"
    fi
done
# --- END carbon.super screen branding ---



# --- Branding options per tenant ---
for i in "${!TENANT_NAMES[@]}"; do
    # --- Global branding per tenant ---
    mkdir -p "exports/${TENANT_NAMES[$i]}"
    FILE_PATH="exports/${TENANT_NAMES[$i]}/global_branding_${TENANT_NAMES[$i]}.json"
    STATUS=$(curl -k -f -s -o "$FILE_PATH" -w "%{http_code}" \
        -H "Authorization: ${AUTH}" \
        -H "accept: application/json" \
        "${BASE_URL}/t/${TENANT_NAMES[$i]}/api/server/v1/branding-preference?type=ORG")

    if [ "$STATUS" -eq 200 ]; then
        echo "[OK] Saved global_branding_${TENANT_NAMES[$i]}.json"
    else
        rm -f "$FILE_PATH"
        echo "[SKIP] global_branding_${TENANT_NAMES[$i]}.json returned ${STATUS} (Not configured or error)"
    fi
    # --- END Global branding per tenant ---

    # --- Branding per screen
    mkdir -p "exports/${TENANT_NAMES[$i]}/screens"
    for SCREEN in "${SCREENS[@]}"; do
        FILE_PATH="exports/${TENANT_NAMES[$i]}/screens/${SCREEN}.json"

        STATUS=$(curl -k -f -s -o "$FILE_PATH" -w "%{http_code}" \
            -H "Authorization: ${AUTH}" \
            -H "accept: application/json" \
            "${BASE_URL}/t/${TENANT_NAMES[$i]}/api/server/v1/branding-preference?type=ORG&locale=en-US&screen=${SCREEN}")

        if [ "$STATUS" -eq 200 ]; then
            echo "[OK] Saved ${TENANT_NAMES[$i]}/screens/${SCREEN}.json"
        else
            rm -f "$FILE_PATH"
            echo "[SKIP] global_branding_${TENANT_NAMES[$i]}.json returned ${STATUS} (Not configured or error)"
        fi
    done
    # --- END Branding per screen ---

done
# --- END Branding options per tenant ---