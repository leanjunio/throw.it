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
- **THEN** the system displays a 404 page indicating the track was not found

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

The system SHALL display the track title and duration on the playback page. The upload date MAY be displayed. Anonymous tracks MUST display remaining time until expiry.

#### Scenario: Metadata displayed

- **WHEN** a listener opens a valid share URL for a track titled "Demo Beat" with a duration of 3:42
- **THEN** the playback page shows "Demo Beat" and "3:42"

#### Scenario: Anonymous expiry countdown displayed

- **WHEN** a listener opens an anonymous track share URL with 7 minutes remaining
- **THEN** the playback page shows a visible indicator that the track will expire soon

### Requirement: Deleted and expired tracks are inaccessible

The system SHALL return a 404 response for share URLs of tracks that have been deleted by the uploader or expired (anonymous TTL).

#### Scenario: Deleted track link

- **WHEN** a listener navigates to the share URL of a deleted signed-in track
- **THEN** the system displays a 404 page indicating the track is no longer available

#### Scenario: Expired anonymous track link

- **WHEN** a listener navigates to the share URL of an anonymous track past its 10-minute TTL
- **THEN** the system displays a 404 page indicating the track is no longer available

### Requirement: Open Graph metadata for link previews

The system SHALL include Open Graph meta tags on playback pages so that shared links render a rich preview (title, description) in messaging apps and social platforms.

#### Scenario: Link preview in chat app

- **WHEN** a share URL is pasted into a messaging app that reads Open Graph tags
- **THEN** the preview shows the track title and a description indicating it is an audio track on throw.it

### Requirement: Graceful playback error for unsupported formats

The system SHALL detect when the browser cannot decode the audio format and display a clear error message instead of a silent failure. The message MUST suggest the listener ask the uploader to share in MP3 or WAV format.

#### Scenario: Unsupported format in Safari

- **WHEN** a listener on Safari opens a share URL for an OGG track and the browser cannot decode it
- **THEN** the playback page displays an error message explaining the format is not supported in this browser
