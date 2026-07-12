# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Serverless AWS resume-optimizer web app. Users sign in, upload resumes (PDF), paste a job-listing URL to parse, then chat with an AWS Bedrock Agent that does RAG over their own stored listings + resumes.

The frontend is a React SPA (Vite + React 18 + React Router v6 + CSS Modules). The backend is six AWS Lambda functions fronted by an HTTP API with a Cognito JWT authorizer (no custom authorizers, no Lambda@Edge on `/api/v1/*`).

## Deploy / dev commands

There is no test suite. The command surface has three layers: backend (Terraform), frontend (Vite), and the SPA→S3 deployment step.

**Backend (Terraform):**
- All Terraform lives under `infra/`. Run `terraform init && terraform apply` from `infra/`. Provider pinned to AWS region `us-east-1` (infra/main.tf). The `parse_auth` Lambda@Edge and HTTP API both require that region.
- **Layout**: `infra/{main,variables,outputs,api_gateway,cognito,cloudfront,lambdas,dynamodb,opensearch,bedrock}.tf`. Python sources under `../lambda/` and the React SPA under `../front_end/spa/` are NOT moved — Terraform only references them via `${path.module}/../lambda/...` paths.
- **Build & push the scraper image** — `null_resource.Lambda_DockerFile_Update` in `infra/lambdas.tf` shells out to `aws ecr get-login-password | docker login … && docker build && docker push` every apply, keyed on `filemd5` of `lambda/parse_listing/{Dockerfile, requirements.txt, lambda_scraper.py}`. Locally equivalent: `docker build -f lambda/parse_listing/Dockerfile lambda/parse_listing/`.
- **Repackage zipped Lambdas** — every `data "archive_file"` block in `infra/*.tf` regenerates a `.zip` on `terraform apply`; do not commit the generated `.zip` files. `infra/.gitignore` lists them.
- **Update Lambda@Edge config** — `lambda/authorization/config.py.tmpl` is substituted into `config.py` (no Lambda@Edge env vars allowed). The mechanism is part of Terraform string interpolation — search for `templatefile`/`local_file`/`null_resource` if the substitution wiring isn't visible in the file you are looking at.
- **Required env vars / secrets before apply** — `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` exported (commented TODO in main.tf); Cognito `SNS_external_ID`, CloudFront domain, `cognito_user_pool_id`, `cognito_user_pool_client_id`, plus all the `*_ARN`/`*_ID` variables declared in `infra/variables.tf`.

**Frontend (Vite SPA at `front_end/spa/`):**
- `cd front_end/spa && npm install` (one-time).
- `npm run dev` — local dev at `http://localhost:5173`. **Note**: API Gateway CORS only allows the CloudFront origin, not `localhost`. The dev server has a `/api/v1/*` proxy in `vite.config.js` placeholder (target must be replaced with the actual CloudFront domain before use).
- `npm run build` — outputs `dist/index.html` + hashed assets under `dist/assets/`.
- **Single-test equivalent** — invoke a Lambda through API Gateway with `curl -H "Authorization: Bearer $IDTOKEN"` against the CloudFront URL. Need a valid idToken (sign in via Hosted UI, grab token from `/dashboard?token=…`).

**SPA deploy:**
```sh
aws s3 sync front_end/spa/dist/ s3://liangtaohu-website-bucket/ --delete --exclude "*.map"
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```

## Architecture

```
Browser → CloudFront (HTTPS)
            ├─ S3 origin:  SPA shell + hashed assets
            │              403/404 → /index.html (SPA fallback, see static_website.tf)
            │              /callback → parse_auth Lambda@Edge (sets cookies, 302→/dashboard?token=…)
            └─ API Gateway origin: /api/v1/* routes, JWT authorizer pointed at Cognito User Pool
                                     ├─ GET  /api/v1/upload_resume  → s3_presigned_url Lambda
                                     ├─ POST /api/v1/parse_listing  → web_scraper_lambda (Docker)
                                     ├─ POST /api/v1/message        → message_bedrock Lambda
                                     ├─ GET  /api/v1/view_data      → conversation_starter Lambda
                                     ├─ POST /api/v1/search_jobs    → search_jobs Lambda (Adzuna proxy, preview only)
                                     ├─ POST /api/v1/jobs/add       → job_crud Lambda (add_job.handler)
                                     └─ POST /api/v1/jobs/delete    → job_crud Lambda (delete_job.handler; soft-delete via `deletedAt`)
```

Identity is the **Cognito `sub` claim** propagated by the API Gateway authorizer (`event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]`). All six API Lambdas have stopped reading the cookie and now rely entirely on this claim (and the SPA sends `Authorization: Bearer <idToken>`). The `idToken` is read in by `parse_auth` on `/callback` and handed back to the browser via `/dashboard?token=…`; the SPA's `Dashboard.jsx` captures it on mount into `sessionStorage`/`AuthContext`.

