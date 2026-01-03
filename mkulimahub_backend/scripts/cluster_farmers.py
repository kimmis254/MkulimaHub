import pandas as pd
import numpy as np
from sklearn.cluster import DBSCAN
import os

# --- CONFIGURATION ---
KMS_PER_RADIAN = 6371.0088
EPSILON_KM = 5.0 
EPSILON_RADIANS = EPSILON_KM / KMS_PER_RADIAN
MIN_FARMERS = 3  # Lowered slightly to ensure we find groups for testing

# PATHS
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_FILE = os.path.join(BASE_DIR, 'data', 'farmers_dummy.csv')
OUTPUT_FILE = os.path.join(BASE_DIR, 'data', 'farmers_clustered.csv')

def cluster_farmers():
    print("📍 Starting Smart Clustering (By Location + Crop)...")
    
    if not os.path.exists(INPUT_FILE):
        print(f"❌ Error: Input file not found at {INPUT_FILE}")
        return

    df = pd.read_csv(INPUT_FILE)
    
    # Create a new column for the Cluster ID, default to -1 (Noise)
    df['cluster_id'] = -1
    
    # Get list of all unique crops
    unique_crops = df['crop'].unique()
    
    total_clusters = 0
    
    for crop in unique_crops:
        print(f"\n🚜 Processing {crop} Farmers...")
        
        # 1. Filter: Get only farmers growing this crop
        # We work with INDICES to update the main dataframe later
        crop_indices = df[df['crop'] == crop].index
        
        if len(crop_indices) < MIN_FARMERS:
            print(f"   -> Skipping (Not enough farmers: {len(crop_indices)})")
            continue

        # 2. Get coordinates for this subset
        coords = df.loc[crop_indices, ['latitude', 'longitude']].values
        coords_radians = np.radians(coords)
        
        # 3. Run DBSCAN on this subset
        db = DBSCAN(eps=EPSILON_RADIANS, min_samples=MIN_FARMERS, algorithm='ball_tree', metric='haversine')
        db.fit(coords_radians)
        
        # 4. Assign Cluster IDs
        # We need to make these IDs unique across crops. 
        # If Maize has cluster 0, 1, 2... Beans should start at 3, 4, 5.
        labels = db.labels_
        
        # Update the main dataframe
        # We iterate through the results and assign them back
        new_labels = []
        for label in labels:
            if label == -1:
                new_labels.append(-1) # Still noise
            else:
                new_labels.append(label + total_clusters) # Shift ID to be unique
        
        df.loc[crop_indices, 'cluster_id'] = new_labels
        
        # Update total clusters count for the next loop
        num_clusters_in_crop = len(set(labels)) - (1 if -1 in labels else 0)
        total_clusters += num_clusters_in_crop
        print(f"   -> Found {num_clusters_in_crop} {crop} cooperatives.")

    # 5. Save & Summary
    print("-" * 40)
    print(f"✅ FINAL RESULTS:")
    print(f"   - Total Crop-Specific Clusters: {total_clusters}")
    noise_count = len(df[df['cluster_id'] == -1])
    print(f"   - Isolated Farmers: {noise_count}")
    
    df.to_csv(OUTPUT_FILE, index=False)
    
    # 6. Verify Logic
    if total_clusters > 0:
        # Find a valid cluster ID to show
        valid_id = df[df['cluster_id'] != -1].iloc[0]['cluster_id']
        print(f"\n🔎 Example: Farmers in Cluster #{valid_id} (Should all be same crop):")
        print(df[df['cluster_id'] == valid_id][['name', 'crop', 'latitude']].head())

if __name__ == "__main__":
    cluster_farmers()