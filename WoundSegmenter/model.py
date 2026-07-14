from typing import Any
import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import transforms
from PIL import Image
import numpy as np
from mobile_sam import sam_model_registry
from peft import PeftModel

class MobileSAMFinetuner(nn.Module):
    """
    Wrapper around fine-tuned MobileSAM for wound segmentation using bounding boxes.
    """

    def __init__(self, sam_model, img_size=1024, emb_size=1024):
        super().__init__()
        self.sam = sam_model
        self.img_size = img_size
        self.emb_size = emb_size
        self.scale_factor = emb_size / img_size

    def forward(self, images: torch.Tensor, batch_bboxes: list[torch.Tensor]):
        B, C, H, W = images.shape

        with torch.no_grad():
            image_embeddings = self.sam.image_encoder(images)

        all_masks, all_iou_preds = [], []

        for i in range(B):
            image_embedding_i = image_embeddings[i].unsqueeze(0)
            
            # Prepare prompts
            boxes_i = batch_bboxes[i]
            sparse_embeddings_i, dense_embeddings_i = self.sam.prompt_encoder(
                points=None, boxes=boxes_i, masks=None
            )

            # Mask Decoder
            low_res_masks_i, iou_predictions_i = self.sam.mask_decoder(
                image_embeddings = image_embedding_i,
                image_pe = self.sam.prompt_encoder.get_dense_pe(),
                sparse_prompt_embeddings = sparse_embeddings_i,
                dense_prompt_embeddings = dense_embeddings_i,
                multimask_output = False,
            )

            # Upsample to 1024x1024
            upsampled_masks_i = F.interpolate(
                low_res_masks_i,
                size = (self.img_size, self.img_size),
                mode = "bilinear",
                align_corners = False,
            )

            all_masks.append(upsampled_masks_i)
            all_iou_preds.append(iou_predictions_i)

        return all_masks, all_iou_preds


# Util class for app.py (contains the inference logic)
class WoundSegmenter:
    """
    Handles model loading, pre/post-processing and inference call.
    """

    def __init__(self, base_model_path="./mobile_sam.pt", lora_path="./lora_image_encoder", decoder_path="./mask_decoder.pth", model_type="vit_t", img_size: int=1024):
        
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.img_size = img_size

        # Load base MobileSAM model
        print(f"Loading base MobileSAM model from {base_model_path}")
        self.sam_model = sam_model_registry[model_type](checkpoint=base_model_path)

        # Load LoRA Adapter into Image Encoder
        print(f"Loading LoRA adapters from {lora_path}")
        self.sam_model.image_encoder = PeftModel.from_pretrained(self.sam_model.image_encoder, lora_path)

        # Load Fine-Tuned Mask Decoder
        print(f"Loading fine-tuned mask decoder from {decoder_path}")
        decoder_state_dict = torch.load(decoder_path, map_location=self.device)
        self.sam_model.mask_decoder.load_state_dict(decoder_state_dict)

        # Wrap in Finetuner class
        self.model = MobileSAMFinetuner(
            sam_model=self.sam_model, img_size=img_size, emb_size=img_size
        ).to(self.device)

        # Preprocess using ImageNet statistics
        mean = (0.485, 0.456, 0.406)
        std = (0.229, 0.224, 0.225)

        self.transform = transforms.Compose([
            transforms.Resize((img_size, img_size)),
            transforms.ToTensor(),
            transforms.Normalize(mean=mean, std=std),
        ])

    # Inference call
    def predict(self, image: Image.Image, bboxes: list[list[float]], confidence_threshold: float = 0.80) -> list[np.ndarray]:
        """
        Returns:
          combined_mask: A single numpy array (uint8) where valid masks are merged.
          all_scores: A list of floats representing the confidence of each box.
        """

        # Preprocessing
        w_orig, h_orig = image.size
        
        # Resize and Normalize -> [1, 3, 1024, 1024]
        image_tensor = self.transform(image).unsqueeze(0).to(self.device)

        # Scale bounding boxes to 1024x1024
        scaled_bboxes = []
        scale_x = self.img_size / w_orig
        scale_y = self.img_size / h_orig

        for x1_orig, y1_orig, x2_orig, y2_orig in bboxes:
            x1_scaled = x1_orig * scale_x
            y1_scaled = y1_orig * scale_y
            x2_scaled = x2_orig * scale_x
            y2_scaled = y2_orig * scale_y

            scaled_bboxes.append([x1_scaled, y1_scaled, x2_scaled, y2_scaled])

        bboxes_tensor = [torch.tensor(scaled_bboxes, dtype=torch.float32, device=self.device)]
        
        # Inference
        with torch.no_grad():
            mask_list, iou_list = self.model(image_tensor, bboxes_tensor)

        # Post-processing
        # mask_list[0] shape = [num_boxes, 1, 1024, 1024]
        # We need to return a list of binary masks resized back to original resolution (w_orig, h_orig)

        final_masks = []
        all_scores = []

        # Check if any masks were detected
        if len(mask_list) > 0 and mask_list[0].numel()> 0:
            for i, low_res_mask in enumerate[Any](mask_list[0]):

                # Extract the confidence score
                # iou_list[0] is shape [Num_Boxes, 1] because multimask_output=False
                score = iou_list[0][i].item()
                all_scores.append(score)

                # Check
                if score > confidence_threshold:
                    # Interpolate to original size
                    mask_resized = F.interpolate(
                        low_res_mask.unsqueeze(0),
                        size=(h_orig, w_orig),
                        mode="bilinear",
                        align_corners=False,
                    ).squeeze().cpu().numpy()

                    binary_mask = (mask_resized > 0).astype(np.uint8)
                    final_masks.append(binary_mask)


        return final_masks, all_scores