### Backend Lambdas
- `lambda/upload_resume/s3_presigned_url.py` — presigned S3 POST keyed by `f"{sub.lower()}/{ts}.pdf"`, one-upload-per-window via DynamoDB `LINK` row (`PENDING → USED`). Two S3-event Lambdas (`alert_dynamo_link.py`, `add_dynamo_resume.py`) continue to read identity from the S3 object key prefix — that prefix now matches the new `sub` namespace used by the API path.
- `lambda/parse_listing/lambda_scraper.py` — the only **container** Lambda (`Dockerfile` pulls `aws-lambda-python-selenium:3.12`). Selenium Chrome loads the URL, Claude-Sonnet extracts `JobListing { position, company, requirements, optional_skills }`, the content is chunked, embedded with `amazon.titan-embed-text-v2:0`, written to OpenSearch index `f"{sub.lower()}-job-listings"` (one index per user). The metadata filter in `message_bedrock.py` keys on this same `sub`.
- `lambda/chat/message_bedrock.py` — conversation endpoint. Loads/creates `CONV#<id>`, fetches `JOB#` + `RESUME#` rows, prepends `cachedText` to the prompt, calls `bedrock-agent-runtime.InvokeAgent` with a `knowledgeBaseConfigurations` filter `andAll([user-id == sub, title == f"{company}-{position}"])`. **Note: `AGENT_ALIAS_ID` is read from env but `lambda/chat/variables.tf` doesn't declare it — known wiring TODO.**
- `lambda/view_data/conversation_starter.py` — powers the "Choose 2" picker. Returns `resumes`, `job_listings`, `conversations` via three DynamoDB `Query` calls; the `JOB#` query filters on `attribute_not_exists(deletedAt)` so soft-deleted rows stay hidden from the SPA. *(The data is keyed under `body`, not `data` — was a string-vs-int bug, now fixed.)*
- `lambda/search_jobs/search_jobs.py` — stateless Adzuna proxy. POST `{keywords, max_results, country}` → `GET https://api.adzuna.com/v1/api/jobs/{country}/search/1` → `{results: [{adzuna_id, title, company, location, url, snippet}]}`. No DB writes; the SPA shows the preview and asks the user which to import.
- `lambda/job_crud/{add_job,delete_job}.py` — single zip, two handlers, two distinct Lambda functions. `add_job` calls `UpdateItem` with `attribute_not_exists(deletedAt)` to write `JOB#<co>-<pos>` with `status: PENDING_INGEST`. `delete_job` calls `UpdateItem` to set `deletedAt = <iso8601>`, idempotent (no guard). Restoring a soft-deleted row is a future endpoint.

### Bedrock / OpenSearch (`serverless_services/`)
- One OpenSearch Serverless collection `resume-rag-database` (VECTORSEARCH), AWS-owned-key encryption, public network policy, data-access policy grants `aoss:APIAccessAll` to the parse-listing role and `kb-exec-role`.
- One Bedrock KB `resume-knowledge-base` over that collection, vector field `bedrock-vector`, embedding model `amazon.titan-embed-text-v2:0`. KB's data source points back at the parse_listing Lambda.
- One Bedrock Agent `resume-optimizer` on `anthropic.claude-v2`, idle TTL 300s, SESSION_SUMMARY memory.
- **Mismatch:** `parse_listing` writes to OpenSearch index `f"{sub.lower()}-job-listings"` but `serverless_services/bedrock.tf` declares the KB's vector index name as `resume-rag-database`. These need reconciling for KB retrieval to actually return vectors.

### DynamoDB (single-table, hash=`HK`, range=`SK`, both strings; documented at the top of `serverless_services/dynamodb.tf`)
| HK | SK | extra attrs |
|---|---|---|
| `USER#<sub>` | `RESUME#<file>` | S3Location, cachedText |
| `USER#<sub>` | `LINK` | url, fields, status, expiresIn |
| `USER#<sub>` | `JOB#<company>-<position>` | company, position, url, status, adzunaId?, deletedAt? |
| `USER#<sub>` | `CONV#<id>` | resumeID, jobID, chatHistory |

