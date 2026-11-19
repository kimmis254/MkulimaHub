from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
import requests as http_requests

import models
from schemas.auth import UserProfileUpdate, UserRead
from dependencies import get_db, get_current_user

router = APIRouter()


@router.put("/users/profile", response_model=UserRead)
def update_profile(profile_data: UserProfileUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    update_data = profile_data.dict(exclude_unset=True)

    provided_lat = update_data.get("latitude")
    provided_lng = update_data.get("longitude")

    if provided_lat is None or provided_lng is None:
        ward = update_data.get("ward") or current_user.ward
        county = update_data.get("county") or current_user.county

        if ward and county:
            print(f"Asking OpenStreetMap for exact Ward: {ward}, {county}...")
            headers = {"User-Agent": "MkulimaHubApp/1.0 (Student Project)"}
            try:
                url_ward = f"https://nominatim.openstreetmap.org/search?q={ward}, {county}, Kenya&format=json&limit=1"
                ward_data = http_requests.get(url_ward, headers=headers).json()

                if ward_data:
                    update_data["latitude"] = float(ward_data[0]["lat"])
                    update_data["longitude"] = float(ward_data[0]["lon"])
                else:
                    url_county = f"https://nominatim.openstreetmap.org/search?q={county} County, Kenya&format=json&limit=1"
                    county_data = http_requests.get(url_county, headers=headers).json()
                    if county_data:
                        update_data["latitude"] = float(county_data[0]["lat"])
                        update_data["longitude"] = float(county_data[0]["lon"])
            except Exception as e:
                print(f"Geocoding API Error: {e}")

    for key, value in update_data.items():
        setattr(current_user, key, value)

    try:
        db.add(current_user)
        db.commit()
        db.refresh(current_user)
        return current_user
    except Exception as e:
        db.rollback()
        print(f"DB Error updating profile: {e}")
        raise HTTPException(status_code=500, detail="Could not update profile. Please try again.")


@router.get("/users/me", response_model=UserRead)
def get_my_profile(current_user: models.User = Depends(get_current_user)):
    return current_user


@router.delete("/users/me")
def delete_my_account(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    db.delete(current_user)
    db.commit()
    return {"message": "Account deleted successfully"}


@router.put("/users/leave-hub")
def leave_hub(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    current_user.hub_id = None
    db.commit()
    return {"message": "Successfully left the Co-op."}
