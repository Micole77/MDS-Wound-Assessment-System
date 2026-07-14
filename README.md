# MDS Wound Assessment System (Handover Repository)

This repository contains the complete handover package for the chronic wound assessment project, incorporating the Flutter mobile app, Python inference backend, and all machine learning notebooks and model checkpoints.

## Repository Structure

*   `VerdaSense/` — **Mobile Application:** A Flutter client displaying IME (Infection, Moisture, Edge) classification and side-by-side progression tracking over time.
*   `WoundSegmenter/` — **Inference Backend:** Python Gradio server running MobileSAM segmentation and temperature-calibrated IME classification. Hosted live on [Hugging Face Spaces](https://huggingface.co/spaces/Micole07/TIMENet).
*   `notebooks/` — **Model Training:** Cleaned Jupyter Notebooks outlining both Supervised and Semi-Supervised Learning pipelines. *(Configured by default to run on Google Colab with paths pointing to `/content/drive/MyDrive/Wound_Assessment/`)*
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
2.  **External Datasets:** Open the [Shared Datasets Folder](PASTE_SHARED_FOLDER_LINK_HERE) on Google Drive/OneDrive, download the following ZIP files, and extract them into their respective directories:
    *   `segmented_images.zip` $\rightarrow$ Extract into `data/segmented_images/`
    *   `original_data_and_mask.zip` $\rightarrow$ Extract into `data/original_data_and_mask/`
    *   `tsegnet_mask.zip` $\rightarrow$ Extract into `data/tsegnet_mask/`
3.  **Local Run:** Initialize the Android Emulator in Android Studio, configure the Dart SDK path, and execute `flutter run`.
    *   *Note on Notebook Paths:* The Jupyter notebooks are configured for Google Colab and read/write from Google Drive at `/content/drive/MyDrive/Wound_Assessment/`. If running locally, simply update the base path variable at the top of each notebook to point to your local project directory.

---

## Deployment & Live Services

*   **Live Cloud API URL:** `https://micole07-timenet.hf.space`
*   **Hugging Face Spaces Repository:** [Micole07/TIMENet](https://huggingface.co/spaces/Micole07/TIMENet)

---

## Dataset References

The model was developed, validated, and tested using the following datasets:
1.  **Baseline Labeled Dataset:** 107 expert-annotated clinical chronic wound images classified under the TIME (Infection, Moisture, Edge) framework.
2.  **Unlabeled Semi-Supervised Dataset:** Unlabeled wound dataset utilized for self-training rounds to generate pseudo-labels and bootstrap model representations.
    *   *Source:* The training dataset was obtained from the Kaggle [Wound Segmentation Images Dataset](https://www.kaggle.com/datasets/leoscode/wound-segmentation-images?resource=download).
3.  **Annotations & Folds:** Cleaned folds splits and bounding box references are located inside `data/metadata/metadata_with_folds.csv` and `data/annotations/`.

### Citations & Academic References
*   **[1]** Thomas, S. Stock pictures of wounds. *Medetec Wound Database* (2020). http://www.medetec.co.uk/files/medetec-image-databases.html
*   **[2]** Wang, C., Anisuzzaman, D.M., Williamson, V. et al. Fully automatic wound segmentation with deep convolutional neural networks. *Sci Rep* 10, 21897 (2020). https://doi.org/10.1038/s41598-020-78799-w
*   **[3]** S. R. Oota, V. Rowtula, S. Mohammed, M. Liu and M. Gupta, "WSNet: Towards An Effective Method for Wound Image Segmentation," *2023 IEEE/CVF Winter Conference on Applications of Computer Vision (WACV)*, Waikoloa, HI, USA, 2023, pp. 3233-3242, doi: [10.1109/WACV56688.2023.00325](https://ieeexplore.ieee.org/document/10030591)

