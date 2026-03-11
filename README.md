# wso2is-branding-export-tool

## Overview
The export process targets multiple levels of branding within an instance:
* **Global Level (carbon.super)**
* **Org Level**
* **Application Level**

### Target Entities
* **Super tenant** `carbon.super`
* **Sub Organizations:** `Org1`, `Org2`
* **Applications:**

---

## Phase 1: Global Branding Preferences

### 1.1 Super Tenant Branding
Retrieve the general branding options for the super tenant (`carbon.super`).
`GET '/api/server/v1/branding-preference?type=ORG'`

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

### 1.3 Loop through sub-organizations and retrieve global branding and screen branding
Retrieve the general branding options for sub-organizations: 
`GET '/o/<org-id>/api/server/v1/branding-preference?type=ORG'`

Retrieve screen branding per sub-org and locale
`GET /o/<org-id>/api/server/v1/branding-preference/text?type=ORG&name=WSO2&locale=en-US&screen={screen_name}`

### 1.4 Global Notification Templates (SMS/Email)

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

## Phase 2: Application Level

1. **List Applications:**
   `GET /api/server/v1/applications`

2. **Export App Branding:**
   For each `{app-name}` found in the application list:
   `GET /api/server/v1/branding-preference?type=APP&name={app-name}`


## Phase 3: Import & Promote
Retrieve the previously created artifacts and use the payload information to import and promote branding options to a higher environment.






### How to use
As per the latest version of this script, in order to run and extract the branding information it's necessary to modify the "Configuration" entries at the top of the script. Specifically the BASE_URL, AUTH (Basic at the moment), TENANT_IDS and TENANT_NAMES.
If needed, the export directories can be changed to point somewhere else.






