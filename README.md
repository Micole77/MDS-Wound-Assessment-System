# MDS Wound Assessment System (Handover Repository)

This repository contains the complete handover package for the chronic wound assessment project, incorporating the Flutter mobile app, Python inference backend, and all machine learning notebooks and model checkpoints.

## Repository Structure

*   `VerdaSense/` — **Mobile Application:** A Flutter client displaying IME (Infection, Moisture, Edge) classification and side-by-side progression tracking over time.
*   `WoundSegmenter/` — **Inference Backend:** Python Gradio server running MobileSAM segmentation and temperature-calibrated IME classification.
*   `notebooks/` — **Model Training:** Cleaned Jupyter Notebooks outlining both Supervised and Semi-Supervised Learning pipelines.
*   `models/` — **Trained Model Checkpoints:** Saved weights (`.pth` files) for supervised baseline and semi-supervised iterations.
*   `data/` — **Data Metadata & Annotations:** Folds configurations and annotations. (Raw image datasets are stored externally on Google Drive).
*   `docs/` — **Handover Documents:** Standard handover manuals and future direction briefs.

---

## Technical Details

### 1. Temperature Calibration (Logit Scaling)
To resolve the overconfidence issue common in softmax-based classification, post-hoc temperature scaling was calibrated against the validation folds to minimize Negative Log-Likelihood (NLL). The optimal temperatures applied in `WoundSegmenter/ime_classifier.py` are:
*   Infection: $T = 3.2051$
*   Moisture: $T = 2.6764$
*   Edge: $T = 1.8236$

### 2. Preprocessing Corrections
Redundant resizing steps inside `inference_transform` were eliminated, correcting a "double-resize" interpolation artifact that introduced high-frequency ringing noise and degraded EfficientNet-B0 accuracy on production images.

---

## Setup & Handover Execution

1.  **Configure `.env`:** Copy `VerdaSense/.env.example` to `VerdaSense/.env` and update the Supabase client keys and HuggingFace API base URL.
2.  **External Datasets:** Download the datasets from the shared Drive links below, unzip them, and place them in their respective directories:
    *   [ ] [segmented_images.zip](PASTE_GOOGLE_DRIVE_LINK_HERE) (Extract into `data/segmented_images/`)
    *   [ ] [original_data_and_mask.zip](PASTE_GOOGLE_DRIVE_LINK_HERE) (Extract into `data/original_data_and_mask/`)
    *   [ ] [tsegnet_mask.zip](PASTE_GOOGLE_DRIVE_LINK_HERE) (Extract into `data/tsegnet_mask/`)
    *   [ ] [original_code_archieve.zip](PASTE_GOOGLE_DRIVE_LINK_HERE) (Extract into `original_code_archieve/`)
3.  **Local Run:** Initialize the Android Emulator in Android Studio, configure the Dart SDK path, and execute `flutter run`.
