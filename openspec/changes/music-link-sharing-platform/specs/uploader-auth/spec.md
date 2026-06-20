## ADDED Requirements

### Requirement: Email magic link authentication

The system SHALL authenticate uploaders via email magic link. The uploader MUST enter their email address and click a link sent to that address to sign in. No password is required. Magic links MUST be reusable within the 15-minute expiry window (e.g., open on phone then laptop) until the uploader successfully signs in.

#### Scenario: Request magic link

- **WHEN** a user enters a valid email address and requests a sign-in link
- **THEN** the system sends a magic link to that email address

#### Scenario: Sign in via magic link

- **WHEN** a user clicks a valid, unexpired magic link
- **THEN** the system creates a session for that uploader and redirects them to their library

#### Scenario: Magic link reusable within window

- **WHEN** a user clicks a valid magic link on their phone and then clicks the same link on their laptop within 15 minutes
- **THEN** both devices successfully sign in

#### Scenario: Expired magic link

- **WHEN** a user clicks a magic link that has expired (older than 15 minutes)
- **THEN** the system rejects the link and prompts the user to request a new one

### Requirement: Session persistence

The system SHALL maintain an authenticated session for 24 hours after sign-in so uploaders can return without re-authenticating on every visit. Multiple concurrent sessions across devices MUST be allowed.

#### Scenario: Return visit within session

- **WHEN** an authenticated uploader returns to throw.it within 24 hours of their last sign-in
- **THEN** the system recognizes their session and grants access to their library without a new magic link

#### Scenario: Session expired

- **WHEN** an uploader's session has expired after 24 hours
- **THEN** the system requires a new magic link sign-in before granting access to the library

#### Scenario: Multiple device sessions

- **WHEN** an uploader signs in on a laptop and later signs in on a phone
- **THEN** both devices remain signed in until their respective sessions expire

### Requirement: Redirect if already signed in

The system SHALL detect when a user with a valid session visits the sign-in page and gently redirect them to their library without sending a new magic link email.

#### Scenario: Already signed in visits sign-in page

- **WHEN** an authenticated uploader with a valid session navigates to the sign-in page
- **THEN** the system redirects them to their library with a message indicating they are already signed in

### Requirement: Sign out

The system SHALL allow authenticated uploaders to sign out, which MUST invalidate their current session on that browser.

#### Scenario: Sign out

- **WHEN** an authenticated uploader clicks "Sign out"
- **THEN** the session is invalidated on that browser and the uploader is redirected to the public landing page

### Requirement: Authentication is optional for uploading

The system MUST NOT require authentication for all uploads. Unauthenticated users MAY upload via the anonymous temporary path. Authentication is required only for persistent storage, library access, and track management.

#### Scenario: Anonymous upload without sign-in

- **WHEN** a person without an account uploads via the anonymous path
- **THEN** the system accepts the upload without any sign-in prompt

#### Scenario: Persistent upload requires sign-in

- **WHEN** a person without an account attempts to upload via the signed-in persistent path
- **THEN** the system prompts them to sign in via magic link

### Requirement: Listeners do not need accounts

The system MUST NOT require authentication for visiting share URLs or playing audio.

#### Scenario: Anonymous listener

- **WHEN** a person without an account opens a share URL
- **THEN** the system serves the playback page without any sign-in prompt

### Requirement: Uploader account created on first sign-in

The system SHALL create an uploader record on first successful magic link sign-in for a new email address. No separate registration step is required.

#### Scenario: First sign-in creates account

- **WHEN** a user signs in via magic link with an email not previously seen
- **THEN** the system creates a new uploader record linked to that email
