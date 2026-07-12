# Backend architecture

Three views of the same system:

1. **System overview** — which components exist and how they connect.
2. **Auth flow** — request-level sequence for sign-in.
3. **Chat-with-RAG flow** — the most layered flow in the app (SPA → API Gateway → Lambda → Bedrock Agent → KB → OpenSearch).

## 1. System overview

```mermaid
graph TB
    subgraph Client
        Browser["Browser<br/>(React SPA in sessionStorage holds idToken)"]
    end

    subgraph Edge["AWS Edge (us-east-1)"]
        CF["CloudFront<br/>liangtaohu-website-bucket alias<br/>custom_error_response 403/404 -> /index.html"]
        S3Static["S3: liangtaohu-website-bucket<br/>(SPA build, private + OAC)"]
        LambdaEdge["Lambda@Edge: parse_auth<br/>viewer-request on /callback"]
    end

    subgraph Identity["Cognito"]
        CognitoPool["User Pool: client-users<br/>(+ Hosted UI @ resume-optimizer-domain)"]
    end

    subgraph API["API layer"]
        APIGW["HTTP API<br/>JWT Authorizer<br/>(identity_source = Authorization header)"]
    end

    subgraph Lambdas["Lambda (us-east-1)"]
        Upload["lambda_s3_upload_function<br/>s3_presigned_url.handler"]
        Parse["web_scraper_lambda<br/>Docker image: aws-lambda-python-selenium:3.12"]
        View["lambda_display_user_data<br/>conversation_starter.handler"]
        Chat["lambda_message_bedrock<br/>message_bedrock.handler"]
        Search["lambda-search-jobs<br/>search_jobs.handler<br/>(Adzuna proxy — preview only)"]
        JobCrud["lambda-job-crud-add<br/>add_job.handler<br/>+<br/>lambda-job-crud-delete<br/>delete_job.handler<br/>(soft-delete via deletedAt)"]
        S3T1["add_dynamo_resume_trigger<br/>(S3 ObjectCreated)"]
        S3T2["alert_dynamo_link_trigger<br/>(S3 ObjectCreated)"]
    end

    subgraph Data["Data stores"]
        DDB[("DynamoDB<br/>res-optimizer-user-data<br/>HK: USER#<sub>")]
        S3Resume["S3: resume bucket<br/>key = sub.lower()/&lt;ts&gt;.pdf<br/>(declared elsewhere)"]
        OSS[("OpenSearch Serverless<br/>collection: resume-rag-database<br/>vector index name mismatch — see caveat")]
    end

    subgraph Bedrock["Bedrock"]
        KB["Knowledge Base<br/>resume-knowledge-base<br/>embedding model: amazon.titan-embed-text-v2:0"]
        Agent["Bedrock Agent<br/>resume-optimizer<br/>foundation model: anthropic.claude-v2<br/>KB association ENABLED"]
        Sonnet["Claude 3 Sonnet<br/>anthropic.claude-3-sonnet-20240229-v1:0"]
    end

    Browser -->|"HTTPS GET /"| CF
    CF -->|"default / static asset"| S3Static
    CF -->|"path /api/v1/*"| APIGW
    CF -->|"path /callback"| LambdaEdge

    Browser -.->|"Hosted UI login redirect"| CognitoPool
    CognitoPool -.->|"302 /callback?code=&state="| CF
    LambdaEdge -->|"POST /oauth2/token<br/>exchange code -> tokens"| CognitoPool

    APIGW -->|"GET /upload_resume"| Upload
    APIGW -->|"POST /parse_listing"| Parse
    APIGW -->|"GET /view_data"| View
    APIGW -->|"POST /message"| Chat
    APIGW -->|"POST /search_jobs"| Search
    APIGW -->|"POST /jobs/add"| JobCrud
    APIGW -->|"POST /jobs/delete"| JobCrud

    Search -.->|"GET /jobs/{country}/search<br/>app_id, app_key"| Adzuna["Adzuna Jobs API<br/>adzuna.com"]

    Upload --> DDB
    Upload -.->|"presigned POST URL"| Browser
    Browser -->|"POST multipart (file)"| S3Resume
    S3Resume -.->|"ObjectCreated:*"| S3T1
    S3Resume -.->|"ObjectCreated:*"| S3T2
    S3T1 -->|"put RESUME# row"| DDB
    S3T2 -->|"update LINK status -> USED"| DDB

    Parse --> DDB
    Parse -->|"embed chunks + write vectors"| OSS
    Parse -.->|"structured extraction"| Sonnet

    View --> DDB
    JobCrud --> DDB

    Chat --> DDB
    Chat -->|"InvokeAgent<br/>(filter: user-id == sub, title == co-pos)"| Agent
    Agent --> KB
    KB -->|"embed query"| OSS
    KB --> Titan["Titan Embed v2<br/>amazon.titan-embed-text-v2:0"]
```

