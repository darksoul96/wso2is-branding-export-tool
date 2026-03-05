# wso2is-branding-export-tool

## Overview
The export process targets multiple levels of branding within an instance:
* **Global Level (Root)**
* **Tenant Level**
* **Application Level**

### Target Entities
* **Tenants:** `Org1`, `Org2`
* **Applications:** `openid-app`, `saml-app`, `myaccount`

---

## Phase 1: Global Branding Preferences (Root Level)

### 1.1 Super Tenant Branding
Retrieve the general branding options for the super tenant (`carbon.super`).

```bash
curl --location 'https://localhost:9445/api/server/v1/branding-preference?type=ORG&name=carbon.super' \
--header 'accept: application/json'
```

### 1.2 Global Custom Text (Localization)
Retrieve custom text for specific screens and locales.

**General Pattern:**
`GET /api/server/v1/branding-preference/text?type=ORG&name=WSO2&locale=en-US&screen={screen_name}`

**Key Screens to Export:**
* login
* sms-otp
* email-otp
* totp
* push-auth
* sign-up
* password-recovery
* password-reset
* password-reset-success
* email-link-expiry
* recovery-claim (username-recovery-claim)
* username-recovery-channel-selection
* username-recovery-success
* myaccount
* email-template

### 1.3 Global Notification Templates (SMS/Email)

#### Email Templates
* **List Types:** `GET /api/server/v1/notification/email/template-types`
* **Type Details:** `GET /api/server/v1/notification/email/template-types/{template-type-id}`
* **Organization Templates:** `GET /api/server/v1/notification/email/template-types/{type-id}/org-templates/{locale}`
* **Application Templates:** `GET /api/server/v1/notification/email/template-types/{type-id}/app-templates/{app-id}/{locale}`
* **System Templates:** `GET /api/server/v1/notification/email/template-types/{type-id}/system-templates/{locale}`

#### SMS Templates
* **List Types:** `GET /api/server/v1/notification/sms/template-types`
* **Type Details:** `GET /api/server/v1/notification/sms/template-types/{template-type-id}`
* **Organization Templates:** `GET /api/server/v1/notification/sms/template-types/{type-id}/org-templates/{locale}`
* **Application Templates:** `GET /api/server/v1/notification/sms/template-types/{type-id}/app-templates/{app-id}/{locale}`
* **System Templates:** `GET /api/server/v1/notification/sms/template-types/{type-id}/system-templates/{locale}`

---

## Phase 2: Application Level (Super Tenant)

1. **List Applications:**
   `GET /api/server/v1/applications`

2. **Export App Branding:**
   For each `{app-name}` found in the application list:
   `GET /api/server/v1/branding-preference?type=APP&name={app-name}`

---

## Phase 3: Individual Tenant Loop

Iterate through each tenant domain (e.g., `Org1`, `Org2`) and perform the following:

### 3.1 Tenant Level Branding
* **Branding Preferences:** `GET /api/server/v1/branding-preference?type=ORG&name={tenant-domain}`
* **Custom Text:** `GET /api/server/v1/branding-preference/custom-text?type=ORG&name={tenant-domain}&locale=en-US`

### 3.2 Tenant Notification Templates
Retrieve templates using the tenant-qualified URL:
`GET /t/{tenant-domain}/api/server/v1/notification/...`

### 3.3 Tenant Applications
1. **List Apps for Tenant:**
   `GET /t/{tenant-domain}/api/server/v1/applications`

2. **Export App-Specific Branding:**
   For each application with an explicit preference set:
   `GET /t/{tenant-domain}/api/server/v1/branding-preference?type=APP&name={app-name}`