import gradio as gr
from PIL import Image
import numpy as np
import json

from model import WoundSegmenter
from k_means_cluster import KMeansClusterer
from ime_classifier import predict_ime

# Model Initialization
try:
    segmenter = WoundSegmenter()
    clusterer = KMeansClusterer(max_clusters=3)
    print("MobileSAM Segmenter and K-Means Cluster are initialized successfully.")
except Exception as e:
    print(f"Error: {e}")
    segmenter = None
    clusterer = None

# Utility for converting mask array to image
def mask_array_to_image(mask_array: np.ndarray) -> Image.Image:
    """Converts a binary NumPy mask (0 or 1) into a black and white PIL Image."""
    # Scale 0/1 mask to 0/255 for black (0) and white (255)
    mask_255 = mask_array * 255
    # Convert to PIL Image in grayscale mode ('L')
    return Image.fromarray(mask_255.astype(np.uint8))

# Utility for combining mask and image for visualization
def overlay_mask_on_image(image: Image.Image, masks: list[np.ndarray]) -> Image.Image:
    """
    Creates an overlay of the masks on the original image.
    """
    # Return original image if no masks are found
    if not masks:
        return image

    # Get the height and width from the image
    expected_h, expected_w = image.size[::-1] # --> for numpy/matrix (H, W)
    original_w, original_h = image.size  # --> (W, H)

    # Ensure mask shape macthes image dimension
    first_mask_shape = masks[0].shape

    if first_mask_shape != (expected_h, expected_w):
        if first_mask_shape == (expected_w, expected_h):
            print("LOG: Transposing masks from (W, H) to (H, W)")
            masks = [mask.T for mask in masks]
        else:
            print(f"LOG: Mask shape {first_mask_shape} does not match expected image shape ({expected_h}, {expected_w})")
            raise IndexError("Mask shape mistmatch. Check mask resizing in model.py")

    # Combine masks into a single mask
    combined_mask = np.sum(masks, axis=0)
    combined_mask = np.clip(combined_mask, 0, 1).astype(np.uint8)

    # Create a colored, semi-transparent overlay
    overlay = np.zeros((expected_h, expected_w, 4), dtype=np.uint8)
    color = np.array([255, 0, 0, 150], dtype=np.uint8)
    overlay[combined_mask == 1] = color

    # Overlay the mask
    overlay_img = Image.fromarray(overlay)

    if overlay_img.size != (original_w, original_h):
        print(f"LOG: Resizing overlay {overlay_img.size} to match image {image.size}.")
        overlay_img = overlay_img.resize((original_w, original_h), Image.Resampling.NEAREST)

    # Convery image to RGBA
    image_rgba = image.convert("RGBA")

    combined = Image.alpha_composite(image_rgba, overlay_img)

    return combined.convert("RGB") # Return as RGB for the Gradio output

# Gradio Inference Function
def gradio_segmentation_api(image: Image.Image, bboxes_list: str):
    """
    Takes a PIL Image and a JSON string of bounding boxes, and returns the segmented image.
    Bboxes format: "[[x1, y1, x2, y2], [x1, y1, x2, y2], ...]"
    """

    if segmenter is None:
        raise gr.Error("Model is not initialized. Check Space logs.")
    
    try:
        # Parse the bounding boxes string into a list of lists of floats
        # Gradio UI users will enter a string; the API might send a list directly.
        if isinstance(bboxes_list, str):
            bboxes = json.loads(bboxes_list)
        elif isinstance(bboxes_list, list):
            bboxes = bboxes_list
        else:
            raise ValueError("Bounding boxes must be provided as a JSON string or list.")
            
        if not bboxes:
             raise gr.Error("Bounding boxes list cannot be empty.")
        
        import time
        
        # --- 1. SEGMENTATION INFERENCE ---
        start_seg = time.time()
        # Run the prediction using the utility class
        masks, scores = segmenter.predict(image=image, bboxes=bboxes)
        time_seg = (time.time() - start_seg) * 1000

        THRESHOLD_CHECK = 0.80

        print(f"\n--- Processing {len(scores)} Bounding Boxes")

        scores_dict = {}
        for i, score in enumerate(scores):
            # Create label for UI
            label = f"Box {i+1}"
            scores_dict[f"{label}:"] = float(score)
            
            # Print status to console/logs
            if score <= THRESHOLD_CHECK:
                print(f"[WARNING] {label} SKIPPED. Low confidence: {score:.4f} (<= {THRESHOLD_CHECK})")
            else:
                print(f"[SUCCESS] {label} Processed. Confidence: {score:.4f}")

        if not masks:
            print("[RESULT] No valid wounds detected in any bounding box.")

        if masks:
            # Combine masks into a single mask
            combined_mask = np.sum(masks, axis=0)
            combined_mask = np.clip(combined_mask, 0, 1).astype(np.uint8)
        else:
            # Create a blank black mask matching the image size
            w, h = image.size
            combined_mask = np.zeros((h, w), dtype=np.uint8)
        
        mask_image = mask_array_to_image(combined_mask)
        
        # Combine the masks with the original image for visual output
        overlay_image = overlay_mask_on_image(image, masks)

        # --- 2. K-MEANS INFERENCE ---
        start_kmeans = time.time()
        image_np = np.array(image)
        kmeans_overlay = clusterer.cluster(image_np, combined_mask)
        time_kmeans = (time.time() - start_kmeans) * 1000

        # --- 3. IME INFERENCE ---
        start_ime = time.time()
        try:
            ime_result = predict_ime(image, combined_mask)
            time_ime = (time.time() - start_ime) * 1000

            scores_dict[f"IME - Infection: {ime_result['infection_label']}"] = ime_result["infection_conf"]
            scores_dict[f"IME - Moisture: {ime_result['moisture_label']}"] = ime_result["moisture_conf"]
            scores_dict[f"IME - Edge: {ime_result['edge_label']}"] = ime_result["edge_conf"]

            print(f"[IME SUCCESS] {ime_result}")
            
            print("\n==============================================")
            print("SERVER INFERENCE TIMING REPORT:")
            print(f"Segmentation (MobileSAM): {time_seg:.2f} ms")
            print(f"Tissue Class (K-Means):   {time_kmeans:.2f} ms")
            print(f"IME Classification:       {time_ime:.2f} ms")
            print(f"Total Server Inference:   {time_seg + time_kmeans + time_ime:.2f} ms")
            print("==============================================\n")

        except Exception as ime_error:
            print(f"[IME ERROR] {ime_error}")
            scores_dict["IME - Error"] = 0.0
        
        return [scores_dict, overlay_image, mask_image, kmeans_overlay]
        
    except Exception as e:
        print(f"Inference Error: {e}")
        # Raise a Gradio error that is visible in the UI/API response
        raise gr.Error(f"Segmentation failed. Ensure Bboxes are in format [[x1, y1, x2, y2]]: {e}")


# Gradio Interface 
iface = gr.Interface(
    fn = gradio_segmentation_api,
    inputs = [
        gr.Image(type="pil", label="Input Image"),
        gr.Textbox(label="Bounding box ([[x1, y1, x2, y2], ...])")
    ],
    outputs = [
        gr.Label(label="Model Confidence Score"),
        gr.Image(type="pil", label="Overlay Image"),
        gr.Image(type="pil", label="Segmentation Mask"),
        gr.Image(type="pil", label="K-means Overlay"),
    ],
    title = "MobileSAM + K-means Wound Segmentation",
    description = "Wound Segmentation using fine-tuned Mobile SAM with bounding box prompts."
)

# Launch the app
iface.launch()