# VerdaSense

VerdaSense is a Flutter application for wound tracking and analysis using Supabase as the backend and several internal repositories (`user_repository`, `home_repository`, `wound_repository`).

This guide is written for the next maintainer so you can set up and run the project locally.

## 1. Prerequisites

- Flutter SDK installed (stable channel, any version compatible with Dart `^3.9.2`)
  - Follow the official guide: `https://docs.flutter.dev/get-started/install`
- Xcode (for iOS) and/or Android Studio + Android SDK (for Android)
- A device or emulator (iOS Simulator or Android Emulator)
- Access to the existing **Supabase** project credentials (from the previous maintainer)

Check your Flutter installation:

```bash
flutter --version
flutter doctor
```

## 2. Clone the project

```bash
git clone <REPO_URL>
cd verdasense
```

> Replace `<REPO_URL>` with the actual Git repository URL if it is not already cloned.

## 3. Environment variables (`.env`)

This project uses `flutter_dotenv` and includes `.env` as an asset (see `pubspec.yaml`), so a valid `.env` file **must** exist in the project root.

Because `.env` is git-ignored, it is **not** stored in the repository.

- **Step 1**: Ask the previous maintainer for the current `.env` file (or values).
- **Step 2**: Place the file at the project root as:

```text
verdasense/
  .env
  pubspec.yaml
  lib/
  packages/
  ...
```

The `.env` file will typically contain at least your Supabase configuration (for example, URL and anon/public key) and any other secrets required by the app.

Do **not** commit the `.env` file to git.

### 3.1 Required keys

At minimum, the app expects:

- `SUPABASE_URL` – Your Supabase project URL.
- `SUPABASE_KEY` – Supabase **anon/public** API key.
- `WOUND_SEGMENTATION_BASE_URL` – Base URL of the external wound segmentation service (e.g. Hugging Face / Gradio Space).

Example:

```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_KEY=your-anon-key
WOUND_SEGMENTATION_BASE_URL=https://your-hf-space-url
```

> If `WOUND_SEGMENTATION_BASE_URL` is not set, the app falls back to the original default URL used during development.

## 4. Install dependencies

From the project root:

```bash
flutter pub get
```

This will install:

- Flutter dependencies (e.g. `bloc`, `flutter_bloc`, `camera`, `image_picker`, `supabase_flutter`, etc.)
- Local packages:
  - `packages/user_repository`
  - `packages/home_repository`
  - `packages/wound_repository`

## 5. Running the app

### 5.1 Start an emulator or connect a device

- For Android:
  - Open Android Studio → Device Manager → Start an Android Virtual Device (AVD), **or**
  - Connect an Android phone with USB debugging enabled.
- For iOS:
  - Open Xcode → `Xcode > Settings > Platforms` to install the iOS simulator if needed.
  - Start an iOS Simulator from Xcode or `open -a Simulator`.

Verify that Flutter sees your devices:

```bash
flutter devices
```

### 5.2 Run in debug mode

From the project root:

```bash
flutter run
```

If you have multiple devices/emulators, you can select the target device in your IDE (VS Code / Android Studio) or specify the `-d` flag:

```bash
flutter run -d <device_id>
```

## 6. Project structure (high level)

Some key locations to be aware of:

- `lib/main.dart` – Flutter entry point.
- `lib/screens/home` – Home screen and app shell.
- `lib/screens/upload` – Upload flows, including image capture and bounding boxes.
- `lib/screens/analysis` – Analysis screen and related BLoC.
- `lib/screens/comparison` – Comparison screen and related BLoC.
- `packages/user_repository` – User-related data/repository logic.
- `packages/home_repository` – Home/dashboard related data/repository logic.
- `packages/wound_repository` – Wound data and Supabase integration.

The app uses the BLoC pattern (`bloc` / `flutter_bloc`) and `equatable` for state management.

For a deeper explanation of the architecture and data flow (including BLoCs, repositories, and how Supabase + the segmentation service fit together), see:

- `docs/architecture.md`

## 7. Backend and data model overview

The app relies on:

- **Supabase** for:
  - Authentication (`auth` / email-password sign in & sign up).
  - Postgres database tables:
    - `users` – user profile data (user ID, email, name).
    - `wounds` – per-wound metadata (image name, bounding boxes, pixels-per-cm, created_at).
    - `wound_comparisons` – comparison results between two wounds (size change %, dates, overlay path).
  - Storage bucket:
    - `wound-images` – holds original wound images, segmentation overlays, masks, tissue overlays, and comparison overlays.

- **External segmentation service** (Hugging Face / Gradio):
  - Receives an image + bounding boxes from the app.
  - Returns:
    - Confidence scores for each box.
    - URLs for the segmentation overlay, mask, and tissue classification images.
  - The base URL is configured via `WOUND_SEGMENTATION_BASE_URL` and injected into `SupabaseWoundsRepo`.

Key places in the code that interact with the backend:

- `lib/main.dart` – loads `.env`, initializes Supabase, and reads `WOUND_SEGMENTATION_BASE_URL`.
- `packages/user_repository/lib/src/supabase_users_repo.dart` – handles auth and user profile data in the `users` table.
- `packages/wound_repository/lib/src/supabase_wounds_repo.dart` – handles:
  - Uploading wound images and inference results to the `wound-images` bucket.
  - Reading/writing `wounds` and `wound_comparisons` tables.
  - Calling the external segmentation service.
- `packages/home_repository/lib/src/supabase_home_repo.dart` – exposes wound streams for the home dashboard.

If you change the database schema, storage paths, or external service URL, update both:

- The relevant repository code, and  
- This section (and `docs/architecture.md`) so future maintainers know the expected backend setup.

## 8. Common issues & tips

- **Missing `.env` / Supabase errors**: If the app fails early or Supabase calls fail, confirm that `.env` exists at the root, is loaded via `flutter_dotenv`, and contains valid Supabase keys.
- **Dependencies not found**: Run `flutter clean` followed by `flutter pub get` if you have dependency issues.
- **iOS build issues**: Ensure you have accepted Xcode licenses and run `pod install` inside the `ios` directory if prompted.

## 9. Next steps for the new maintainer

- Review the BLoC implementations in the `lib/screens/**/blocs` directories to understand the state management flow.
- Review the repositories in `packages/*_repository` to understand how data is fetched and stored (especially `wound_repository` for Supabase usage).
- Coordinate with the previous maintainer for:
  - Supabase project access
  - `.env` contents
  - Any API keys or external services used by the app.

Once the above setup is done, you should be able to run and continue development on VerdaSense without issues.
