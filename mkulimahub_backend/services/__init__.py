from sqlalchemy.orm import Session
import numpy as np
import pandas as pd
from sklearn.cluster import DBSCAN

import models
from config import EARTH_RADIUS_KM, MAX_DISTANCE_KM


def run_clustering_algorithm(db: Session, target_crop: str = "All"):
    query = db.query(models.User).filter(
        models.User.role == "farmer",
        models.User.hub_id == None,
        models.User.latitude.isnot(None),
        models.User.longitude.isnot(None)
    )

    if target_crop != "All":
        query = query.filter(models.User.main_crops.ilike(f"%{target_crop}%"))

    independent_farmers = query.all()
    if not independent_farmers:
        return 0

    data = []
    for f in independent_farmers:
        if f.main_crops:
            primary_crop = f.main_crops.split(',')[0].strip().title()
            data.append({
                "id": f.id,
                "lat": float(f.latitude),
                "lon": float(f.longitude),
                "crop": primary_crop,
                "ward": f.ward or "Regional"
            })

    if not data:
        return 0

    df = pd.DataFrame(data)
    total_hubs_created = 0

    epsilon = MAX_DISTANCE_KM / EARTH_RADIUS_KM

    unique_crops = df['crop'].unique()

    for current_crop in unique_crops:
        crop_df = df[df['crop'] == current_crop].copy()

        if len(crop_df) < 2:
            continue

        coords = np.radians(crop_df[['lat', 'lon']].values)
        dbscan = DBSCAN(eps=epsilon, min_samples=2, algorithm='ball_tree', metric='haversine').fit(coords)
        crop_df['cluster'] = dbscan.labels_

        for cluster_id in crop_df['cluster'].unique():
            if cluster_id == -1:
                continue

            cluster_farmers = crop_df[crop_df['cluster'] == cluster_id]
            ward_name = cluster_farmers.iloc[0]['ward']
            hub_name = f"{ward_name} {current_crop} Co-op"

            new_hub = models.Hub(
                name=hub_name,
                crop=current_crop,
                center_latitude=float(cluster_farmers['lat'].mean()),
                center_longitude=float(cluster_farmers['lon'].mean())
            )
            db.add(new_hub)
            db.flush()

            for farmer_id in cluster_farmers['id']:
                db.query(models.User).filter(models.User.id == farmer_id).update({"hub_id": new_hub.id})

            total_hubs_created += 1

    db.commit()
    return total_hubs_created
