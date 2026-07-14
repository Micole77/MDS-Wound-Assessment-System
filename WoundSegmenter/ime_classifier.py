import os
import cv2
import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np
from PIL import Image
from torchvision import transforms, models


DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
TARGET_SIZE = 224
WEIGHTS_PATH = os.path.join(os.path.dirname(__file__), "SSL_IME_Round3_0.70_F1Moist.pth")


class ProposedMultiTaskModel(nn.Module):
    def __init__(self):
        super(ProposedMultiTaskModel, self).__init__()

        self.backbone = models.efficientnet_b0(
            weights=models.EfficientNet_B0_Weights.IMAGENET1K_V1
        )

        num_ftrs = self.backbone.classifier[1].in_features
        self.backbone.classifier = nn.Identity()

        self.head_inf = nn.Sequential(
            nn.Linear(num_ftrs, 512),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(512, 2)
        )

        self.head_moist = nn.Sequential(
            nn.Linear(num_ftrs, 512),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(512, 3)
        )

        self.head_edge = nn.Sequential(
            nn.Linear(num_ftrs, 512),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(512, 2)
        )

    def forward(self, x):
        features = self.backbone(x)
        out_inf = self.head_inf(features)
        out_moist = self.head_moist(features)
        out_edge = self.head_edge(features)
        return out_inf, out_moist, out_edge


def resize_with_padding(image, target_size=224):
    h, w = image.shape[:2]
    scale = min(target_size / w, target_size / h)
    new_w, new_h = int(w * scale), int(h * scale)

    resized = cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_CUBIC)

    canvas = np.zeros((target_size, target_size, 3), dtype=np.uint8)
    x_off = (target_size - new_w) // 2
    y_off = (target_size - new_h) // 2

    canvas[y_off:y_off + new_h, x_off:x_off + new_w] = resized
    return canvas


def preprocess_for_ime(pil_image, combined_mask):
    """
    Match your SSL preprocessing:
    1. Apply wound mask to suppress background
    2. Crop wound bounding area from mask
    3. Resize with padding to 224x224
    """

    image_rgb = np.array(pil_image.convert("RGB"))

    if combined_mask is None:
        raise ValueError("combined_mask is None")

    if combined_mask.shape[:2] != image_rgb.shape[:2]:
        combined_mask = cv2.resize(
            combined_mask,
            (image_rgb.shape[1], image_rgb.shape[0]),
            interpolation=cv2.INTER_NEAREST
        )

    combined_mask = combined_mask.astype(np.uint8)

    masked_img = cv2.bitwise_and(
        image_rgb,
        image_rgb,
        mask=combined_mask
    )

    rows = np.any(combined_mask, axis=1)
    cols = np.any(combined_mask, axis=0)

    if not np.any(rows) or not np.any(cols):
        raise ValueError("Empty wound mask. Cannot crop wound region for IME classification.")

    y_min, y_max = np.where(rows)[0][[0, -1]]
    x_min, x_max = np.where(cols)[0][[0, -1]]

    cropped = masked_img[y_min:y_max, x_min:x_max]
    processed = resize_with_padding(cropped, TARGET_SIZE)

    return processed


inference_transform = transforms.Compose([
    transforms.ToPILImage(),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    )
])


INF_LABELS = ["Non-Infected", "Infected"]
MOIST_LABELS = ["Dry", "Moderate", "Wet"]
EDGE_LABELS = ["Advancing", "Not Advancing"]


_model = None


def load_ime_model():
    global _model

    if _model is not None:
        return _model

    if not os.path.exists(WEIGHTS_PATH):
        raise FileNotFoundError(f"IME model weights not found at {WEIGHTS_PATH}")

    model = ProposedMultiTaskModel().to(DEVICE)
    state_dict = torch.load(WEIGHTS_PATH, map_location=DEVICE)
    model.load_state_dict(state_dict)
    model.eval()

    _model = model
    return _model


def predict_ime(pil_image, combined_mask):
    model = load_ime_model()

    processed_img = preprocess_for_ime(pil_image, combined_mask)
    input_tensor = inference_transform(processed_img).unsqueeze(0).to(DEVICE)

    with torch.no_grad():
        out_inf, out_moist, out_edge = model(input_tensor)

        # Apply temperature scaling to calibrate confidence scores
        T_INF = 3.2051
        T_MOIST = 2.6764
        T_EDGE = 1.8236

        prob_inf = F.softmax(out_inf / T_INF, dim=1)
        prob_moist = F.softmax(out_moist / T_MOIST, dim=1)
        prob_edge = F.softmax(out_edge / T_EDGE, dim=1)

        conf_inf, pred_inf = torch.max(prob_inf, dim=1)
        conf_moist, pred_moist = torch.max(prob_moist, dim=1)
        conf_edge, pred_edge = torch.max(prob_edge, dim=1)

    return {
        "infection_label": INF_LABELS[pred_inf.item()],
        "infection_conf": round(conf_inf.item(), 4),
        "moisture_label": MOIST_LABELS[pred_moist.item()],
        "moisture_conf": round(conf_moist.item(), 4),
        "edge_label": EDGE_LABELS[pred_edge.item()],
        "edge_conf": round(conf_edge.item(), 4),
    }