### React SPA (`front_end/spa/`)
- `package.json` declares `react@^18`, `react-dom@^18`, `react-router-dom@^6`, plus `vite@^5` and `@vitejs/plugin-react`. ESLint config in `.eslintrc.cjs`.
- **Auth lives entirely in `src/auth/`:** `AuthContext.jsx` (idToken state + sessionStorage mirror), `api.js` (`useApi().apiFetch` wrapper that injects `Authorization: Bearer`), `login.js` (`startLogin()` builds the Hosted UI URL from `VITE_COGNITO_DOMAIN`/`VITE_COGNITO_CLIENT_ID`; `signOut()` hits `/logout` + clears `sessionStorage`).
- **Components:** `Layout.jsx` wraps every route with `<Header /><Outlet /><Footer />`. `ProtectedRoute.jsx` redirects unauthenticated visitors to `/?next=<path>`.
- **Pages:** `Home.jsx` (landing + "Sign up / Log in" call), `Dashboard.jsx` (captures `?token=…`, renders greeting + three feature links), `Resumes.jsx` (presigned upload flow), `Listings.jsx` (job listing table + side panel), `Chats.jsx` (Choose-2 picker + chat thread; sends to `/api/v1/message`), `Error.jsx` (handles both `?error=auth_failed&reason=…` and the catch-all `*` route).
- **CSS:** every page has a `*.module.css` colocated under `src/styles/`. `base.css` is loaded once globally (imported in `main.jsx`) and keeps its tag-level selectors for `header`/`footer`/`nav`. Modifiers like `.selected`, `.disabled`, `.valid`, `.info_shown`, `.hidden` carry state via class concatenation. **Cross-page shared classes** (`.icon`, `.listing`) intentionally duplicate across modules — that's the cost of CSS Modules.
- **Build / deploy:** `npm run build` outputs `dist/` which is uploaded with `aws s3 sync` to `s3://liangtaohu-website-bucket/`. The bucket is private and only CloudFront OAC can read it.
- **SPA fallback:** `aws_cloudfront_distribution` has two `custom_error_response` blocks (`403 → 200 /index.html`, `404 → 200 /index.html`) so deep links (`/dashboard`, `/chats`, …) and direct refreshes resolve to the React shell.

### Cognito (`lambda/authorization/cognito.tf`)
- `aws_cognito_user_pool` `client-users`, MFA optional, self-service signup enabled, email verification on, `https://<cloudfront>/callback` is the only OAuth callback URL, OAuth scopes `openid email phone`.
- `aws_cognito_user_pool_domain` named `resume-optimizer-domain` produces the Hosted UI URL the SPA points at.
- `parse_auth.py` (Lambda@Edge) runs on `/callback` viewer-request, validates the nonce from the `state` parameter, exchanges the code for tokens, and 302s to `https://{host}/dashboard?token=<idToken>`. It still sets `idToken`/`refreshToken` HttpOnly cookies for legacy callsites — the SPA ignores them.

## Known caveats / TODOs worth knowing

- **ACM cert is missing.** `front_end/static_website.tf:viewer_certificate` references `aws_acm_certificate.cert.arn` but no resource defines it; the `data "aws_acm_certificate"` block is just a placeholder. `terraform apply` will fail until this is added.
- **Missing `aws_s3_bucket.resume_bucket`.** Referenced by `lambda_funcs.tf` (Lambda IAM policy) but never declared. Add it (or an `s3_bucket` variable + definition) before applying.
- **OpenSearch index name mismatch** between `parse_listing/lambda_scraper.py` (`f"{sub}-job-listings"`) and the KB's declared `vector_index_name = "resume-rag-database"` in `serverless_services/bedrock.tf`. Fix by aligning the scraper to write to `resume-rag-database` (matching the KB) and switching the metadata filter accordingly.
- **`AGENT_ALIAS_ID` env var** is referenced in `lambda/chat/message_bedrock.py:8` but no `variables.tf` declares it yet. `terraform apply` will fail.
- **No `cognito_domain` variable** for the SPA's `VITE_COGNITO_DOMAIN`. The operator runs `terraform output` on the Cognito User Pool Domain resource to wire it into `.env`. (Could be plumbed through Terraform, but not done yet.)
- **Cross-module wiring TODO** — there is no root `main.tf` that orchestrates the nested `*.tf` modules; all the `*_ARN`/`*_ID` variables must be supplied via `terraform apply -var` or a tfvars file. **Resolved** by the infra/ merge — everything now sits in one root module under `infra/`.
- **Dev-mode CORS** — the API Gateway allow-list is restricted to the CloudFront origin. Local Vite dev needs either a Terraform workspace with relaxed CORS, or the dev-server proxy in `vite.config.js` filled in with the actual CloudFront URL.
- **No silent idToken refresh** yet. ~1h after login the SPA gets `401`s from API Gateway; no auto-redirect or refresh flow is implemented.
- **`CHATS`/`CONV#` rows** keyed under old `idToken` values will coexist with new `sub`-keyed rows until cleaned up. No migration script.
- **`Remove -` button on the listings page** is now wired to `POST /api/v1/jobs/delete` (soft-delete via `deletedAt`); restore endpoint is a future follow-up.
- **HTTP API `cors_configuration`'s response-side limitation:** API Gateway handles preflight `OPTIONS` but does NOT inject `Access-Control-Allow-Origin` on proxied Lambda responses. Every Lambda return dict emits CORS via a `cors_headers(event)` helper that echoes `event.headers.origin`. If you add a new Lambda behind the API, give it the same helper.
