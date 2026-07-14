# VerdaSense Architecture

This document gives a high-level overview of how the app is structured and how data flows between the UI, BLoC layers, repositories, and the backend (Supabase + external segmentation service).

## 1. High-level layers

- **Presentation (Flutter UI)**  
  - Located under `lib/screens/**/views` and `lib/components`.  
  - Uses `BlocBuilder` / `BlocListener` to react to state changes and render widgets.

- **State management (BLoC)**  
  - Located under `lib/blocs/**` and `lib/screens/**/blocs`.  
  - Each feature (auth, upload, analysis, comparison, home/past records) has its own BLoC with:
    - `Event` classes (`*_event.dart`)
    - `State` classes (`*_state.dart`)
    - `Bloc` class (`*_bloc.dart`) that handles events and emits new states.

- **Repositories (data access)**  
  - Located under `packages/*_repository/lib/src`.  
  - Abstract interfaces (`wound_repo.dart`, `home_repo.dart`, `user_repo.dart`) define what the app needs (e.g. `getWounds()`, `saveWoundWithResults`, `signIn`, `fetchHomeData`).  
  - Concrete implementations (`SupabaseWoundsRepo`, `SupabaseUsersRepo`, `SupabaseHomeRepo`) contain the actual Supabase and HTTP logic.

- **Backend services**
  - **Supabase** for authentication, Postgres database, and file storage (bucket `wound-images`).  
  - **External segmentation service** (Hugging Face / Gradio) for wound segmentation and tissue classification.

## 2. Application startup

Entry point: `lib/main.dart`

1. **Load environment variables** via `flutter_dotenv` from `.env`.  
2. **Initialize Supabase** with `SUPABASE_URL` and `SUPABASE_KEY`.  
3. **Read inference backend URL** from `WOUND_SEGMENTATION_BASE_URL` (with a default).  
4. Create a `SupabaseClient` and pass it plus the inference base URL into `MyApp`.

`MyApp` (`lib/app.dart`):

- Creates instances of:
  - `SupabaseUsersRepo` (auth + user profile)
  - `SupabaseWoundsRepo` (wound storage + segmentation + comparisons), configured with the injected `inferenceBaseUrl`
- Exposes these repositories via `MultiRepositoryProvider`.
- Sets up top-level BLoCs:
  - `AuthenticationBloc` – tracks authentication state (`authenticated`, `unauthenticated`, `unknown`).
  - `ThemeBloc` – manages light/dark theme mode.
  - `AnalysisBloc` – subscribes to wound data for the analysis tab.
- Renders `MyAppView`, which wires Material theming and top-level navigation (sign-in vs main shell).

## 3. Authentication flow

Files:

- `lib/blocs/authentication_bloc/*`
- `packages/user_repository/lib/src/supabase_users_repo.dart`
- `lib/screens/auth/**`

Flow:

1. **Sign-in / Sign-up UI** (`sign_in_screen.dart`, `sign_up_screen.dart`) sends events to `SignInBloc` / `SignUpBloc`.  
2. `SignInBloc` / `SignUpBloc` call `SupabaseUsersRepo`:
   - `signIn(email, password)` → `supabase.auth.signInWithPassword`
   - `signUp(myUser, password)` → `supabase.auth.signUp` + `setUserData` in `users` table.
3. `SupabaseUsersRepo.user` exposes a **stream of `MyUser?`** based on `supabase.auth.onAuthStateChange`.  
4. `AuthenticationBloc` listens to that stream:
   - If `MyUser` is not `MyUser.empty` → emit `AuthenticationState.authenticated(user)`.
   - If `MyUser.empty` or session null → emit `AuthenticationState.unauthenticated()`.
5. `MyAppView` and `AppShell` use `BlocBuilder<AuthenticationBloc, AuthenticationState>` to:
   - show `SignInScreen` when unauthenticated,
   - show the main `AppShell` when authenticated.

## 4. Upload flow (capture → bounding boxes → inference → save)

Files:

- UI: `lib/screens/upload/views/*`
- BLoC: `lib/screens/upload/blocs/upload_bloc.dart` (+ `upload_event.dart`, `upload_state.dart`)
- Repository: `SupabaseWoundsRepo` in `packages/wound_repository/lib/src/supabase_wounds_repo.dart`

Flow:

