# FocusGlobe Online — CloudKit Schema & Dashboard Setup

Container (exact, used everywhere via `CloudKitConfig.containerIdentifier`):

```
iCloud.com.mobitegames.FocusGlobe
```

All CloudKit access goes through `CKContainer(identifier: CloudKitConfig.containerIdentifier)`.
`CKContainer.default()` is never used by FocusGlobe Online.

> **Environment**: do all of the setup below in the **Development** environment
> first. Never auto-deploy to Production — promote the schema manually with
> *Deploy Schema Changes…* in the CloudKit Dashboard once two-account device
> testing has passed.

CloudKit creates record types automatically in Development the first time the
app saves a record ("just-in-time schema"), but **indexes and security roles
are never created automatically** — they must be added by hand as described
below, or every query in the app will fail with "field not marked queryable".

---

## 1. Databases at a glance

| Database | Record types | Who reads / writes |
|---|---|---|
| **Private** | `FocusIdentity`, `SkyUnlockCampaign`, pre-share `FocusRoom` + children (in the custom zone `FocusGlobeRoomsZone`) | Only the record owner |
| **Public** | `PublicProfile`, `SkyPresence`, `FriendRequest`, `FriendConnection` | Everyone reads; creator writes own records |
| **Shared** | Accepted `FocusRoom`, `RoomParticipant`, `RoomFlightSession`, plus the `cloudkit.share` (CKShare) records | Share participants per CKShare permissions |

Custom zone (private database): **`FocusGlobeRoomsZone`** — required because
CKShare roots must live in a custom zone. Created lazily by
`FocusRoomService.ensureZone()`.

---

## 2. Record types & fields

### Private database

#### `FocusIdentity` — fixed record name `current-user-identity` (default zone)

| Field | Type |
|---|---|
| `publicID` | String |
| `anonymousHandle` | String |
| `createdAt` | Date/Time |
| `updatedAt` | Date/Time |
| `schemaVersion` | Int(64) |

One per iCloud account; created on first successful connection, reused across
the user's devices. Contains no personal data — `publicID` is a random UUID
and `anonymousHandle` is a generated `SkyPilot####` name (user-editable).

#### `SkyUnlockCampaign` — record name `campaign-<skyID>` (default zone)

| Field | Type |
|---|---|
| `campaignID` | String |
| `ownerPublicID` | String |
| `skyID` | String |
| `requiredAcceptedUsers` | Int(64) |
| `acceptedUniquePublicIDs` | String (List) |
| `createdAt` | Date/Time |
| `updatedAt` | Date/Time |
| `unlockedAt` | Date/Time (nil until unlocked) |

Private mirror of verified invite-unlock progress so it synchronises across
the owner's devices. The source of truth is the set of **accepted CKShare
participants** of the campaign's room — never share-button taps.

#### `FocusRoom` (custom zone `FocusGlobeRoomsZone`, root record of the CKShare)

| Field | Type |
|---|---|
| `roomPublicID` | String |
| `ownerPublicID` | String |
| `title` | String |
| `skyID` | String |
| `createdAt` | Date/Time |
| `expiresAt` | Date/Time (optional) |
| `maximumParticipants` | Int(64) — app enforces 8 |
| `status` | String — `lobby` / `active` / `ended` / `closed` |
| `allowsLateJoin` | Int(64) (0/1) |
| `requiresReadyState` | Int(64) (0/1) |
| `purpose` | String — `flight` / `skyUnlock` |
| `startedAt` | Date/Time (optional; owner sets on start — every device computes its local countdown from this shared timestamp) |
| `schemaVersion` | Int(64) |

#### `RoomParticipant` (same custom zone; `parent` reference → its `FocusRoom`)

Record name: `participant-<roomID>-<publicID>` (idempotent upsert).

| Field | Type |
|---|---|
| `roomPublicID` | String |
| `publicID` | String |
| `displayName` | String |
| `balloonSkinID` | String |
| `countryCode` | String (optional) |
| `joinedAt` | Date/Time |
| `status` | String — `joined` / `ready` / `flying` / `left` |
| `readyAt` | Date/Time (optional) |
| `activeSessionID` | String (optional) |
| `lastHeartbeatAt` | Date/Time (optional) |

#### `RoomFlightSession` (same custom zone; `parent` reference → its `FocusRoom`)

