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
2.  **External Datasets:** Download the raw segmented images and place them under `data/segmented_images/` if running the notebooks locally.
3.  **Local Run:** Initialize the Android Emulator in Android Studio, configure the Dart SDK path, and execute `flutter run`.
