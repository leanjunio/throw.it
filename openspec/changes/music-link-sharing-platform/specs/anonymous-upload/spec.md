## ADDED Requirements

### Requirement: Anonymous users can upload audio files temporarily

The system SHALL allow unauthenticated users to upload audio files via the web UI for temporary hosting. Upload MUST complete and be confirmed before a share link is issued. Anonymous uploads MUST NOT require or create an uploader account.

#### Scenario: Successful anonymous upload

- **WHEN** an unauthenticated user submits a valid audio file within anonymous limits
- **THEN** the system stores the file, creates a track record with a 10-minute TTL, and displays the share link with clear expiry messaging

#### Scenario: Anonymous upload is fire-and-forget

- **WHEN** an anonymous upload completes successfully
- **THEN** the system provides a share link only; no management URL, library entry, or delete option is offered

### Requirement: Anonymous track TTL

The system SHALL set a 10-minute time-to-live on every anonymous track from the moment of successful upload confirmation. After expiry, the track and its share URL MUST become inaccessible (404). The TTL MUST be clearly communicated to the uploader at upload time and on the share page.

#### Scenario: Track accessible within TTL

- **WHEN** a listener opens an anonymous track share URL 5 minutes after upload
- **THEN** the system serves the playback page and the audio is playable

#### Scenario: Track expired after TTL

- **WHEN** a listener opens an anonymous track share URL 11 minutes after upload
- **THEN** the system displays a 404 page indicating the track is no longer available

#### Scenario: Expiry messaging shown to uploader

- **WHEN** an anonymous upload completes successfully
- **THEN** the UI displays the share link with a clear message that the track will be deleted in 10 minutes

### Requirement: Anonymous IP track limit

The system SHALL allow a maximum of 3 active anonymous tracks per IP address at any time. A track is considered active from confirmation until TTL expiry and deletion. When an active anonymous track expires and is deleted, its slot MUST become available again for that IP.

#### Scenario: Third active track allowed

- **WHEN** an IP address has 2 active anonymous tracks and the user uploads a third within limits
- **THEN** the system accepts the upload

#### Scenario: Fourth active track rejected

- **WHEN** an IP address already has 3 active anonymous tracks
- **THEN** the system rejects the upload with a message indicating the IP limit has been reached and slots will free when existing tracks expire

#### Scenario: Slot freed after expiry

- **WHEN** an IP address has 3 active anonymous tracks and one expires and is deleted
- **THEN** that IP may upload a new anonymous track (subject to storage quota)

### Requirement: Anonymous IP storage quota

The system SHALL enforce a maximum combined storage of 100 MB across all active anonymous tracks per IP address. Only confirmed tracks count toward this quota.

#### Scenario: Upload within IP quota

- **WHEN** an IP address has 60 MB of active anonymous tracks and the user uploads a 30 MB file
- **THEN** the system accepts the upload

#### Scenario: Upload exceeds IP quota

- **WHEN** an IP address has 90 MB of active anonymous tracks and the user uploads a 20 MB file
- **THEN** the system rejects the upload with a message indicating the 100 MB IP storage limit

### Requirement: No concurrent anonymous uploads

The system SHALL allow only one anonymous upload at a time per IP address. An in-progress upload session (including unconfirmed uploads) MUST block new anonymous uploads for up to 15 minutes.

#### Scenario: Concurrent upload blocked

- **WHEN** an IP address has an in-progress anonymous upload that has not completed or timed out
- **THEN** the system rejects a new anonymous upload attempt with a message to wait for the current upload to finish

#### Scenario: Session timeout releases block

- **WHEN** an anonymous upload session has been in-progress for more than 15 minutes without confirmation
- **THEN** the system releases the concurrent upload block for that IP

### Requirement: Anonymous uploads cannot be claimed

The system SHALL NOT provide any mechanism for anonymous uploaders to convert a temporary track into a signed-in persistent track. Users who want persistent storage MUST sign in and re-upload their file.

#### Scenario: No claim after sign-in

- **WHEN** a user who previously uploaded anonymously signs in via magic link
- **THEN** the anonymous track is not added to their library and remains on its original TTL schedule

### Requirement: Anonymous uploads use same format rules

Anonymous uploads MUST follow the same supported format list as signed-in uploads (MP3, WAV, FLAC, AAC, OGG) with the same format warnings and rejection rules.

#### Scenario: Valid format accepted anonymously

- **WHEN** an unauthenticated user submits a valid `.mp3` file within anonymous limits
- **THEN** the system accepts the upload

### Requirement: Anonymous track cleanup

The system SHALL run a background job that deletes expired anonymous tracks and their R2 objects promptly after TTL expiry. Expired anonymous slugs MUST be retired permanently (never reused).

#### Scenario: Expired anonymous track deleted

- **WHEN** an anonymous track's `expires_at` timestamp has passed
- **THEN** the cleanup job deletes the track record and R2 object, and the slug is retired

#### Scenario: Expired slug not reused

- **WHEN** an anonymous track with slug `xK9mP2qR` expires and is deleted
- **THEN** no future track may be assigned slug `xK9mP2qR`

### Requirement: Shared IP blocking acceptable for MVP

The system SHALL use the client IP address (via `X-Forwarded-For` on Vercel) for anonymous rate limiting. Shared-network blocking (offices, coffee shops) is an accepted MVP tradeoff.

#### Scenario: IP derived from proxy header

- **WHEN** an anonymous upload request arrives via Vercel with `X-Forwarded-For` set
- **THEN** the system uses that IP address for quota enforcement
