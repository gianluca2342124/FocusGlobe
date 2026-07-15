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
| **Private** | `FocusIdentity`, `CrewMember`, `SkyUnlockCampaign`, pre-share `FocusRoom` + children (custom zone `FocusGlobeRoomsZone`) | Only the record owner |
| **Public** | `PublicProfile`, `SkyPresence`, `FriendRequest`, `FriendResponse`, `PilotReport` | See ownership matrix (§3) |
| **Shared** | Accepted `FocusRoom`, `RoomParticipant`, `RoomFlightSession`, plus the `cloudkit.share` (CKShare) records | Explicitly invited share participants only |

Custom zone (private database): **`FocusGlobeRoomsZone`** — required because
CKShare roots must live in a custom zone. Created lazily by
`FocusRoomService.ensureZone()`.

## 2. Private-room CKShare permission model (SECURITY-CRITICAL)

Every `FocusRoom` share is created with:

```swift
share.publicPermission = .none
```

**No private room ever uses `.readWrite` or `.readOnly` public permission.**
Access exists exclusively for explicitly invited `CKShare.Participant`s:

- **System sharing sheet** (`UICloudSharingController`, wrapped by
  `CloudSharingView`) with `availablePermissions = [.allowPrivate,
  .allowReadWrite]` — the owner picks recipients through Messages / WhatsApp /
  AirDrop; CloudKit records them as invited participants. The same sheet is
  the owner's participant management UI (remove a participant, stop sharing).
- **Contact lookup** (`FocusRoomService.addParticipant(to:email:phone:)`) —
  a deliberately picked contact's email/phone is resolved once via
  `fetchShareParticipant(withEmailAddress:/withPhoneNumber:)`, added with
  `.readWrite` participant permission, and the share is saved. The lookup
  value is never stored. If resolution fails, the app falls back to the
  system sharing sheet — never to a public link.

Consequences:
- A forwarded room URL grants an uninvited iCloud account **nothing**.
- There is **no Copy Link** action for private rooms (a raw copied URL cannot
  carry private participant authorization, so the action was removed rather
  than weakening the share).
- The root record and its CKShare are saved **together atomically** at
  creation; child records (`RoomParticipant`, `RoomFlightSession`) stay in
  the same custom zone with `parent` set to the room root, so share
  participants can read/write them per their participant permission.
- Participants leave by deleting their own participant record (and can remove
  themselves via the system share UI); the owner closes the room (status
  `closed`) or stops sharing, which invalidates the invitation
  (*"This Focus Room is no longer available."*).

## 3. Ownership matrix — who creates / reads / updates / deletes what

| Record | DB | Created by | Read by | Updated by | Deleted by |
|---|---|---|---|---|---|
| `FocusIdentity` | Private | Owner | Owner | Owner (alias) | Owner (Delete Online Data) |
| `CrewMember` | Private | Owner (each side keeps its own) | Owner | Owner | Owner (remove crew / delete data) |
| `SkyUnlockCampaign` | Private | Owner | Owner | Owner | Owner |
| `FocusRoom` (+ children pre-share) | Private zone | Owner | Owner + invited participants (via share) | Owner (status/startedAt); participants write only their own child records | Owner |
| `PublicProfile` | Public | The profiled user | Any authenticated user | Creator only | Creator only |
| `SkyPresence` | Public | The present user | Any authenticated user | Creator only | Creator only |
| `FriendRequest` | Public | **Sender** (immutable) | Sender + recipient (world-readable, see §5) | **Nobody** (immutable by design) | **Sender only** (cancel / resolved cleanup) |
| `FriendResponse` | Public | **Recipient** | Sender + recipient (world-readable, see §5) | Creator (recipient) only | Creator (recipient) only |
| `PilotReport` | Public | **Reporter** | Creator only (NOT world-readable) | Creator (reporter) only | Creator (reporter) only |
| CKShare + shared room records | Shared | Owner (share), participants (own child records) | Invited participants | Per CKShare participant permission | Owner (stop sharing); participant removes own records |

**No user ever has to modify a record another user created.** The recipient
answers a sender-owned `FriendRequest` by creating their own
`FriendResponse` (deterministic ID `resp_<requestID>`, so duplicates
collapse); request state is *derived* from request + response. After an
accepted response, **each side creates its own private `CrewMember` record**
in its own private database — there is no world-writable or shared friendship
record, and no public `FriendConnection` graph exists any more.