| Field | Type |
|---|---|
| `roomPublicID` | String |
| `sessionID` | String |
| `publicID` | String |
| `startedAt` | Date/Time |
| `expectedEndAt` | Date/Time (optional — nil = Infinite Mode) |
| `lastHeartbeatAt` | Date/Time |
| `isPaused` | Int(64) (0/1) |
| `completedAt` | Date/Time (optional) |
| `focusedSeconds` | Int(64) (optional) |
| `completionState` | String (optional) |

### Public database

#### `PublicProfile` — record name = `publicID`

| Field | Type |
|---|---|
| `publicID` | String |
| `displayName` | String (anonymous alias — never the onboarding name) |
| `balloonSkinID` | String |
| `countryCode` | String (optional) |
| `isDiscoverable` | Int(64) (0/1) |
| `allowsFriendRequests` | Int(64) (0/1) |
| `createdAt` | Date/Time |
| `updatedAt` | Date/Time |

#### `SkyPresence` — record name = `publicID` (ONE record per user, updated in place)

| Field | Type |
|---|---|
| `publicID` | String |
| `sessionID` | String |
| `skyID` | String |
| `mode` | String — `publicSky` (private rooms are NOT published here) |
| `roomPublicID` | String (optional; unused for public flights) |
| `startedAt` | Date/Time |
| `expectedEndAt` | Date/Time (optional — nil = Infinite Mode, shown as "Infinite focus") |
| `lastHeartbeatAt` | Date/Time (heartbeat ≈ every 45 s; stale after 120 s) |
| `isPaused` | Int(64) (0/1) |
| `focusCategory` | String (preset title only — no free text) |
| `balloonSkinID` | String |
| `displayName` | String |
| `countryCode` | String (optional) |
| `acceptsInvites` | Int(64) (0/1) |
| `updatedAt` | Date/Time |

#### `FriendRequest` — record name = `req_<senderPublicID>_<recipientPublicID>` (deterministic)

| Field | Type |
|---|---|
| `requestID` | String |
| `senderPublicID` | String |
| `recipientPublicID` | String |
| `senderDisplayName` | String |
| `senderBalloonSkinID` | String |
| `createdAt` | Date/Time |
| `status` | String — `pending` / `accepted` / `declined` / `cancelled` |
| `updatedAt` | Date/Time |

#### `FriendConnection` — record name = `conn_<min(publicID)>_<max(publicID)>` (deterministic, ordered)

| Field | Type |
|---|---|
| `connectionID` | String |
| `participantA` | String (lexicographically smaller publicID) |
| `participantB` | String (larger publicID) |
| `createdAt` | Date/Time |
| `status` | String — `active` |
| `updatedAt` | Date/Time |

### Shared database

Nothing is created here directly. When a recipient accepts a room's CKShare
invitation URL, CloudKit materialises the owner's zone in the recipient's
**shared** database: the accepted `FocusRoom`, its `RoomParticipant` /
`RoomFlightSession` children, and the `cloudkit.share` (CKShare) record.
The app enumerates `sharedCloudDatabase.allRecordZones()` to find joined rooms.

CKShare configuration used by the app:
- `CKShare.SystemFieldKey.title` = `"FocusGlobe Flight"` (safe, no personal data)
- `publicPermission = .readWrite` — **deliberate engineering call** so that
  anyone the owner sends the link to can join with one tap (link-based join,
  no per-person addressing). Access still requires possession of the URL;
  the room enforces its own 8-participant limit and the owner can close the
  room at any time (which deletes the root and invalidates the share).
  An expired/deleted share surfaces in-app as
  *"This Focus Room is no longer available."*

---

## 3. Indexes you must create manually (CloudKit Dashboard → Schema → Indexes)

CloudKit Dashboard: select the record type → *Add Index*. `QUERYABLE` for
predicate fields, `SORTABLE` where noted. In **Development** first; promote
with the schema.

```
PublicProfile.publicID              QUERYABLE
PublicProfile.isDiscoverable        QUERYABLE

SkyPresence.skyID                   QUERYABLE
SkyPresence.lastHeartbeatAt         QUERYABLE + SORTABLE
SkyPresence.publicID                QUERYABLE
SkyPresence.updatedAt               QUERYABLE + SORTABLE

FriendRequest.senderPublicID        QUERYABLE
FriendRequest.recipientPublicID     QUERYABLE
FriendRequest.status                QUERYABLE
FriendRequest.createdAt             QUERYABLE + SORTABLE

FriendConnection.participantA       QUERYABLE
FriendConnection.participantB       QUERYABLE
FriendConnection.status             QUERYABLE

FocusRoom.roomPublicID              QUERYABLE
FocusRoom.status                    QUERYABLE
FocusRoom.expiresAt                 QUERYABLE

RoomParticipant.roomPublicID        QUERYABLE
RoomParticipant.publicID            QUERYABLE
RoomParticipant.status              QUERYABLE

RoomFlightSession.roomPublicID      QUERYABLE
RoomFlightSession.publicID          QUERYABLE
RoomFlightSession.lastHeartbeatAt   QUERYABLE + SORTABLE

SkyUnlockCampaign.skyID             QUERYABLE
SkyUnlockCampaign.ownerPublicID     QUERYABLE
```

