## ADDED Requirements

### Requirement: Signed-in users can upload audio files

The system SHALL allow authenticated uploaders to upload a single audio file at a time via the web UI. Upload MUST complete and be confirmed before a share link is issued. The system SHALL NOT expose a public API—all upload endpoints are internal to the web application.

#### Scenario: Successful signed-in upload

- **WHEN** an authenticated uploader submits a valid audio file within size and format limits and their account is under the 5 GB storage cap
- **THEN** the system stores the file, records metadata (duration, format), and creates a track record linked to the uploader

#### Scenario: Unauthenticated user uses signed-in upload path

- **WHEN** an unauthenticated user attempts to upload via the signed-in upload flow
- **THEN** the system rejects the upload with an authentication required error

#### Scenario: Storage cap exceeded

- **WHEN** an authenticated uploader submits a file that would exceed their 5 GB total storage cap
- **THEN** the system rejects the upload with a clear message indicating the library is full and suggesting deletion of old tracks

### Requirement: Supported audio formats

The system SHALL accept uploads in MP3, WAV, FLAC, AAC, and OGG formats. Files with unsupported extensions or unrecognized MIME types MUST be rejected.

#### Scenario: Valid MP3 accepted

- **WHEN** an uploader submits a file with `.mp3` extension and valid MP3 content
- **THEN** the system accepts the upload

#### Scenario: Unsupported format rejected

- **WHEN** an uploader submits a file with an unsupported extension (e.g., `.zip`, `.pdf`)
- **THEN** the system rejects the upload with a clear format error message

### Requirement: Signed-in upload size limit

The system SHALL enforce a maximum upload size of 500 MB per file for signed-in uploaders. Files exceeding this limit MUST be rejected before storage.

#### Scenario: File within limit accepted

- **WHEN** an authenticated uploader submits a 200 MB WAV file
- **THEN** the system accepts the upload

#### Scenario: File exceeding limit rejected

- **WHEN** an authenticated uploader submits a file larger than 500 MB
- **THEN** the system rejects the upload with a size limit error message

### Requirement: Signed-in storage quota

The system SHALL enforce a maximum total storage of 5 GB per authenticated uploader account across all their tracks. There is no track-count cap.

#### Scenario: Upload within quota

- **WHEN** an authenticated uploader with 3 GB used submits a 1 GB file
- **THEN** the system accepts the upload

#### Scenario: Upload exceeds quota

- **WHEN** an authenticated uploader with 4.8 GB used submits a 500 MB file
- **THEN** the system rejects the upload with a storage quota error

### Requirement: Track title on upload

The system SHALL allow the uploader to set a display title during upload. If no title is provided, the system MUST default to the original filename (without extension).

#### Scenario: Custom title provided

- **WHEN** an authenticated uploader uploads a file and sets the title to "Summer Mix v3"
- **THEN** the track record stores "Summer Mix v3" as the display title

#### Scenario: Title omitted

- **WHEN** an authenticated uploader uploads `final_master.wav` without specifying a title
- **THEN** the track record stores "final_master" as the display title

### Requirement: Upload progress feedback

The system SHALL display upload progress to the uploader during file transfer.

#### Scenario: Progress shown during upload

- **WHEN** an uploader begins uploading a large file
- **THEN** the UI shows a progress indicator until the upload completes or fails

### Requirement: Upload session with same-ticket retry

The system SHALL issue a short-lived `upload_id` when an upload begins. If the file reaches storage but the confirm step fails, the uploader MUST be able to retry confirmation using the same `upload_id` without re-uploading the file.

#### Scenario: Confirm fails, retry succeeds

- **WHEN** an uploader's file is stored in R2 but the confirm request fails, and the uploader retries confirm with the same `upload_id`
- **THEN** the system creates the track record without requiring a new file upload

#### Scenario: In-progress session blocks concurrent upload

- **WHEN** an uploader has an in-progress upload session that has not been confirmed or abandoned
- **THEN** the system blocks starting a new upload until the session completes, fails, or times out (15 minutes)

### Requirement: Duration from browser with fallback

The system SHALL accept duration reported by the browser during upload confirm. If duration is missing, the playback page MUST fall back to reading duration from the `<audio>` element metadata.

#### Scenario: Browser reports duration on confirm

- **WHEN** an uploader confirms an upload and the browser reports a duration of 222 seconds
- **THEN** the track record stores duration as 222 seconds (or equivalent milliseconds)

#### Scenario: Duration missing at confirm

- **WHEN** an uploader confirms an upload without a browser-reported duration
- **THEN** the track record is created with unknown duration and the playback page displays duration once the audio element loads metadata

### Requirement: Format compatibility warnings at upload

The system SHALL display a warning at upload time when the user selects a format with known browser compatibility risks (e.g., OGG on Safari). The upload MUST still be accepted if the format is in the supported list.

#### Scenario: OGG upload warning

- **WHEN** an uploader selects an `.ogg` file for upload
- **THEN** the UI displays a warning that OGG may not play on Safari or iPhone and suggests MP3 or WAV for broadest compatibility

### Requirement: Orphaned upload cleanup

The system SHALL run a background sweeper that deletes R2 objects with no matching track record after a safe waiting period. Orphaned uploads MUST NOT count toward anonymous IP quotas or signed-in storage quotas.

#### Scenario: Orphan cleaned up

- **WHEN** a file exists in R2 from an upload session that was never confirmed and is older than the sweeper waiting period
- **THEN** the sweeper deletes the R2 object