Notes on the graph above:
- The same Cognito `sub` claim flows to (a) DynamoDB `USER#<sub>` keying, (b) S3 resume object key prefix `<sub.lower()>/<file>.pdf`, (c) OpenSearch vector metadata `user-id=<sub>`, and (d) the Bedrock KB retrieval filter.
- DynamoDB layout (single-table): `USER#<sub>` + `RESUME#<file>` | `LINK` | `JOB#<company>-<position>` | `CONV#<id>` (full key patterns documented in `serverless_services/dynamodb.tf`).
- **Keyword search & soft-delete flow:** `/search_jobs` is a stateless Adzuna proxy — it does not write to DynamoDB. `/jobs/add` writes a `JOB#<co>-<pos>` row with `status: PENDING_INGEST`. `/jobs/delete` performs a *soft* delete by setting `deletedAt = <iso8601>`; the row stays in DynamoDB for future restore but `view_data`'s `JOB#` query filters on `attribute_not_exists(deletedAt)` so soft-deleted rows never reach the SPA. OpenSearch vectors for soft-deleted listings are orphaned (a known follow-up).

## 2. Sign-in flow (sequence)

`parse_auth` Lambda@Edge runs as a `viewer-request` hook on the `/callback` cache behavior. API Gateway JWT authorizer runs as the request validator on every `/api/v1/*` route.

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant SPApp as React SPA<br/>(sessionStorage)
    participant CF as CloudFront
    participant Cognito as Cognito Hosted UI
    participant LE as parse_auth<br/>Lambda@Edge
    participant DDB as DynamoDB
    participant API as HTTP API<br/>JWT Authorizer
    participant Lambda as any /api/v1/*<br/>Lambda

    U->>SPApp: 1. Click "Sign up / Log in"
    SPApp->>SPApp: 2. startLogin() builds Hosted UI URL from VITE_COGNITO_DOMAIN + nonce in state
    SPApp->>Cognito: 3. 302 to Hosted UI (/login)
    U->>Cognito: 4. Enter credentials
    Cognito-->>CF: 5. 302 /callback?code=A&state=B
    CF->>LE: 6. viewer-request trigger
    LE->>LE: 7. Parse state (decode base64), read nonce from cookie, compare
    LE->>Cognito: 8. POST /oauth2/token (grant_type=authorization_code)
    Cognito-->>LE: 9. { id_token, refresh_token, expires_in }
    LE->>CF: 10. 302 /dashboard?token=<idToken><br/>Set-Cookie: idToken, refreshToken (HttpOnly)
    CF->>SPApp: 11. SPA loads, Dashboard.jsx captures ?token=...
    SPApp->>SPApp: 12. AuthContext.setIdToken() -> sessionStorage<br/>history.replaceState strips token from URL

    Note over U,SPApp: Subsequent API call
    U->>SPApp: 13. Click "View Resumes"
    SPApp->>API: 14. GET /api/v1/view_data<br/>Authorization: Bearer <idToken>
    API->>API: 15. JWT authorizer: validate signature, exp, aud, iss against Cognito JWKS
    API->>Lambda: 16. event.requestContext.authorizer.jwt.claims.sub propagated
    Lambda->>DDB: 17. Query USER#<sub>
    DDB-->>Lambda: 18. RESUME# / JOB# / CONV# rows
    Lambda-->>API: 19. 200 + JSON body
    API-->>SPApp: 20. Response body + CORS echoed by Lambda
```

## 3. Chat-with-RAG flow (sequence)

This is the most layered request in the system. The Bedrock Agent picks the KB, the KB embeds the query and retrieves vectors from OpenSearch, and the Agent synthesizes the answer using `anthropic.claude-v2`. The filter `user-id == sub AND title == company-position` is what scopes retrieval to the user's own uploaded listing.

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant SPApp as React SPA<br/>(Chats.jsx)
    participant API as HTTP API +<br/>JWT Authorizer
    participant Chat as message_bedrock<br/>Lambda
    participant DDB as DynamoDB
    participant Agent as Bedrock Agent<br/>resume-optimizer<br/>claude-v2
    participant KB as Bedrock KB<br/>resume-knowledge-base
    participant Titan as Titan Embed v2
    participant OSS as OpenSearch Serverless

    U->>SPApp: 1. Pick 1 resume + 1 listing, click Generate, type message, click Send
    SPApp->>API: 2. POST /api/v1/message<br/>Authorization: Bearer <idToken><br/>Body: { user_message, conversation_id, resume_id, job_id }
    API->>API: 3. JWT validated -> claims attached
    API->>Chat: 4. JSON event with sub claim
    Chat->>DDB: 5. Get CONV#<id> (or create from resume_id+job_id)
    DDB-->>Chat: 6. chatHistory, resumeID, jobID
    Chat->>DDB: 7. Get JOB#<id>
    DDB-->>Chat: 8. company, position
    Chat->>Chat: 9. Build prompt:<br/>"USER RESUME: <cachedText>" + "USER MESSAGE: ..."<br/>(or full chat history if last msg > 1h ago)
    Chat->>Agent: 10. InvokeAgent(inputText, sessionId,<br/>  sessionState.knowledgeBaseConfigurations[<br/>    filter: andAll([user-id == sub, title == co-pos])<br/>  ])
    Agent->>Agent: 11. claude-v2 reasons about the prompt + decides to retrieve
    Agent->>KB: 12. bedrock:Retrieve (query = prompt, same filter)
    KB->>Titan: 13. Embed query
    Titan-->>KB: 14. Embedding vector
    KB->>OSS: 15. POST _search { knn, filter }<br/>(4cA v4 signing via aoss)
    OSS-->>KB: 16. Top-K vectors (per-user, per-listing scope)
    KB-->>Agent: 17. Retrieved text chunks
    Agent->>Agent: 18. claude-v2 composes answer from chunks + prompt
    Agent-->>Chat: 19. completion stream (delta chunks)
    Chat->>Chat: 20. derive_full_text() concatenates bytes
    Chat-->>API: 21. 200 { agent_text: "..." }
    API-->>SPApp: 22. SPA appends Agent message to chat thread
```

Caveats this diagram does *not* hide:
- The OpenSearch index name in `parse_listing/lambda_scraper.py` is `f"{sub.lower()}-job-listings"` (one index per user), but `serverless_services/bedrock.tf` declares the KB's `vector_index_name` as `resume-rag-database`. Until those are reconciled, step 15 returns nothing and the agent falls back to model knowledge only.
- DynamoDB-`CACHE` TTL is set on the `expiresIn` attribute via the table-level `ttl` block, but `expiresIn` is only written today by `LINK` rows; `RESUME`/`JOB`/`CONV` rows have no expiry.
- Bedrock KB agent association is `knowledgeBase_state = ENABLED` in `bedrock.tf` but the `agent_version` and `prepare_flow` lifecycle steps are skipped — Bedrock auto-prepares on first invoke.