1. **User selects source** (camera or gallery) in `UploadMainScreen` → `UploadSourceSelected` event.  
2. **User captures/selects an image** → `UploadImageCaptured` event stores the image file in `UploadState`.  
3. **User draws bounding boxes** on the scaled preview in `bounding_box_screen.dart`.  
4. When user taps “Confirm”:
   - UI dispatches `UploadBoundingBoxesConfirmed` and finally `UploadSaved` with the list of drawn `Rect`s (UI coordinates).
5. In `UploadBloc._onSaved`:
   - Reads original image bytes and decodes original width/height.
   - Uses `convertUiBoxesToOriginal` to map UI-space bounding boxes to **original image pixel coordinates**.
   - Builds `List<BoundingBoxModel>` from the converted `Rect`s.
   - Generates a unique `imageName` (timestamp-based).
   - Calls `woundRepository.getSegmentationMask(...)` with the image file, image name, and boxes.
6. `SupabaseWoundsRepo.getSegmentationMask`:
   - Uploads the image to the external segmentation service (`_uploadUrl`), passing bounding boxes.
   - Polls `_segmentationApiUrl` for the result (Server-Sent Events).
   - Parses confidence scores and throws if no box has sufficient confidence (> 0.80).
   - Downloads overlay, mask, and tissue images as bytes.
   - Returns an `InferenceResult` (overlayBytes, maskBytes, tissueBytes, scores).
7. On successful inference, `UploadBloc` calls `woundRepository.saveWoundWithResults(...)`:
   - `SupabaseWoundsRepo.saveWoundWithResults`:
     - Uploads:
       - Original image → `wound-images/{userId}/original_wound/{imageName}`
       - Overlay → `wound-images/{userId}/overlay_wound/{imageName}_overlay.webp`
       - Mask → `wound-images/{userId}/segmentation_mask/{imageName}_mask.webp`
       - Tissue overlay → `wound-images/{userId}/tissue_classification/{imageName}_tissue.webp`
     - Inserts a record into `wounds` table with `user_id`, `image_url` (the base name), `bounding_boxes`, and `pixelsPerCm` if available.
8. `UploadBloc` emits `UploadStatus.success` or `UploadStatus.error` with a message to update the UI.

## 5. Analysis flow (latest wound + history)

Files:

- BLoC: `lib/screens/analysis/blocs/analysis_bloc.dart`
- UI: `lib/screens/analysis/views/analysis_results_screen.dart`
- Repository: `SupabaseWoundsRepo.getWounds`, `getOverlayUrl`, `getTissueUrl`

Flow:

1. When `AnalysisBloc` is created in `MyApp`, it immediately dispatches `AnalysisStarted`.  
2. `_onStarted` subscribes to `woundRepository.getWounds()`:
   - A **realtime stream** from Supabase `wounds` table filtered by `user_id`, ordered by `created_at DESC`.  
3. Each time a new list of wounds arrives:
   - `AnalysisBloc` identifies:
     - `latestWound` = first element in the list.
     - `recentWounds` = up to the first 2 wounds.
   - For each recent wound, it fetches signed URLs in parallel:
     - `getOverlayUrl(originalImageName)`
     - `getTissueUrl(originalImageName)`
   - Builds:
     - `recentWoundsOverlayUrls` (map: `imageName -> overlayUrl`)
     - `recentWoundsTissueUrls` (map: `imageName -> tissueUrl`)
   - Extracts `latestOverlayUrl` / `latestTissueUrl` from those maps.
4. Emits `AnalysisStatus.success` with:
   - `latestWound`, `latestOverlayUrl`, `latestTissueUrl`
   - `recentWounds` + their overlay/tissue URL maps, for the analysis UI to render.

## 6. Home & past records

Files:

- `lib/screens/home/views/home_screen.dart`, `past_records_screen.dart`, `app_shell.dart`
- BLoCs: `home_bloc`, `past_records_bloc`
- Repositories: `SupabaseHomeRepo`, `SupabaseWoundsRepo`

Flow:

- **Home screen**:
  - `HomeBloc` uses `SupabaseHomeRepo.fetchHomeData()`, which simply returns a `HomeModel` containing the `Stream<List<WoundImageModel>>` from `woundRepository.getWounds()`.
  - UI can show real-time updates of recent wounds on the home tab.

- **Past records**:
  - `PastRecordsBloc` subscribes directly to `woundRepository.getWounds()`.
  - On each update:
    - Sorts wounds by `createdAt` descending.
    - For each wound, tries to fetch `getTissueUrl(originalImageName)` and builds a `tissueUrls` map.
  - Emits `PastRecordsStatus.success` with the sorted wounds and any available tissue URLs for visualization.

