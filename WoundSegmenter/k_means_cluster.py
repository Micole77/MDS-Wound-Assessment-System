from typing import Any
import cv2
import numpy as np
from sklearn.cluster import MiniBatchKMeans
from sklearn.metrics import silhouette_score
from scipy.spatial.distance import cdist

class KMeansClusterer:
    def __init__(self, max_clusters: int = 3, sample_size: int = 50000, l_weight: float = 0.3):
        self.max_clusters = max_clusters
        self.sample_size = sample_size
        self.l_weight = l_weight

        # Reference Colors (L, A, B)
        self.REF_LAB = np.array([
            [20, 128, 128],    # Necrotic (Idx 0)
            [130, 170, 130],   # Granulation (Idx 1)
            [200, 128, 170]    # Slough (Idx 2)
        ])
        
        self.REF_NAMES = ['Necrotic', 'Granulation', 'Slough']

        self.TISSUE_MAP = {
            'Slough': {'id': 1, 'color': [255, 255, 0]},
            'Granulation': {'id': 2, 'color':[255, 0, 0]},
            'Necrotic': {'id': 3, 'color': [0, 0, 0]},
        }

    def _preprocess_features(self, lab_pixels):
        # Convert the image data from integers (uint8, 0-255) to floating point numbers (float32)
        pixels = lab_pixels.astype(np.float32)
        
        # Select all rows for 0th column, then multiply the value in that column by the l_weight
        # l_weight is the shadow suppression factor --> how important the L channel is
        pixels[:, 0] *= self.l_weight
        return pixels

    def cluster(self, wound_image: np.ndarray, mask: np.ndarray):
        print("\n" + "="*40)
        print(" [START] K-Means Clustering Process")
        print("="*40)

        # 1. Preprocessing
        if mask.ndim == 3:
            mask = mask[:, :, 0]    # Select all rows & columns but only the 0th color channel
        
        blurred_img = cv2.GaussianBlur(wound_image, (5, 5), 0)      # Smooth the sparkles (tiny white dots from flash reflection) out
        lab_image = cv2.cvtColor(blurred_img, cv2.COLOR_RGB2Lab)    # Convert to LAB
        
        wound_indices = np.where(mask > 0)          # Find the coordinates (y, x) of every white pixel (where the wound is)
        wound_pixels = lab_image[wound_indices]     # Extract the wound region out
        n_pixels = wound_pixels.shape[0]            # Original image: (100, 100, 3), wound_pixels: (1000, 3)
        
        print(f"[STEP 1] Data Extraction")
        print(f"  > Total Wound Pixels: {n_pixels}")

        if n_pixels == 0:
            return wound_image

        # 2. Weighting
        weighted_pixels = self._preprocess_features(wound_pixels)

        # 3. Sampling
        if n_pixels > self.sample_size:
            indices = np.random.choice(n_pixels, self.sample_size, replace=False)
            training_data = weighted_pixels[indices]
            print(f"  > Sampling: Reduced {n_pixels} -> {self.sample_size} pixels for training.")
        else:
            training_data = weighted_pixels
            print(f"  > Sampling: Using all {n_pixels} pixels.")

        # 4. Model Selection
        best_kmeans = None
        best_score = -1.0
        best_k = 1
        
        # Variance check on A & B channel
        chromatic_var = np.var(training_data[:, 1:], axis=0).sum()
        print(f"\n[STEP 2] Variance Check")
        print(f"  > Chromatic Variance (A+B): {chromatic_var:.2f}")
        
        if chromatic_var > 95.0:
            print(f"  > Variance is high enough. Testing K=2 to K={self.max_clusters}...")
            
            # Finding Best K (2 or 3)
            for k in range(2, self.max_clusters + 1):
                kmeans = MiniBatchKMeans(n_clusters=k, batch_size=256, random_state=42, n_init=3)
                labels = kmeans.fit_predict(training_data)
                
                try:
                    score = silhouette_score(training_data, labels, sample_size=1000)
                except ValueError: 
                    score = 0
                
                print(f"    [TEST] K={k} -> Silhouette Score: {score:.4f}")
                
                # SELECTION LOGIC DEBUGGING
                if score > 0.25:
                    if score > best_score:
                        print(f"       -> ACCEPTED. (Reason: {score:.4f} >= {best_score:.4f})")
                        best_score = score
                        best_kmeans = kmeans
                        best_k = k
                    else:
                        print(f"       -> REJECTED. (Reason: {score:.4f} < {best_score:.4f})")
                else:
                    print(f"       -> REJECTED. (Score too low)")

        # Fallback
        if best_kmeans is None:
            print("\n[RESULT] Variance/Score too low. Fallback to K=1.")
            best_kmeans = MiniBatchKMeans(n_clusters=1, random_state=42).fit(training_data)
        else:
            print(f"\n[RESULT] Selected Best Model: K={best_k}")

        # 5. Prediction
        all_labels = best_kmeans.predict(weighted_pixels)       # a list of labels of every wound pixels -> [0, 1, 1, 2, ...]
        weighted_centroids = best_kmeans.cluster_centers_
        
        # 6. Un-weight
        real_centroids = weighted_centroids.copy()
        real_centroids[:, 0] /= self.l_weight

        # 7. Mapping
        print(f"\n[STEP 3] Mapping Clusters to Tissues")
        mapped_labels_flat = self._map_clusters_to_tissues(all_labels, real_centroids)

        # 8. Reconstruction
        clustered_mask = np.zeros_like(mask, dtype=np.uint8)    # Create a blank canvas the exact same size as the original photo
        clustered_mask[wound_indices] = mapped_labels_flat      # Take the first number from the mapped_labels_flat list into first coord & so on
        
        clustered_mask = cv2.medianBlur(clustered_mask, 5)                              # smoothing out the noise
        clustered_mask = cv2.bitwise_and(clustered_mask, clustered_mask, mask=mask)     # boundary enforcement

        # Apply the color of the tissues based on their ids
        overlay = wound_image.copy()
        for _, props in self.TISSUE_MAP.items():
            overlay[clustered_mask == props['id']] = props['color']

        # Add transparency (60% original photo, 40% tissues' colors)
        blended = cv2.addWeighted(wound_image, 0.6, overlay, 0.4, 0)
        print("="*40 + "\n")
        return blended

    def _map_clusters_to_tissues(self, labels, centroids):
        # Debug: Show raw centroid data
        for i, c in enumerate(centroids):
            print(f"  > Cluster {i} Centroid (LAB): [{c[0]:.1f}, {c[1]:.1f}, {c[2]:.1f}]")
        
        # Shrink L by 50% during matching so Color (A&B channel) is 2x more important
        match_weight = np.array([0.5, 1.0, 1.0])
        w_centroids = centroids * match_weight  # Weight the Centroids
        w_refs = self.REF_LAB * match_weight    # Weight the Reference Colors

        # Calculate the minimum distance from every cluster to every reference colour
        dists = cdist(w_centroids, w_refs, metric='euclidean')
        closest_ref_indices = np.argmin(dists, axis=1)
        
        print(f"  > Initial Assignments (Indices): {closest_ref_indices}")
        
        # --- CONFLICT RESOLUTION ---
        unique_assignments = np.unique(closest_ref_indices)
        
        if len(unique_assignments) < len(centroids):
            print("  > [!] CONFLICT DETECTED: Multiple clusters mapped to same tissue.")
            
            # Case K=2
            if len(centroids) == 2 and closest_ref_indices[0] == closest_ref_indices[1]:
                dup_tissue = self.REF_NAMES[closest_ref_indices[0]]
                print(f"    > Conflict Type: Both K=2 clusters mapped to '{dup_tissue}'")

                # Identify which cluster is Darker/ Lighter
                # Sort the indices based on the lightness of centroid
                if centroids[0][0] < centroids[1][0]:
                    idx_dark = 0
                    idx_light = 1
                else:
                    idx_dark = 1
                    idx_light = 0

                avg_lightness = (centroids[0][0] + centroids[1][0]) / 2.0
                print(f"    > Action: Splitting based on Average Lightness ({avg_lightness})")
                
                # Dynamic Decision based on Lightness Threshold
                if avg_lightness < 60.0:
                    print(f"    -> Low Lightness detected: Splitting into Necrotic + Granulation")
                    closest_ref_indices[idx_dark] = 0   # Necrotic (Black)
                    closest_ref_indices[idx_light] = 1  # Granulation (Red)
                else:
                    print(f"    -> High Lightness detected. Splitting into Granulation + Slough")
                    closest_ref_indices[idx_dark] = 1   # Granulation (Red)
                    closest_ref_indices[idx_light] = 2  # Slough (Yellow)
            
            # Case K=3
            elif len(centroids) == 3:
                print("    > Conflict Type: K=3 Overlap. Running Greedy Assignment...")
                
                # Create 9 tuples (3 clusters x 3 tissues)
                flat_dists = []
                for r in range(3): 
                    for c in range(3): 
                        flat_dists.append((dists[r,c], r, c))
                
                # Sort the tuples based on their distance (smallest first)
                flat_dists.sort(key=lambda x: x[0])
                
                assigned_clusters = set()
                assigned_tissues = set()
                new_indices = [0, 0, 0]
                
                for d, r, c in flat_dists:
                    if r not in assigned_clusters and c not in assigned_tissues:
                        print(f"      -> Assigning Cluster {r} to {self.REF_NAMES[c]} (Dist={d:.1f})")
                        new_indices[r] = c
                        assigned_clusters.add(r)
                        assigned_tissues.add(c)
                closest_ref_indices = np.array(new_indices)

        # Create the Look-Up Table (LUT)
        print("  > Final Mapping:")
        
        # Create a small & empty array of zeroes with the clsuter's size
        # E.g. K=3, so labels will be 0, 1, 2
        # np.max(labels) -> 2
        # +1 so the array's length is 3 -> lut = [0, 0, 0]
        lut = np.zeros(int(np.max(labels)) + 1, dtype=np.uint8)
        
        # E.g. closest_ref_indices -> [1, 2, 0] = Cluster 0 is Reference 1 (Granulation) and so on
        # cluster_idx = 0, ref_idx = 1
        for cluster_idx, ref_idx in enumerate[Any](closest_ref_indices):
            tissue_name = self.REF_NAMES[ref_idx]                       # Get the tissue name from REF_NAMES
            lut[cluster_idx] = self.TISSUE_MAP[tissue_name]['id']       # Get the id of that tissue from TISSUE_MAP
            print(f"    -> Cluster {cluster_idx} ==> {tissue_name}")

        # Replace every number in the labels with the value in the lut
        return lut[labels]