Crew removal: each user deletes their own `CrewMember`. No reciprocal
tombstone record is created — the other pilot simply keeps their private
entry, which can be removed on their side at any time; nothing in the app
fabricates activity for a removed connection (activity comes only from live
`SkyPresence` reads).

## 4. Creator-identity verification (anti-impersonation)

A `senderPublicID` field alone is never trusted:

- `PublicProfile`'s record name **is** the publicID, and only its creator can
  modify it (security role, §7). The profile's CloudKit
  `creatorUserRecordID` therefore binds each publicID to one real account.
- Incoming `FriendRequest`s are accepted only when the request record's
  `creatorUserRecordID` **equals** the creator of the claimed sender's
  `PublicProfile` (`FriendService.incomingRequests`). Spoofed requests are
  ignored client-side even before role enforcement.
- `FriendResponse`s are trusted only when created by the actual recipient's
  account (same check against the recipient's profile creator).
- Sky-unlock counting never reads self-reported fields at all (§6).
- `SkyPresence`/`PublicProfile` use recordName == publicID + creator-only
  write, so an attacker can neither overwrite nor duplicate someone else's
  records once they exist.

Apple ID, email, and phone numbers are never displayed in UI and never stored
in any record.

## 5. Record types & fields

### Private database

#### `FocusIdentity` — fixed record name `current-user-identity` (default zone)

| Field | Type |
|---|---|
| `publicID` | String |
| `anonymousHandle` | String |
| `createdAt` / `updatedAt` | Date/Time |
| `schemaVersion` | Int(64) |

#### `CrewMember` — record name `crew-<otherPublicID>` (default zone)

| Field | Type |
|---|---|
| `otherPublicID` | String |
| `displayName` | String (refreshed from the other pilot's PublicProfile) |
| `balloonSkinID` | String |
| `connectedAt` | Date/Time |
| `sourceRequestID` | String |
| `status` | String (`active`) |
| `updatedAt` | Date/Time |

#### `SkyUnlockCampaign` — record name `campaign-<skyID>` (default zone)

| Field | Type |
|---|---|
| `campaignID` | String |
| `ownerPublicID` | String |
| `skyID` | String |
| `requiredAcceptedUsers` | Int(64) |
| `acceptedUniquePublicIDs` | String (List) — stable CloudKit user record IDs |
| `createdAt` / `updatedAt` | Date/Time |
| `unlockedAt` | Date/Time (nil until unlocked) |

#### `FocusRoom` (custom zone `FocusGlobeRoomsZone`, CKShare root)

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
| `allowsLateJoin` / `requiresReadyState` | Int(64) (0/1) |
| `purpose` | String — `flight` / `skyUnlock` |
| `startedAt` | Date/Time (optional; owner sets on start — devices compute local countdowns from this shared timestamp) |
| `schemaVersion` | Int(64) |

#### `RoomParticipant` (same zone; `parent` → its `FocusRoom`) — record name `participant-<roomID>-<publicID>`

| Field | Type |
|---|---|
| `roomPublicID`, `publicID`, `displayName`, `balloonSkinID` | String |
| `countryCode` | String (optional) |
| `joinedAt` | Date/Time |
| `status` | String — `joined` / `ready` / `flying` / `left` |
| `readyAt`, `lastHeartbeatAt` | Date/Time (optional) |
| `activeSessionID` | String (optional) |

#### `RoomFlightSession` (same zone; `parent` → its `FocusRoom`)

| Field | Type |
|---|---|
| `roomPublicID`, `sessionID`, `publicID` | String |
| `startedAt`, `lastHeartbeatAt` | Date/Time |
| `expectedEndAt`, `completedAt` | Date/Time (optional) |
| `isPaused` | Int(64) |
| `focusedSeconds` | Int(64) (optional) |
| `completionState` | String (optional) |

### Public database

#### `PublicProfile` — record name = `publicID`

| Field | Type |
|---|---|
| `publicID`, `displayName` (anonymous alias), `balloonSkinID` | String |
| `countryCode` | String (optional) |
| `isDiscoverable`, `allowsFriendRequests` | Int(64) |
| `createdAt` / `updatedAt` | Date/Time |

#### `SkyPresence` — record name = `publicID` (ONE record per user, updated in place)

| Field | Type |
|---|---|
| `publicID`, `sessionID`, `skyID`, `mode`, `focusCategory`, `balloonSkinID`, `displayName` | String |
| `roomPublicID`, `countryCode` | String (optional) |
| `startedAt`, `lastHeartbeatAt`, `updatedAt` | Date/Time |
| `expectedEndAt` | Date/Time (optional — nil = Infinite Mode) |
| `isPaused`, `acceptsInvites` | Int(64) |

Heartbeat ≈ 45 s; stale after 120 s; remaining time interpolated locally from
`expectedEndAt` (no per-second writes). Private-room membership is NOT
published here.

#### `FriendRequest` — record name = `req_<senderPublicID>_<recipientPublicID>` (SENDER-owned, immutable)

| Field | Type |
|---|---|
| `requestID`, `senderPublicID`, `recipientPublicID` | String |
| `senderDisplayName`, `senderBalloonSkinID` | String |
| `createdAt` | Date/Time |

#### `FriendResponse` — record name = `resp_<requestID>` (RECIPIENT-owned)

| Field | Type |
|---|---|
| `responseID`, `requestID`, `senderPublicID`, `recipientPublicID` | String |
| `response` | String — `accepted` / `declined` |
| `createdAt` / `updatedAt` | Date/Time |

#### `PilotReport` — record name = `report_<reporterPublicID>_<reportedPublicID>` (REPORTER-owned, moderation)

| Field | Type |
|---|---|
| `reportID`, `reporterPublicID`, `reportedPublicID`, `reportedSessionID` | String |
| `reason` | String — closed category (`Inappropriate alias` / `Harassment or bullying` / `Spam` / `Something else`) |
| `createdAt` | Date/Time |

Anonymous IDs + a closed reason category only — never email, phone, real name
or any focus text. Deterministic record name means one reporter can't flood
the same pilot with new records. In the CloudKit Dashboard set the security
role so it is **Creator create/read/write only** (NOT World-readable) — reports
are reviewed out-of-band by the team, never surfaced to other users in-app.
Decorative pilots are not users and can never be reported.

### Shared database

Nothing is created here directly. When an **invited** participant accepts,
CloudKit materialises the owner's zone in their shared database: the accepted
`FocusRoom`, its children, and the `cloudkit.share` record. The app
enumerates `sharedCloudDatabase.allRecordZones()` to find joined rooms.

CKShare configuration used by the app:
- `CKShare.SystemFieldKey.title` = `"FocusGlobe Flight"` (no personal data)
- `publicPermission = .none` (see §2)
- Participants added with `.readWrite` participant permission so they can
  write their own `RoomParticipant`/`RoomFlightSession` records.

## 6. Invite-based Sky unlock counting (verified)

`FocusRoomService.acceptedShareParticipantIDs(for:)` is the ONLY input:

- reads the campaign room's CKShare `participants` array;
- counts only `acceptanceStatus == .accepted`;
- excludes the owner by `role == .owner`;
- deduplicates by `participant.userIdentity.userRecordID.recordName` — the
  **stable CloudKit account identity**, never display names and never
  self-written records;
- link opens, share-sheet presentations, and forwarded URLs count for
  nothing (with `.none` public permission an uninvited account cannot even
  accept);
- the same iCloud account can never count twice (set semantics), and the
  owner can never count themselves;
- reaching the target calls `AppModel.unlockSkyFromVerifiedInvites` —
  idempotent, permanent, mirrored to the private `SkyUnlockCampaign` record
  so it synchronises across the owner's devices.

## 7. Security roles (CloudKit Dashboard → Schema → Security Roles)

Public database record types:

| Record type | World | Authenticated | Creator |
|---|---|---|---|
| `PublicProfile` | Read* | Create + Read | Create/Read/Write |
| `SkyPresence` | Read* | Create + Read | Create/Read/Write |
| `FriendRequest` | Read* | Create + Read | Create/Read/Write |
| `FriendResponse` | Read* | Create + Read | Create/Read/Write |
| `PilotReport` | — (no World read) | Create only | Create/Read/Write |

\* **Justification for read access** (CloudKit public-DB roles cannot express
"only the addressed recipient may read"): profiles and presence are the
product's discoverability surface (anonymous by construction — alias, skin,
timing, category only); requests/responses must be readable by their
counterpart to derive state, and they contain nothing beyond the two
anonymous publicIDs, an alias and a skin ID. No email, phone, real name,
location, or contact data ever enters a public record. If tighter-than-world
read is required later, the request/response pair can move to a CKShare-based
one-to-one channel; that trade-off is documented here deliberately.

**No unrestricted authenticated WRITE/UPDATE exists anywhere**: only the
creator can modify or delete their records. This is exactly what makes the
request/response/crew model safe — no flow requires touching a foreign
record.

Private and shared databases need no role setup — private records are
owner-only, and shared records are governed by each CKShare's explicitly
invited participant permissions.

## 8. Indexes you must create manually (Dashboard → Schema → Indexes)

`QUERYABLE` for predicate fields, `SORTABLE` where noted; add in
**Development**, promote with the schema. Also add the system field
`recordName` as `QUERYABLE` on every type below (Dashboard metadata indexes).

```
PublicProfile.publicID              QUERYABLE
PublicProfile.isDiscoverable        QUERYABLE

SkyPresence.skyID                   QUERYABLE
SkyPresence.lastHeartbeatAt         QUERYABLE + SORTABLE
SkyPresence.publicID                QUERYABLE
SkyPresence.updatedAt               QUERYABLE + SORTABLE

FriendRequest.senderPublicID        QUERYABLE
FriendRequest.recipientPublicID     QUERYABLE
FriendRequest.createdAt             QUERYABLE + SORTABLE

FriendResponse.requestID            QUERYABLE
FriendResponse.senderPublicID       QUERYABLE
FriendResponse.recipientPublicID    QUERYABLE

PilotReport.reportedPublicID        QUERYABLE   (team review only)
PilotReport.reporterPublicID        QUERYABLE

CrewMember.otherPublicID            QUERYABLE   (private DB queries)
CrewMember.status                   QUERYABLE

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

(The former `FriendConnection` type is removed. If it was already created in
Development, delete the record type there before promoting.)

## 9. Subscriptions (created by the app, listed for reference)

- Public `CKQuerySubscription` `friend-requests-<publicID>` —
  `recipientPublicID == me` (silent, content-available).
- Public `CKQuerySubscription` `friend-responses-<publicID>` —
  `senderPublicID == me` (answers to my requests; silent).
- Shared `CKDatabaseSubscription` `shared-db-changes` (silent).

Silent pushes are best-effort; the app also refreshes on foreground and on a
35 s poll during online flights.

## 10. Exact Dashboard checklist (in order)

1. <https://icloud.developer.apple.com/dashboard> → container
   `iCloud.com.mobitegames.FocusGlobe` → **Development**.
2. Run the app once against Development (toggle *Appear in Public Skies*,
   send a friend request, create a room) so record types auto-create — or
   create them by hand per §5.
3. Add every index from §8 (including `recordName` metadata indexes).
4. Set the §7 security roles on the four public record types
   (World read, Authenticated create+read, Creator write).
5. Delete the obsolete `FriendConnection` type if present.
6. Two-account device test (see the release checklist in the repo report).
7. **Deploy Schema Changes… → Production** manually before the App Store
   build; re-verify indexes and roles in Production afterwards.

## 11. Diagnosing "Couldn't create your private room" by EXACT CKError

Room creation no longer hides the real failure. When
`FocusRoomService.createRoom` fails it logs (and never shows the user a raw
error):

```
createRoom FAILED: CKError.<name> (<rawValue>): <localizedDescription> | underlying <domain>#<code>: … | server: … | partial[<recordName>]=<name>: …
  [op=modifyRecords type=FocusRoom db=private zone=FocusGlobeRoomsZone container=iCloud.com.mobitegames.FocusGlobe purpose=flight]
```

**Read the exact error two ways:**

1. **Console.app (wired Mac):** device → filter *subsystem*
   `com.focusglobe.app`, *category* `online`, search `createRoom FAILED`.
2. **On-device (DEBUG builds):** Online Diagnostics screen → **Create test
   private room** → the exact breakdown appears in **Last room error (exact)**
   and in the log list. (This is DEBUG-only; Release users only ever see the
   friendly retry card.)

Then map the logged **CKError code** to its cause and fix:

| Logged `CKError.<name>` | Root cause | Fix |
|---|---|---|
| `unknownItem`, `invalidArguments`, `serverRejectedRequest`, or a `partialFailure` whose server message mentions *"record type… not found" / "unknown field"* | **The #1 cause on TestFlight/App Store builds: the `FocusRoom` schema exists only in the CloudKit *Development* environment, never deployed to *Production*.** Release and TestFlight builds hit **Production**; just-in-time schema does NOT run there. | In the Dashboard, **Deploy Schema Changes… → Production** (§10 step 7), then re-verify §8 indexes and §7 roles in Production. |
| `notAuthenticated` | No usable iCloud account despite a cached `.available` status. | User signs into iCloud; app already gates on `availability` and flips it via `applyOperationError`. |
| `networkUnavailable`, `networkFailure`, `serviceUnavailable` | Genuine connectivity / CloudKit outage. | Retry (the app flips availability to offline and shows the retry card). |
| `permissionFailure` | Security role/zone permission wrong, or the account can't write the private zone. | Verify §7 roles; confirm the custom zone `FocusGlobeRoomsZone` deployed to the active environment. |
| `quotaExceeded` | The owner's iCloud storage is full. | User frees iCloud space; nothing to change in the app. |
| `badContainer`, `missingEntitlement` | The CloudKit entitlement / container identifier isn't wired into the signed build. | Confirm the `iCloud.com.mobitegames.FocusGlobe` container is checked in the target's iCloud capability and in the provisioning profile. |
| `zoneNotFound`, `userDeletedZone` | The rooms zone was removed server-side between launches. | `ensureZone()` recreates it on next attempt; retry. |
| `serverRecordChanged` | A concurrent write raced the atomic save (rare for a fresh UUID root). | Retry (a new record ID is generated per attempt). |
| **Saved but `share.url == nil`** (logged as `CKShare saved but url==nil`) | The share record saved but CloudKit didn't mint an invitation URL — almost always the same Production-schema gap for the `cloudkit.share` system type, or CKSharing not enabled on the container. | Deploy the schema to Production; confirm the container supports sharing (it does by default once schema is deployed). The app deliberately treats this as a failure so the room is NEVER shown as "ready" without a real URL. |

**Development vs Production — the crux.** Creating a *custom zone* in the
private database succeeds in both environments without any schema. Saving a
record of a *custom type* (`FocusRoom`) requires that type to exist in the
environment being used. A build run from Xcode onto a device uses the CloudKit
**Development** environment (JIT creates the type on first save, so it "works
on my debug device"). A **TestFlight or App Store** build uses **Production**,
where JIT does not run — so if the schema was never promoted, the very first
`modifyRecords` fails. This is why a real iPhone with working WiFi and iCloud
still can't create a room: the account and network are fine; the **Production
schema is missing**.

**State-machine guarantee (requirement: no false "ready").** A room is only
returned — and only ever promoted to the pending/"Private room ready" state —
when the `FocusRoom` record saved, the `CKShare` saved, AND the saved share's
`url` is non-nil. Any failure throws with the exact error above; the invite
sheet then shows a retry, and the flight selector never claims a room exists.

## 12. Privacy summary (for the Privacy Policy update)

- Stored online: a random `publicID`, an editable anonymous alias, a
  balloon-skin ID, an optional device-region country code, focus-session
  timing, a focus category title, friend requests/responses between
  anonymous IDs, and room membership among explicitly invited participants.
- Never stored or uploaded: Apple ID, email, phone number, real name,
  onboarding answers, precise location, or contacts. The contact picker runs
  out-of-process; a chosen email/phone is used once to resolve a CloudKit
  share participant and is then discarded.
- Contacts permission is requested only when the user taps *Invite from
  Contacts*, after an explanation; denial keeps the system sharing sheet
  fully available.
- *Settings → FocusGlobe Online → Delete Online Data* removes the public
  profile, presence, own requests/responses, private CrewMember records,
  owned rooms (closing their shares), subscriptions, the private identity
  record, and the local online cache — local flights, coins and streaks are
  untouched.
