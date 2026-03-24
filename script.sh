#!/bin/bash

# Configuration
BASE_URL="https://localhost:9445"
SCREENS=("login" "sms-otp" "email-otp" "totp" "push-auth" "sign-up" "password-recovery" "password-reset" "password-reset-success" "email-link-expiry" "username-recovery-claim" "username-recovery-channel-selection" "username-recovery-success" "myaccount" "email-template")
AUTH="Basic YWRtaW46YWRtaW4="
BRANDING_LOCALE="en-US"
TEMPLATE_LOCALES=("en_US")
APPLICATION_PAGE_SIZE=100
# Optional fallback bearer token if Basic auth is not applicable.
# ORG_API_BEARER_TOKEN="bb4c7dfd-8222-3897-8314-11c1720cc68e"
TENANT_APPLICATION_OVERRIDES=()

mkdir -p "exports/carbon.super"

safe_path_component() {
    local value="$1"

    value=$(printf '%s' "$value" | sed 's/[^[:alnum:]._-]/_/g; s/__*/_/g; s/^_//; s/_$//')
    printf '%s' "${value:-item}"
}

urlencode() {
    jq -nr --arg value "$1" '$value|@uri'
}

api_get() {
    local url="$1"

    api_get_with_auth "Authorization: ${AUTH}" "${url}"
}

api_get_with_auth() {
    local auth_header="$1"
    local url="$2"

    curl -k -f -s \
        -H "${auth_header}" \
        -H "accept: application/json" \
        "${url}"
}

encode_base64() {
    printf '%s' "$1" | base64 | tr -d '\n'
}

decode_base64() {
    if base64 --help >/dev/null 2>&1; then
        printf '%s' "$1" | base64 --decode
    else
        printf '%s' "$1" | base64 -D
    fi
}

get_context_auth_header() {
    local tenant_domain="$1"
    local encoded_credentials
    local decoded_credentials
    local username
    local password

    if [ "${tenant_domain}" = "carbon.super" ]; then
        printf 'Authorization: %s' "${AUTH}"
        return
    fi

    if [ "${AUTH#Basic }" != "${AUTH}" ]; then
        encoded_credentials="${AUTH#Basic }"
        decoded_credentials=$(decode_base64 "${encoded_credentials}")
        username="${decoded_credentials%%:*}"
        password="${decoded_credentials#*:}"

        if [ -n "${username}" ] && [ "${password}" != "${decoded_credentials}" ] && [[ "${username}" != *"@"* ]]; then
            printf 'Authorization: Basic %s' "$(encode_base64 "${username}@${tenant_domain}:${password}")"
            return
        fi
    fi

    # if [ -n "${ORG_API_BEARER_TOKEN}" ]; then
    #     printf 'Authorization: Bearer %s' "${ORG_API_BEARER_TOKEN}"
    #     return
    # fi

    printf 'Authorization: %s' "${AUTH}"
}

save_api_response() {
    local url="$1"
    local file_path="$2"
    local label="$3"

    save_api_response_with_auth "Authorization: ${AUTH}" "${url}" "${file_path}" "${label}"
}

save_api_response_with_auth() {
    local auth_header="$1"
    local url="$2"
    local file_path="$3"
    local label="$4"
    local status

    mkdir -p "$(dirname "${file_path}")"

    status=$(curl -k -f -s -o "${file_path}" -w "%{http_code}" \
        -H "${auth_header}" \
        -H "accept: application/json" \
        "${url}")

    if [ "${status}" = "200" ]; then
        echo "[OK] Saved ${label}"
    else
        rm -f "${file_path}"
        echo "[SKIP] ${label} returned ${status:-000} (Not configured or error)"
    fi
}

to_lowercase() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

append_application() {
    local app_id="$1"
    local app_name="$2"
    local i

    [ -z "${app_id}" ] && return

    for i in "${!APPLICATION_IDS[@]}"; do
        if [ "${APPLICATION_IDS[$i]}" = "${app_id}" ]; then
            return
        fi
    done

    APPLICATION_IDS+=("${app_id}")
    APPLICATION_NAMES+=("${app_name}")
}

