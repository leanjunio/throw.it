## ADDED Requirements

### Requirement: Unique shareable URL per track

The system SHALL generate a unique public URL for each uploaded track (signed-in or anonymous) immediately after a successful upload confirmation. The URL MUST be copyable by the uploader. Signed-in track URLs are permanent until deleted. Anonymous track URLs are valid only until the 10-minute TTL expires.

#### Scenario: Share link generated on upload

- **WHEN** an upload completes successfully
- **THEN** the system generates a unique URL in the format `https://throw.it/t/{slug}` and displays it to the uploader

#### Scenario: Share link is unique

- **WHEN** two tracks are uploaded
- **THEN** each track receives a distinct URL slug that does not collide with any other track

#### Scenario: Slug never reused

- **WHEN** a track is deleted or expires
- **THEN** its slug is permanently retired and MUST NOT be assigned to any future track

### Requirement: Public playback without authentication

The system SHALL serve a playback page at each share URL to any visitor without requiring login or an account.

#### Scenario: Listener opens share link

- **WHEN** any person navigates to a valid track share URL
- **THEN** the system renders a playback page with an audio player without prompting for authentication

#### Scenario: Invalid share link

- **WHEN** a person navigates to a URL with a slug that does not match any active track
- **THEN** the system displays a generic 404 page with the message "Track not found"

### Requirement: In-browser audio streaming with refresh on demand

The system SHALL stream the audio file to the browser's native audio player on the playback page. Playback MUST support play, pause, and seek. Stream URLs MUST use presigned R2 URLs that refresh on demand—the player fetches a new presigned URL on play and when the current URL expires.

#### Scenario: Play track

- **WHEN** a listener clicks play on the playback page
- **THEN** the system provides a fresh presigned stream URL and audio begins playing in the browser

#### Scenario: Seek within track

- **WHEN** a listener drags the playback scrubber to a different position
- **THEN** playback resumes from the selected timestamp

#### Scenario: Stream URL refresh on expiry

- **WHEN** a listener's presigned stream URL expires during a listening session
- **THEN** the player fetches a new presigned URL and playback continues without user intervention

#### Scenario: Anonymous stream URL bounded by TTL

- **WHEN** a listener requests a stream URL for an anonymous track with 2 minutes remaining on its TTL
- **THEN** the presigned URL is valid only until the track expires; after expiry, no new stream URLs are issued

### Requirement: Track metadata on playback page

The system SHALL display the track title and duration on the playback page. The upload date MUST NOT be displayed. Anonymous tracks MUST display a static expiry message (computed at page load; no live countdown timer).

#### Scenario: Metadata displayed

- **WHEN** a listener opens a valid share URL for a track titled "Demo Beat" with a duration of 3:42
- **THEN** the playback page shows "Demo Beat" and "3:42"

#### Scenario: Anonymous expiry message displayed

- **WHEN** a listener opens an anonymous track share URL with 7 minutes remaining
- **THEN** the playback page shows a static message indicating the track is temporary and will expire (e.g., "This temporary track expires 10 minutes after upload")

### Requirement: Deleted and expired tracks are inaccessible

The system SHALL return a 404 response for share URLs of tracks that have been deleted by the uploader or expired (anonymous TTL).

#### Scenario: Deleted track link

- **WHEN** a listener navigates to the share URL of a deleted signed-in track
- **THEN** the system displays a generic 404 page with the message "Track not found"

#### Scenario: Expired anonymous track link

- **WHEN** a listener navigates to the share URL of an anonymous track past its 10-minute TTL
- **THEN** the system displays a generic 404 page with the message "Track not found"

### Requirement: Open Graph metadata for link previews

The system SHALL include Open Graph meta tags on playback pages so that shared links render a rich preview in messaging apps and social platforms. The preview MUST use the track title as `og:title`, the fixed description "Listen on throw.it" as `og:description`, and a static branded throw.it image as `og:image`.

#### Scenario: Link preview in chat app

- **WHEN** a share URL is pasted into a messaging app that reads Open Graph tags
- **THEN** the preview shows the track title, the description "Listen on throw.it", and the static throw.it preview image

### Requirement: Graceful playback error for unsupported formats

The system SHALL detect when the browser cannot decode the audio format and display a clear error message instead of a silent failure. The message MUST suggest the listener ask the uploader to share in MP3 or WAV format.

#### Scenario: Unsupported format in Safari

- **WHEN** a listener on Safari opens a share URL for an OGG track and the browser cannot decode it
- **THEN** the playback page displays an error message explaining the format is not supported in this browser

### Requirement: Listen count displayed on playback page

The system SHALL display the total listen count on the public playback page for all tracks (signed-in and anonymous). The count MUST use correct pluralization ("1 listen" vs "N listens"). The count MUST be visible even when zero (e.g., "0 listens").

#### Scenario: Listen count shown on playback page

- **WHEN** a listener opens a valid share URL for a track with 12 listens
- **THEN** the playback page displays "12 listens" alongside the track title and duration

#### Scenario: Singular listen count

- **WHEN** a listener opens a valid share URL for a track with 1 listen
- **THEN** the playback page displays "1 listen"

### Requirement: Listen counted on fresh play from start

The system SHALL increment a track's listen count when a listener starts playback from the beginning of the track. A listen MUST NOT be counted when the listener resumes after pausing mid-track. A listen MUST NOT be counted when the listener scrubs back to the start and presses play during the same pass (before the track has ended naturally). A listen MUST be counted again when the listener plays from the start after the track has ended naturally and they press play for a new pass. A listen MUST be counted on each new page visit or tab that starts playback from the beginning under the same rules.

The player MUST treat `currentTime < 0.5` seconds as "at the beginning" for counting purposes. The player MUST track whether a listen has already been counted for the current pass and reset that flag when the track fires its `ended` event.

#### Scenario: First play from start counts

- **WHEN** a listener opens a share URL and clicks play while `currentTime` is less than 0.5 seconds
- **THEN** the system increments the track's listen count by 1

#### Scenario: Pause and resume does not count

- **WHEN** a listener plays a track from the start, pauses at 1:30, and clicks play again
- **THEN** the system does not increment the listen count

#### Scenario: Scrub to start mid-pass does not count

- **WHEN** a listener plays a track from the start, seeks to 2:00, seeks back to 0:00, and clicks play
- **THEN** the system does not increment the listen count

#### Scenario: Replay after track ends counts

- **WHEN** a listener plays a track from start to finish, then clicks play again from the beginning
- **THEN** the system increments the listen count by 1 for the second pass

#### Scenario: New page visit counts

- **WHEN** a listener opens a share URL in a new browser tab and clicks play from the beginning
- **THEN** the system increments the listen count by 1

### Requirement: Listen increment via server API

The system SHALL persist listen counts server-side on the track record. The playback player MUST call a server API to increment the count when a countable play occurs. The API MUST reject increments for invalid, deleted, or expired track slugs. The API MUST be callable without authentication.

#### Scenario: Increment persisted

- **WHEN** a countable play occurs for a valid track
- **THEN** the server atomically increments `listen_count` on the track record and the updated count is available on subsequent page loads

#### Scenario: Increment rejected for missing track

- **WHEN** the player attempts to increment the listen count for a slug that does not match an active track
- **THEN** the server returns an error and does not modify any record
