# Privacy

AI Status does not collect, store, sell, or transmit personal information to
the developer. The app contains no analytics, advertising SDKs, crash-reporting
SDKs, accounts, or telemetry.

## Network requests

To display service health, the app connects directly over HTTPS to public
status endpoints operated by OpenAI, Anthropic, Google Cloud, Cursor,
Perplexity, and GitHub. As with any network request, those operators may receive
standard connection metadata such as your IP address, request time, and the
app's `User-Agent` string. Their respective privacy policies govern that data.

The app uses an ephemeral URL session with cookies and persistent URL caching
disabled. Responses are limited in size and are not written to disk.

## Local preferences

The selected services, refresh interval, and menu bar display preference are
stored locally using macOS `UserDefaults`. They are not sent to the developer.

## External links

Opening an official status page launches your default web browser. From that
point, the destination website and browser govern data handling.

## Contact

For privacy questions, open an issue in the project's GitHub repository. Do not
include personal or sensitive information in a public issue.