Additionally, for every record type above also add the system field
`recordName` as `QUERYABLE` (the Dashboard's *metadata indexes* section) —
CloudKit requires it for `records(matching:)` queries that page.

> The app's public queries are: `SkyPresence` by `skyID` +
> `lastHeartbeatAt > now-120s`; `FriendRequest` by `recipientPublicID`/
> `senderPublicID` + `status == "pending"`; `FriendConnection` by
> `participantA`/`participantB` + `status == "active"`. If one of the indexes
> above is missing, exactly those calls fail server-side.

## 4. Subscriptions (created by the app, listed for reference)

- Public DB `CKQuerySubscription` — `FriendRequest` with
  `recipientPublicID == <me>` (fires on create/update; silent push,
  `shouldSendContentAvailable = true`), ID `friend-requests-<publicID>`.
- Shared DB `CKDatabaseSubscription` — ID `shared-db-changes`
  (silent push on any shared-zone change → room refresh).

Silent pushes require the **Push Notifications** capability and the
`remote-notification` background mode (already in the target), and are
best-effort — the app also refreshes on foreground and on a 35 s poll during
online flights, so nothing depends on push delivery.

## 5. Security roles (CloudKit Dashboard → Schema → Security Roles)

Public database record types — set for `PublicProfile`, `SkyPresence`,
`FriendRequest`, `FriendConnection`:

| Role | Create | Read | Write |
|---|---|---|---|
| **World** | — | ✅ | — |
| **Authenticated** | ✅ | ✅ | — |
| **Creator** | ✅ | ✅ | ✅ |

Rationale:
- Any signed-in user can create their own records and read others (needed to
  see pilots, look up profiles, and send requests).
- Only the **creator** can modify/delete a record — nobody can edit another
  pilot's profile or presence.
- Note the one intentional consequence: a `FriendRequest` is created by the
  sender, so the recipient "accepts" by creating the `FriendConnection` and
  the sender's device reconciles request status (the app already treats the
  connection record as the source of truth, so a stale `pending` request is
  harmless and is cleaned up by the sender).

Private and shared databases need no role setup — private records are
owner-only by definition, and shared records are governed by each CKShare's
participant permissions.

## 6. Exact Dashboard checklist (do these in order)

1. Sign in at <https://icloud.developer.apple.com/dashboard> → container
   `iCloud.com.mobitegames.FocusGlobe` → **Development**.
2. Run the app once on a simulator/device signed into iCloud and open an
   Online surface (e.g. toggle *Appear in Public Skies*, start an Online
   flight) so the record types are auto-created — or create the record types
   above by hand.
3. Add **every index** from §3 (including the `recordName` metadata indexes).
4. Set the **security roles** from §5 on the four public record types.
5. Two-account test (see the release checklist in the repo report).
6. **Deploy Schema Changes… → Production** manually before the App Store
   build. Re-check the indexes exist in Production after promotion.

## 7. Privacy summary (for the Privacy Policy update)

- FocusGlobe Online stores only: a random `publicID`, an editable anonymous
  alias, a balloon-skin ID, an optional device-region country code, focus
  session timing (start/expected end/heartbeat), a focus **category** title,
  and friend/room relationships between anonymous IDs.
- Never stored or uploaded: Apple ID, email, phone number, real name,
  onboarding answers, precise location, contacts (the contact picker runs
  out-of-process; a chosen contact only pre-fills a local share sheet), or
  any CloudKit internal user identifier.
- Contacts permission is requested only when the user taps *Invite from
  Contacts*, with a pre-permission explanation; denial keeps every share
  path available.
- *Settings → FocusGlobe Online → Delete Online Data* removes the public
  profile, presence, friend requests/connections, owned rooms (closing their
  shares), subscriptions, the private identity record, and the local online
  cache — local flights, coins and streaks are untouched.