get_context_dir() {
    local tenant_name="$1"

    printf 'exports/%s' "${tenant_name}"
}

build_context_url() {
    local tenant_name="$1"
    local endpoint="$2"

    if [ "${tenant_name}" = "carbon.super" ]; then
        printf '%s%s' "${BASE_URL}" "${endpoint}"
    else
        printf '%s/t/%s%s' "${BASE_URL}" "${tenant_name}" "${endpoint}"
    fi
}

collect_applications() {
    local tenant_name="$1"
    local tenant_domain="$2"
    local offset=0
    local response
    local app_count
    local total_results
    local auth_header

    APPLICATION_IDS=()
    APPLICATION_NAMES=()
    auth_header=$(get_context_auth_header "${tenant_domain}")

    while true; do
        if ! response=$(api_get_with_auth "${auth_header}" "$(build_context_url "${tenant_domain}" "/api/server/v1/applications?limit=${APPLICATION_PAGE_SIZE}&offset=${offset}")"); then
            if [ "${offset}" -eq 0 ]; then
                echo "[SKIP] Unable to retrieve applications for ${tenant_name}"
            fi
            break
        fi

        app_count=$(echo "${response}" | jq -r 'if type == "array" then length else ((.applications // .items // []) | length) end')

        if [ -z "${app_count}" ] || [ "${app_count}" -eq 0 ]; then
            break
        fi

        while IFS=$'\t' read -r app_id app_name; do
            append_application "${app_id}" "${app_name}"
        done <<EOF
$(echo "${response}" | jq -r 'if type == "array" then .[] else (.applications // .items // [])[] end | [(.id // .applicationId // .appId // ""), (.name // .displayName // "")] | @tsv')
EOF

        total_results=$(echo "${response}" | jq -r 'if type == "object" then (.totalResults // .total // empty) else empty end')

        if [[ "${total_results}" =~ ^[0-9]+$ ]] && [ $((offset + app_count)) -ge "${total_results}" ]; then
            break
        fi

        if [ "${app_count}" -lt "${APPLICATION_PAGE_SIZE}" ]; then
            break
        fi

        offset=$((offset + APPLICATION_PAGE_SIZE))
    done

    echo "[INFO] Found ${#APPLICATION_IDS[@]} applications for ${tenant_name}"
}

export_org_branding() {
    local tenant_name="$1"
    local tenant_domain="$2"
    local context_dir
    local global_file
    local screen
    local screen_file
    local encoded_locale
    local auth_header

    context_dir=$(get_context_dir "${tenant_name}")
    mkdir -p "${context_dir}"
    auth_header=$(get_context_auth_header "${tenant_domain}")

    if [ "${tenant_name}" = "carbon.super" ]; then
        global_file="${context_dir}/global.json"
    else
        global_file="${context_dir}/global_branding_${tenant_name}.json"
    fi

    save_api_response_with_auth "${auth_header}" \
        "$(build_context_url "${tenant_domain}" "/api/server/v1/branding-preference?type=ORG")" \
        "${global_file}" \
        "${global_file}"

    mkdir -p "${context_dir}/screens"
    encoded_locale=$(urlencode "${BRANDING_LOCALE}")

    for screen in "${SCREENS[@]}"; do
        screen_file="${context_dir}/screens/${screen}.json"

        save_api_response_with_auth "${auth_header}" \
            "$(build_context_url "${tenant_domain}" "/api/server/v1/branding-preference?type=ORG&locale=${encoded_locale}&screen=$(urlencode "${screen}")")" \
            "${screen_file}" \
            "${screen_file}"
    done
}

