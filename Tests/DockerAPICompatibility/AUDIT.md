# Docker / service V2+V3 compatibility audit

Evidence: saved real frontends for Lucky 2.27.2 (16601) and 3.8.1 (16602), under `/root/.hermes/cache/scratch/lucky-api-compare`. No authenticated calls or service mutations were made.

## Implemented

- V2 `POST containers/set-group` falls back to V3 `PUT containers/group` only on an explicit missing-route response. Identical `{containerName,groupKey}` payload.
- V2 `GET containers/order-mapping` falls back to V3 `GET containers/sort-config`. V3 response uses `sort.flat_order` and `mapping`; preserve raw fields and add legacy aliases.
- V2 synchronous `POST images/upgrade-containers` falls back to V3 `POST images/upgrade-plan`, validates schema 1, matching revision, reference, flags, exact selected IDs and allowed row actions, then submits the returned request with a UUID `request_key` to `images/upgrade-containers-async`. Poll the task; return only its completed result. Never retry an ambiguous mutation failure.
- Upgrade-check WebSocket obtains `POST /api/temp-access-tickets` with `{method:"GET",path:"/api/docker/images/upgrade-check-ws",query:{image_ref}}`. Build URL using returned `ticketParam` (default `Lucky-Temp-Access-Ticket`); never include admin token in V3 URL. Only an explicitly absent ticket route enables V2 admin-query authentication. Auth/application failures do not downgrade.
- Compose creation (`compose/up-async`) now includes a UUID `request_key`; no automatic replay.
- File-operation tests exercise all existing 15 operation method/path/body choices; these match the V3 client. Common DDNS enable/sync, SSL enable and FRP/Cloudflared enable contracts remain unchanged.

Primary V3 evidence: `16602_lucky_client-BsYPm-ob.js` contains Docker route/method/payload definitions. `16602_lucky_panel-DzEUy_Yt.js` contains `ImageUpgradePlanDialog`, schema/revision validation, task submission, and sort response consumption. `16602_lucky_main-BMGWVUhg.js` contains `Eu`, `bn`, `Tu` temporary-ticket acquisition/URL helpers. DDNS: `16602_lucky_ddns-dIiA1oS_.js`. SSL: `16602_lucky_dnsCredentialSources-CigcXNGI.js`. Tunnels: corresponding `16602_lucky_{stun,frp,cloudflared}-*.js`.

## Tests

`bash Tests/DockerAPICompatibility/run.sh`: macOS Swift, native Linux Swift, or Docker `swift:6.2`. The service harness compiles the real Docker/DDNS/SSL/tunnel implementations against a scripted actor transport boundary. It asserts actual emitted requests and returned results; it never connects to a real Lucky instance. RED failures were observed for V3 grouping, sorting reads, async upgrade, ticket support and Compose request key before implementation. Existing-shape tests are regression characterization, not claimed as failing-before-fix tests.

## Remaining limits

- No authenticated end-to-end upgrade, ticket handshake, Compose execution or filesystem mutation was performed. Production Core socket wiring is changed, but this harness tests ticket acquisition and URL construction rather than URLSession's handshake implementation.
- Legacy `container-groups/order`, `PUT containers/order-mapping`, and `containers/switch-version` have no safe one-to-one V3 mapping. V3 sorting uses distinct flat/compose/custom endpoints and a full state payload. They remain unsupported on V3 rather than overwrite unrelated order state. Current app grouping action is covered; these older wrappers are not current screen reorder actions.
- Legacy per-container upgrade route remains unsupported when missing. Current container-upgrade sheet uses the image API, whose selected-container path is covered.
- V3 requests with `container_ids: null` are deliberately refused after the absent legacy route: no implicit broad upgrade.
- DDNS `ipsectionexpanded` is absent from the V3 DDNS frontend; not remapped speculatively. Existing DDNS/SSL/tunnel CRUD/settings were inspected, not exhaustively integration-tested. New V3-only credentials/platform/node features are out of scope.
- V3 cleanup/recovery/self-update flows can require Web UI attention; errors are surfaced, not silently replayed. Generated request keys are per explicit invocation, not persisted across app restarts or user resubmissions.
