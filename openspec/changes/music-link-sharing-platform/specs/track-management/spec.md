## ADDED Requirements

### Requirement: Uploader track library

The system SHALL provide authenticated uploaders with a library page listing all tracks they have uploaded, ordered by most recent first. Anonymous uploads MUST NOT appear in any library.

#### Scenario: View library

- **WHEN** an authenticated uploader navigates to their library
- **THEN** the system displays a list of their tracks with title, duration, upload date, and share link

#### Scenario: Empty library

- **WHEN** an authenticated uploader with no uploads navigates to their library
- **THEN** the system displays an empty state with a prompt to upload their first track

#### Scenario: Anonymous tracks not in library

- **WHEN** an authenticated uploader views their library
- **THEN** no anonymous or temporary tracks appear in the list

### Requirement: Copy share link from library

The system SHALL allow uploaders to copy a track's share URL from the library with a single action.

#### Scenario: Copy link

- **WHEN** an authenticated uploader clicks "Copy link" for a track in their library
- **THEN** the share URL is copied to the clipboard and the UI confirms the copy

### Requirement: Rename track

The system SHALL allow authenticated uploaders to rename their own tracks at any time from the library. The share URL slug MUST NOT change when a title is renamed.

#### Scenario: Rename own track

- **WHEN** an authenticated uploader changes a track title from "final_master" to "Summer Mix v3" in their library
- **THEN** the track record updates the display title and the playback page shows "Summer Mix v3"

#### Scenario: Cannot rename another user's track

- **WHEN** an authenticated uploader attempts to rename a track owned by a different uploader
- **THEN** the system rejects the request with a forbidden error

#### Scenario: Share URL unchanged after rename

- **WHEN** an authenticated uploader renames a track
- **THEN** the share URL slug remains the same

### Requirement: Delete track

The system SHALL allow uploaders to permanently delete their own signed-in tracks. Deletion MUST remove the audio file from storage, invalidate the share URL (404), and retire the slug permanently. Deletion MUST free the track's storage from the uploader's 5 GB quota.

#### Scenario: Delete own track

- **WHEN** an authenticated uploader confirms deletion of a track they own
- **THEN** the track record and stored audio file are removed, the share URL returns 404, and the slug is retired

#### Scenario: Cannot delete another user's track

- **WHEN** an authenticated uploader attempts to delete a track owned by a different uploader
- **THEN** the system rejects the request with a forbidden error

#### Scenario: Storage quota freed on delete

- **WHEN** an authenticated uploader with 4 GB used deletes a 500 MB track
- **THEN** their available storage quota increases by 500 MB

### Requirement: Upload new track from library

The system SHALL provide an upload action accessible from the library page so uploaders can add new tracks without navigating elsewhere.

#### Scenario: Upload from library

- **WHEN** an authenticated uploader clicks "Upload" from their library
- **THEN** the system presents the upload form and, on success, adds the new track to the library list

### Requirement: Storage usage displayed in library

The system SHALL display the uploader's current storage usage relative to the 5 GB account cap in the library.

#### Scenario: Storage usage shown

- **WHEN** an authenticated uploader with 2.3 GB of tracks views their library
- **THEN** the UI displays storage usage (e.g., "2.3 GB of 5 GB used")
