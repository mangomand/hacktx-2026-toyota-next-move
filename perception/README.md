# Model-backed vehicle perception (local integration)

The live camera sends a JPEG sampled at most once every two seconds, with one request in flight. The server calls OpenAI's Responses API with an image and a strict structured output schema. The app records a region only after two distinct consecutive images identify that region with confidence >= 0.7. This threshold is provisional and is not an accuracy guarantee. The requested region is never sent as an observation or hint.

Normal nighttime/colored light is allowed when the vehicle region remains recognizable. The old blur threshold no longer vetoes these model observations. No image produces a damage finding or mechanical/safety conclusion. Unclear orientation stays unknown. The 3D indicator consumes confirmed region state; this change does not reconstruct geometry or add a surface shader.

## Connect the existing backend

Run `server.py` in a private backend process behind HTTPS (Python 3.10+, standard library only). The included `Dockerfile` is Railway-compatible. Set secrets in the host's secret/environment settings, not in the repository:

- `OPENAI_API_KEY`: OpenAI project API key, server only.
- `OPENAI_VISION_MODEL`: optional, defaults to `gpt-4.1-mini` (image input + structured outputs). Keep this default for the initial quality/cost baseline; compare another model only with the same labeled fixture set.
- `PERCEPTION_ACCESS_TOKEN`: separate app-to-backend test access token; never use the OpenAI key here.
- `PERCEPTION_HOST`: optional; defaults to `0.0.0.0` for hosted containers.
- `PORT`: set automatically by Railway; otherwise `PERCEPTION_PORT` defaults to `8787`.

Start locally with `python3 perception/server.py`; hosted deployments expose `GET /healthz` and authenticated `POST /v1/observe`. The phone must reach that host; `localhost` on a phone is the phone, not the Mac. This bridge is for private development, not public unauthenticated deployment. It bounds payload size and concurrency but is not a production user-auth/billing system.

### Railway setup

Create a Railway project from this repository at the repository root; the root `Dockerfile` is the service entrypoint. Set `OPENAI_API_KEY`, `PERCEPTION_ACCESS_TOKEN`, and optionally `OPENAI_VISION_MODEL=gpt-4.1-mini` as Railway variables. Generate a Railway domain, verify `GET https://<domain>/healthz`, then set the iOS `PERCEPTION_ENDPOINT` build setting to `https://<domain>/v1/observe`. Never place the OpenAI key in iOS variables.

Configure the iOS target's build settings `PERCEPTION_ENDPOINT` (full HTTPS URL ending `/v1/observe`) and `PERCEPTION_ACCESS_TOKEN` (the test proxy token). The Info.plist expands these settings. No OpenAI API key is shipped in the app. Scheme environment variables or app UserDefaults with the same names can configure local development. The proxy token in a private test build is not a replacement for production per-user authorization.

Camera samples go to the configured backend and OpenAI for visual analysis. Requests set `store: false`; this is not a promise of zero provider retention. The bridge does not persist or log images, tokens or output. The iOS app keeps sampled JPEG evidence in its Caches/ScanEvidence directory for confirmed regions; caches are purgeable and not a durable inspection archive.

## Boundary

Request: `{ "frameID": "unique-id", "imageBase64": "<JPEG base64>" }`.

Response: `{ "frameID": "same-id", "vehiclePresent": true, "usability": "limited", "regions": [{ "id": "front", "confidence": 0.8 }], "guidance": "Hold the front view briefly." }`. The server rejects more than four regions, non-canonical IDs, low-confidence/non-finite values, unusable views with regions, diagnostic language, empty/gibberish guidance, and no-vehicle contradictions.

This example documents the protocol; it is not runtime scan evidence. Canonical wire contracts are unchanged. Invalid/duplicate regions, wrong frame IDs, unreadable images, no vehicle, failures and uncertain views cannot manufacture coverage. Pausing/canceling/finishing invalidates in-flight responses. Different regions are observed independently of the prompt.

## Verification

- `cd perception && python3 -m unittest -v`: real local HTTP request/auth test plus mocked upstream request/response validation. Does not call a live model or establish accuracy.
- `swift test --package-path ios --disable-sandbox`: model-observation validation, consecutive-frame confirmation, no prompt-assigned coverage, uncertainty, duplicate-frame and pause behavior.
- Xcode simulator build compiles the native camera/JPEG/network integration. Simulator compilation does not validate physical camera behavior.

Live endpoint configuration and a real model call on labeled daytime/nighttime/front/rear/side/ambiguous/no-car footage are required before accepting perception accuracy. Track wrong-region accepts, unknown rate and response latency; do not infer correctness from a model's confidence field. No TestFlight build is created for this increment.

Official API references: https://developers.openai.com/api/docs/guides/images-vision and https://developers.openai.com/api/docs/guides/structured-outputs .