export_application_branding() {
    local tenant_name="$1"
    local tenant_domain="$2"
    local context_dir
    local app_id
    local app_name
    local app_dir
    local i
    local auth_header

    context_dir=$(get_context_dir "${tenant_name}")
    mkdir -p "${context_dir}/applications"
    auth_header=$(get_context_auth_header "${tenant_domain}")

    if [ "${#APPLICATION_IDS[@]}" -eq 0 ]; then
        echo "[SKIP] No applications found for ${tenant_name} application branding export"
        return
    fi

    for i in "${!APPLICATION_IDS[@]}"; do
        app_id="${APPLICATION_IDS[$i]}"
        app_name="${APPLICATION_NAMES[$i]}"
        app_dir="${context_dir}/applications/$(safe_path_component "${app_name}")__$(safe_path_component "${app_id}")"

        save_api_response_with_auth "${auth_header}" \
            "$(build_context_url "${tenant_domain}" "/api/server/v1/branding-preference/resolve?locale=$(urlencode "${BRANDING_LOCALE}")&name=$(urlencode "${app_id}")&type=APP")" \
            "${app_dir}/branding.json" \
            "${app_dir}/branding.json"
    done
}

export_notification_templates() {
    local tenant_name="$1"
    local tenant_domain="$2"
    local channel="$3"
    local context_dir
    local channel_dir
    local template_types_response
    local template_count
    local template_id
    local template_name
    local template_dir
    local locale
    local auth_header

    context_dir=$(get_context_dir "${tenant_name}")
    channel_dir="${context_dir}/notification/${channel}"
    mkdir -p "${channel_dir}"
    auth_header=$(get_context_auth_header "${tenant_domain}")

    if ! template_types_response=$(api_get_with_auth "${auth_header}" "$(build_context_url "${tenant_domain}" "/api/server/v1/notification/${channel}/template-types")"); then
        echo "[SKIP] Unable to retrieve ${channel} template types for ${tenant_name}"
        return
    fi

    printf '%s' "${template_types_response}" > "${channel_dir}/template-types.json"
    echo "[OK] Saved ${channel_dir}/template-types.json"

    template_count=$(echo "${template_types_response}" | jq -r 'if type == "array" then length else ((.templateTypes // []) | length) end')

    if [ -z "${template_count}" ] || [ "${template_count}" -eq 0 ]; then
        echo "[SKIP] No ${channel} template types found for ${tenant_name}"
        return
    fi

    while IFS=$'\t' read -r template_id template_name; do
        [ -z "${template_id}" ] && continue

        template_dir="${channel_dir}/template-types/$(safe_path_component "${template_name}")__$(safe_path_component "${template_id}")"

        save_api_response_with_auth "${auth_header}" \
            "$(build_context_url "${tenant_domain}" "/api/server/v1/notification/${channel}/template-types/$(urlencode "${template_id}")")" \
            "${template_dir}/metadata.json" \
            "${template_dir}/metadata.json"

        for locale in "${TEMPLATE_LOCALES[@]}"; do
            save_api_response_with_auth "${auth_header}" \
                "$(build_context_url "${tenant_domain}" "/api/server/v1/notification/${channel}/template-types/$(urlencode "${template_id}")/org-templates/$(urlencode "${locale}")")" \
                "${template_dir}/org-templates/${locale}.json" \
                "${template_dir}/org-templates/${locale}.json"

            save_api_response_with_auth "${auth_header}" \
                "$(build_context_url "${tenant_domain}" "/api/server/v1/notification/${channel}/template-types/$(urlencode "${template_id}")/system-templates/$(urlencode "${locale}")")" \
                "${template_dir}/system-templates/${locale}.json" \
                "${template_dir}/system-templates/${locale}.json"
        done
    done <<EOF
$(echo "${template_types_response}" | jq -r 'if type == "array" then .[] else (.templateTypes // [])[] end | [(.id // ""), (.displayName // .name // .type // "")] | @tsv')
EOF
}

# --- Retrieve tenant names ---
TENANT_NAMES=()
TENANT_DOMAINS=()
TENANT_IDS=()
if ! TENANT_LIST_RESULTS=$(api_get "${BASE_URL}/api/server/v1/tenants"); then
    echo "[SKIP] Unable to retrieve tenant names"
    TENANT_LIST_RESULTS='{"tenants":[]}'
fi

