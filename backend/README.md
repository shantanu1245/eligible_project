# Eligible CRM Backend — Meta Ads & Firebase Bridge

A high-performance Node.js backend providing seamless integration between **Meta Marketing & Graph API** (Lead Gen Webhooks, Ad Campaign Creation) and **Google Firebase Realtime Database** via Firebase Admin SDK.

---

## 🏗️ Architecture & Data Flow

```mermaid
graph TD
    subgraph Meta [Meta Marketing & Graph API]
        M_ADS[Meta Ads Campaign Engine]
        M_LEADS[Lead Ads / Instant Forms]
        M_HOOK[Real-time Webhook: leadgen]
    end

    subgraph Backend [Eligible CRM Backend :5000]
        API_ROUTER[/api Router]
        CAMP_CTRL[Campaign Controller]
        HOOK_CTRL[Webhook Controller]
        LEAD_CTRL[Lead Controller]
        META_SVC[Meta Graph & Marketing Service]
        FB_SVC[Firebase Admin & Realtime Database Service]
    end

    subgraph Firebase [Google Firebase Realtime Database]
        RT_LEADS[(RTDB: /leads)]
        RT_CAMPS[(RTDB: /campaigns)]
        RT_LOGS[(RTDB: /webhook_logs)]
    end

    subgraph Flutter [Eligible CRM Flutter App]
        FL_CAMPS[Campaigns Screen / Create Campaign Modal]
        FL_LEADS[Leads Screen & Allotment]
        FL_INT[Integrations & Meta Connection Hub]
    end

    %% Campaign Creation Flow
    FL_CAMPS -->|1. Create Campaign POST| CAMP_CTRL
    CAMP_CTRL -->|2. Orchestrate Campaign + AdSet + Creative + Ad| META_SVC
    META_SVC -->|3. POST /act_ID/campaigns| M_ADS
    CAMP_CTRL -->|4. Persist Campaign| FB_SVC
    FB_SVC --> RT_CAMPS

    %% Webhook Ingestion Flow
    M_HOOK -->|1. POST /api/webhooks/meta| HOOK_CTRL
    HOOK_CTRL -->|2. Fetch Full Lead Data| META_SVC
    META_SVC -->|3. GET /{leadgen_id}| M_LEADS
    HOOK_CTRL -->|4. Save Lead| FB_SVC
    FB_SVC --> RT_LEADS
    RT_LEADS -->|5. Sync / Display Leads| FL_LEADS

    %% Integrations & Config
    FL_INT --> API_ROUTER
```

---

## 🚀 Quick Start

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Configure Environment
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

### 3. Connect Firebase (Optional for Dev, Required for Production)
Place your Firebase Admin service account key in `backend/serviceAccountKey.json`.
> **Zero-Config Dev Mode:** If `serviceAccountKey.json` is not provided, the backend automatically operates in **Dev Simulation Mode** using `data/local_db.json`.

### 4. Connect Meta Marketing API
Fill in your Meta credentials in `.env`:
- `META_APP_ID`: Your Facebook App ID.
- `META_APP_SECRET`: Your Facebook App Secret.
- `META_ACCESS_TOKEN`: System User or Page Long-Lived Access Token with permissions:
  - `ads_management`
  - `leads_retrieval`
  - `pages_manage_ads`
  - `pages_read_engagement`
- `META_AD_ACCOUNT_ID`: Your Ad Account ID (e.g., `act_1234567890`).
- `META_PAGE_ID`: Your Facebook Business Page ID.
- `META_WEBHOOK_VERIFY_TOKEN`: A secret string used when subscribing to Meta Webhooks.

### 5. Start the Server
```bash
npm run dev    # Watch mode (Node v20+)
# or
npm start      # Production start
```

### 6. Run Test Suite
```bash
npm test
```

---

## 📡 API Reference

### Health & Status
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/health` | Service health check |
| `GET` | `/api/meta/status` | Current status of Firebase & Meta integrations |
| `POST` | `/api/meta/test-connection` | Test live Meta Access Token against Graph API |
| `GET` | `/api/meta/lead-forms` | Fetch available Lead Generation forms |

### Campaigns (Meta Marketing API)
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/campaigns` | List all campaigns (synced with Meta insights) |
| `POST` | `/api/campaigns` | **Create brand new Meta Ads Campaign, AdSet, Creative & Ad** |
| `PATCH` | `/api/campaigns/:id/status` | Update status (`ACTIVE` or `PAUSED`) on Meta and Firebase |

#### Sample: Create Meta Ads Campaign
```bash
curl -X POST http://localhost:5000/api/campaigns \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Luxury Skyline Villas Pune",
    "dailyBudget": 1500,
    "platform": "Facebook & Instagram",
    "targetLocations": ["IN"],
    "headline": "Exclusive 3 & 4 BHK Luxury Residences",
    "bodyText": "Register your interest today for preview pricing.",
    "status": "ACTIVE"
  }'
```

### Leads & Webhooks
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/webhooks/meta` | Meta Webhook Handshake (`hub.challenge`) |
| `POST` | `/api/webhooks/meta` | Ingest real-time Meta LeadGen event |
| `GET` | `/api/webhooks/logs` | Audit trail of incoming webhooks |
| `GET` | `/api/leads` | Retrieve leads from Firestore (supports `?status=&assignedTo=`) |
| `POST` | `/api/leads` | Create lead manually |
| `POST` | `/api/leads/sync` | Manually sync leads from a Meta Instant Form |

---

## 🔗 Meta Webhook Setup in Meta App Dashboard
1. Go to **Meta for Developers** -> **App Dashboard** -> **Webhooks**.
2. Select **Page** object.
3. Set **Callback URL**: `https://<your-ngrok-or-public-domain>/api/webhooks/meta`
4. Set **Verify Token**: `eligible_crm_secure_verify_token_2026` (or match your `.env`).
5. Subscribe to the `leadgen` field.