## 7. Comparison flow (progress tracking)

Files:

- BLoC: `lib/screens/comparison/blocs/comparison_bloc.dart` (+ events, state)
- UI: `compare_progress_screen.dart`, `comparison_results_screen.dart`, `comparison_history_screen.dart`
- Repository: `SupabaseWoundsRepo` methods:
  - `getOverlayUrl`, `getMaskUrl`, `getTissueUrl`
  - `saveComparison`
  - `getComparisons`
  - `getWoundsByImageNames`

Flow:

1. **Available wounds for comparison**:
   - `ComparisonStarted` causes `ComparisonBloc` to subscribe to `getWounds()` and filter wounds that have an available overlay URL (`getOverlayUrl(...)` succeeds).
   - Emits `ComparisonStatus.success` with `availableWounds`.

2. **User selects two wounds (A & B)**:
   - `ComparisonWoundASelected` / `ComparisonWoundBSelected` update `woundA` and `woundB` in state.

3. **Run comparison** (`ComparisonCompareRequested`):
   - If either selection is null → emit error message.
   - Determine chronological order:
     - `baselineWound` = older; `targetWound` = newer (based on `createdAt`).
   - Fetch URLs in parallel:
     - Overlay, mask, tissue for both baseline and target wounds.
   - If any mask missing → throw error.
   - Call `_processComparison(baselineMaskUrl, targetMaskUrl)`:
     - Downloads mask images.
     - Centers each wound mask on a fixed 1024×1024 canvas.
     - Offloads heavy pixel processing to an isolate (`processComparisonTask`):
       - Counts white pixels for each mask.
       - Computes size change: \((\text{new} - \text{old}) / \text{old} \times 100\%\).
       - Generates an overlay PNG visualizing healed (green) vs remaining (red) areas.
   - Save comparison via `saveComparison(...)`:
     - Uploads optional overlay PNG to storage (`overlay_mask` folder).
     - Inserts a row into `wound_comparisons` with `wound_a_image_name`, `wound_b_image_name`, dates, `size_change_pct`, and `overlay_path`.
   - Emit `ComparisonStatus.success` with:
     - `previousWound`, `currentWound`
     - All related URLs (overlay/mask/tissue)
     - `woundSizeChange` and `comparisonDate`.

4. **Load from history** (`ComparisonLoadFromHistory`):
   - Uses `getWoundsByImageNames([woundAImageName, woundBImageName])`.
   - Resolves all URLs again from storage.
   - Emits a state similar to a freshly run comparison so the UI can re-render past results.

## 8. Data model & Supabase schema (summary)

From the code, the app expects roughly the following shapes in Supabase:

- **Table: `users`**
  - `user_id` (PK / UUID, matches `auth.users.id`)
  - `email` (text)
  - `name` (text)

- **Table: `wounds`**
  - `id` (PK)
  - `user_id` (FK → `auth.users.id`)
  - `image_url` (text) – base image name, used to locate files in storage.
  - `bounding_boxes` (JSONB) – list of bounding box objects (see `bbox_entity.dart`).
  - `pixelsPerCm` (numeric, nullable) – calibration metadata for real-world size.
  - `created_at` (timestamptz, default `now()`).

- **Table: `wound_comparisons`**
  - `id` (PK)
  - `user_id` (FK → `auth.users.id`)
  - `wound_a_image_name` (text) – previous/baseline wound image name.
  - `wound_b_image_name` (text) – current/target wound image name.
  - `previous_date` (timestamptz, nullable)
    - Typically `created_at` of baseline wound.
  - `current_date` (timestamptz, nullable)
    - Typically `created_at` of target wound.
  - `size_change_pct` (numeric) – percent change in wound area.
  - `overlay_path` (text, nullable) – storage path for comparison overlay PNG.
  - `created_at` (timestamptz, default `now()`).

- **Storage bucket: `wound-images`**
  - For each user (`{userId}`) the app writes:
    - `original_wound/{imageName}` – original uploaded image.
    - `overlay_wound/{imageName}_overlay.webp` – segmentation overlay.
    - `segmentation_mask/{imageName}_mask.webp` – binary mask image.
    - `tissue_classification/{imageName}_tissue.webp` – tissue classification overlay.
    - `overlay_mask/{woundA}_{woundB}_{timestamp}_overlay_mask.png` – comparison overlay (if generated).

Keep this document up to date if you change any flows or schema, so future maintainers can quickly understand how everything fits together.

