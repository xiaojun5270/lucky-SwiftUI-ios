# Lucky V3 status compatibility audit

Reference: captured deployed 3.8.1 frontend in `/root/.hermes/cache/scratch/lucky-api-compare/16602_*.js`; comparison server 2.27.2 on localhost:16601, V3 localhost:16602. No authenticated requests or service mutations performed. Ticket-route probe used an unauthenticated POST and returned authentication rejection (V3) / missing route (V2).

## Fixed: status websocket authentication

`lucky_Status-DydoyHNA.js` offset 72830 calls `ps('/api/status/ws', {}, {signal})`; its import maps main export `bn` to `ps`. Main export maps `Tu as bn`. `Tu` calls `bn`, which obtains `Eu({method:'GET',path,query})`; `Eu` POSTs `/api/temp-access-tickets`. Response `ticketParam` defaults to `Lucky-Temp-Access-Ticket`, and the socket URL explicitly excludes the admin token. See main bundle offsets 50845–51800.

The app previously put only `Lucky-Admin-Token` in the socket URL. `StatusStream.swift` now performs the deployed ticket exchange per connection, preserves reverse-proxy base paths and opaque ticket values, and falls back to legacy authentication only for HTTP 404/405. 401/403/500 and malformed successful responses cannot trigger downgrade.

Live unauthenticated probe: V2 ticket POST -> HTTP 404 `Are you ok? Request URL [POST][/api/temp-access-tickets] not found`; V3 -> HTTP 200 `{"msg":"login invalid","ret":-1}`. Authenticated handshake remains unverified because credentials were deliberately not used.

## Protobuf: existing displayed fields remain compatible

Status bundle offsets 70080–72200: fields 1–17 and repeated history field 50 retain their wire numbers/types. Nested history fields 1–9 also match. V3 adds sample field 10 `processUsedMem` and status fields 18–21 (`swapState`, `swapKind`, `swapTotal`, `swapUsed`). The app safely skips these; existing charts are not broken. Swap display and process-memory history are feature gaps, not justified parser rewrites. Existing `ok=false` rejection is retained.

Regression command: `bash Tests/StatusCompatibility/run.sh`. Compiles production stream/protobuf/JSON/request code using Swift 6.2 Docker when no local compiler exists. Gzip and unrelated session/client dependencies are platform shells: this does not validate gzip or a real websocket handshake.

## Dashboard/module overview: feature gap, not removed API

Main offset 119734 declares GET `/api/status/module-overview`; Status bundle fetch function `W()` requires `ret===0` and `Array.isArray(response.modules)`, then polls every 5 seconds. Modules contain `key`, `metrics`, and detail entries; the UI includes SSL/DDNS/webservice/portforward/STUN/Docker summaries.

The current app dashboard (`DashboardScreen.swift:443–468, 612–634`) consumes the live socket and polls full webservice rules every 30 seconds; it does not call the new overview endpoint. `LuckyService.dashboard():62–74` still uses `/api/status`, `/api/info`, `/api/modules/list`, `/version`, but this helper is not called by the displayed dashboard. Live `/api/status` on both versions returned HTTP 200 authentication rejection, so it was NOT removed. `/api/status/module-overview`: V2 HTTP 404, V3 HTTP 200 authentication rejection. Implementing the new richer dashboard is outside owned files and requires authenticated schema fixtures/UI work.

## Other important scope gaps

- Shared temporary ticket support is still absent outside this status fix. `DockerImageUpgradeProtocol.swift:70` / `LuckyClient+DockerUpgrade.swift:34` still construct admin-token websocket URLs. Docker owner should compare deployed upgrade-check socket with main `Tu` helper; do not infer that fixing status fixes every websocket/download.
- V3 history APIs (`/api/status/history`, `/meta`, `/process-ranks`) and host monitoring (`/api/status/host-overview`, `/host-processes`, `/host-connections`) are absent from the app. These are missing new frontend capabilities, not proven regressions in existing screens.
- DDNS V3 adds `/api/ddns/credential-sources`, `/ip-source-defaults`, `/ip-source-test`, `/ipv6-selection-test`, `/router-providers`, `/router-test`, `/router-ssh-host-key`; SSL adds `/api/ssl/credential-sources`, `/ip-source/capabilities`, `/ip-source/preview`, `/platform/capabilities`, `/platform/certificates`. Existing native editors do not load these sources. New V3 router/source/platform configuration cannot be claimed fully supported by the old native forms without payload comparison.
- Webservice V3 adds discovery, statistics, custom error responses, frontend-state and WebAuth session management routes. No implementation claimed here; separate owner handles WebService compatibility.
- Literal-path inventories overstate gaps for Docker/FRP/cloudflared because the app constructs paths dynamically. No counts or failure claims are based on literal absence alone.

No login, DockerService, WebService, UI, or model files modified by this audit.
