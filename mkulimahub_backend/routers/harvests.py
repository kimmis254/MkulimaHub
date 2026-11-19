from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime
import json

import models
from schemas.harvest import HarvestCreate, HarvestReadExtended
from dependencies import get_db, get_current_user

router = APIRouter()


@router.post("/harvests", status_code=status.HTTP_201_CREATED)
def create_harvest(harvest: HarvestCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "farmer":
        raise HTTPException(status_code=403, detail="Only farmers can post harvests")

    new_harvest = models.Harvest(
        farmer_id=current_user.id,
        crop_name=harvest.crop_name,
        weight_kg=harvest.weight_kg,
        price_per_kg=harvest.price_per_kg
    )

    try:
        db.add(new_harvest)
        db.commit()
        db.refresh(new_harvest)
        return {"message": "Harvest posted successfully", "id": new_harvest.id}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to post harvest to the marketplace.")


@router.get("/harvests", response_model=List[HarvestReadExtended])
def get_harvests(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    harvests = db.query(models.Harvest).filter(models.Harvest.farmer_id.isnot(None)).offset(skip).limit(limit).all()
    return harvests


@router.get("/harvests/me")
def get_my_market_listings(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    listings = db.query(models.MarketListing).filter(
        models.MarketListing.farmer_id == current_user.id,
        models.MarketListing.status == "active"
    ).order_by(models.MarketListing.created_at.desc()).all()

    results = []
    for listing in listings:
        orders_query = db.query(models.MarketOrder).filter(
            models.MarketOrder.listing_id == listing.id,
            models.MarketOrder.status == "pending"
        ).all()

        orders_list = [{
            "id": o.id, "buyer_name": o.buyer.full_name if o.buyer else "Local Buyer",
            "quantity": o.quantity_ordered, "type": o.order_type,
            "total_price": o.total_price, "status": o.status
        } for o in orders_query]

        parsed_units = []
        if listing.unit_pricing:
            if isinstance(listing.unit_pricing, str):
                try: parsed_units = json.loads(listing.unit_pricing)
                except:
                    try: parsed_units = json.loads(listing.unit_pricing.replace("'", '"'))
                    except: pass
            elif isinstance(listing.unit_pricing, list):
                parsed_units = listing.unit_pricing

        display_price = listing.price_per_kg
        display_unit = "KG"
        if not listing.is_selling_by_weight and parsed_units and len(parsed_units) > 0:
            display_price = parsed_units[0].get("price", 0)
            display_unit = parsed_units[0].get("unit_name", "Unit")

        results.append({
            "id": listing.id, "crop_name": listing.crop_name,
            "available_kg": listing.available_kg, "price_per_kg": display_price,
            "unit_type": display_unit, "is_selling_by_weight": listing.is_selling_by_weight,
            "unit_pricing": parsed_units,
            "image_base64": getattr(listing, 'image_base64', None),
            "orders": orders_list, "orders_count": len(orders_list)
        })
    return results


@router.get("/api/farmer/dashboard")
def get_farmer_dashboard(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    harvests = db.query(models.Harvest).filter(models.Harvest.farmer_id == current_user.id).all()
    total_yield = sum([h.weight_kg for h in harvests])

    orders = db.query(models.MarketOrder).join(models.MarketListing).filter(
        models.MarketListing.farmer_id == current_user.id,
        models.MarketOrder.status.in_(["pending", "processing", "in_transit", "disputed"])
    ).all()

    deliveries_list = []
    for o in orders:
        deliveries_list.append({
            "type": "solo",
            "id": o.id,
            "crop_name": o.listing.crop_name if o.listing else "Produce",
            "weight_kg": o.quantity_ordered,
            "status": o.status
        })

    return {
        "total_yield_kg": round(total_yield, 2),
        "deliveries_list": deliveries_list
    }