while IFS=$'\t' read -r tenant_name tenant_domain tenant_id; do
    [ -z "${tenant_name}" ] && continue
    TENANT_NAMES+=("${tenant_name}")
    TENANT_DOMAINS+=("${tenant_domain}")
    TENANT_IDS+=("${tenant_id}")
done <<EOF
$(echo "${TENANT_LIST_RESULTS}" | jq -r '.tenants[] | [(.name // .displayName // .tenantDomain // .domain // ""), (.domain // .tenantDomain // ((.name // .displayName // "") | ascii_downcase)), (.id // .tenantId // .organizationId // .uuid // "")] | @tsv')
EOF
# --- END Retrieve tenant names ---

# --- Retrieve email template types IDs and names ---
EMAIL_TEMPLATE_TYPES_IDS=()
EMAIL_TEMPLATE_TYPES_NAMES=()
if ! ROOT_EMAIL_TEMPLATE_TYPES=$(api_get "${BASE_URL}/api/server/v1/notification/email/template-types"); then
    echo "[SKIP] Unable to retrieve email template type definitions"
    ROOT_EMAIL_TEMPLATE_TYPES='[]'
fi

while read -r line; do
    [ -n "${line}" ] && EMAIL_TEMPLATE_TYPES_IDS+=("${line}")
done <<EOF
$(echo "${ROOT_EMAIL_TEMPLATE_TYPES}" | jq -r '.[].id')
EOF

while read -r line; do
    [ -n "${line}" ] && EMAIL_TEMPLATE_TYPES_NAMES+=("${line}")
done <<EOF
$(echo "${ROOT_EMAIL_TEMPLATE_TYPES}" | jq -r '.[] | (.displayName // .name // .type // empty)')
EOF
# --- END Retrieve email template types IDs and names ---

# --- Retrieve SMS template types IDs and names ---
SMS_TEMPLATE_TYPES_IDS=()
SMS_TEMPLATE_TYPES_NAMES=()
if ! ROOT_SMS_TEMPLATE_TYPES=$(api_get "${BASE_URL}/api/server/v1/notification/sms/template-types"); then
    echo "[SKIP] Unable to retrieve SMS template type definitions"
    ROOT_SMS_TEMPLATE_TYPES='[]'
fi

while read -r line; do
    [ -n "${line}" ] && SMS_TEMPLATE_TYPES_IDS+=("${line}")
done <<EOF
$(echo "${ROOT_SMS_TEMPLATE_TYPES}" | jq -r '.[].id')
EOF

while read -r line; do
    [ -n "${line}" ] && SMS_TEMPLATE_TYPES_NAMES+=("${line}")
done <<EOF
$(echo "${ROOT_SMS_TEMPLATE_TYPES}" | jq -r '.[] | (.displayName // .name // .type // empty)')
EOF
# --- END Retrieve SMS template types IDs and names ---

# --- Existing org-level branding export flow ---
export_org_branding "carbon.super" "carbon.super"

for i in "${!TENANT_NAMES[@]}"; do
    export_org_branding "${TENANT_NAMES[$i]}" "${TENANT_DOMAINS[$i]}"
done
# --- END Existing org-level branding export flow ---

# --- Application-specific branding + notification templates ---
collect_applications "carbon.super" "carbon.super"
export_application_branding "carbon.super" "carbon.super"
export_notification_templates "carbon.super" "carbon.super" "email"
export_notification_templates "carbon.super" "carbon.super" "sms"

for i in "${!TENANT_NAMES[@]}"; do
    collect_applications "${TENANT_NAMES[$i]}" "${TENANT_DOMAINS[$i]}"
    export_application_branding "${TENANT_NAMES[$i]}" "${TENANT_DOMAINS[$i]}"
    export_notification_templates "${TENANT_NAMES[$i]}" "${TENANT_DOMAINS[$i]}" "email"
    export_notification_templates "${TENANT_NAMES[$i]}" "${TENANT_DOMAINS[$i]}" "sms"
done
# --- END Application-specific branding + notification templates ---
