from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from typing import List
from datetime import datetime, timedelta

import models
from schemas.bulk_request import (
    BulkRequestCreate, BulkRequestRead, PledgeBase, PledgeRead, PledgeUpdate
)
from dependencies import get_db, get_current_user

router = APIRouter()


@router.post("/api/buyer/contracts")
def create_bulk_contract_buyer(payload: BulkRequestCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Allows a buyer to post a new Bulk Contract to the Marketplace."""
    deadline = datetime.utcnow() + timedelta(hours=payload.deadline_hours)

    new_contract = models.BulkRequest(
        buyer_name=current_user.full_name,
        crop_name=payload.crop_name,
        target_weight_kg=payload.target_weight_kg,
        price_per_kg=payload.price_per_kg,
        county=payload.county,
        ward=payload.ward,
        urgency=payload.urgency,
        status="Open",
        deadline_time=deadline
    )

    db.add(new_contract)
    db.commit()
    db.refresh(new_contract)

    return {"message": "Contract broadcasted to the network!", "contract_id": new_contract.id}


@router.get("/api/contracts")
def get_open_contracts(county: str = None, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    query = db.query(models.BulkRequest).filter(
        models.BulkRequest.status.in_(["Open", "fulfilled"]),
        ~models.BulkRequest.buyer_name.like("Hub Pool:%")
    )
    if county: query = query.filter(models.BulkRequest.county == county)

    contracts = query.all()
    results = []

    for req in contracts:
        has_pledged = any(p.farmer_id == current_user.id for p in req.pledges)
        total_pledged = sum((p.pledged_weight_kg or 0) for p in req.pledges)

        results.append({
            "id": req.id, "crop_name": req.crop_name, "target_weight_kg": req.target_weight_kg,
            "total_pledged": total_pledged, "price_per_kg": req.price_per_kg,
            "buyer_name": req.buyer_name, "county": req.county,
            "ward": req.ward,
            "urgency": req.urgency,
            "deadline_time": req.deadline_time.isoformat() + "Z" if getattr(req, 'deadline_time', None) else None,
            "has_pledged": has_pledged
        })
    return results


@router.get("/api/my-pledges")
def get_my_pledges(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "farmer":
        raise HTTPException(status_code=403, detail="Only farmers can view delivery squads.")

    pledges = db.query(models.Pledge)\
                .options(joinedload(models.Pledge.bulk_request))\
                .filter(
                    models.Pledge.farmer_id == current_user.id,
                    ~models.Pledge.status.in_(["paid", "completed", "rejected"])
                ).all()

    result = []
    db_needs_commit = False

    for p in pledges:
        req = p.bulk_request

        if not req:
            db.delete(p)
            db_needs_commit = True
            continue

        if req.squad_status not in ["active", "voting", "fulfilled"]:
            total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == req.id).scalar() or 0.0

            if total_pledged >= req.target_weight_kg:
                unique_farmers = db.query(models.Pledge.farmer_id).filter(models.Pledge.bulk_request_id == req.id).distinct().count()

                if unique_farmers == 1:
                    req.coordinator_id = p.farmer_id
                    req.squad_status = "active"
                else:
                    req.squad_status = "voting"

                db_needs_commit = True

        squad_pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == req.id).all()
        squad_roster = []
        for sp in squad_pledges:
            farmer = db.query(models.User).filter(models.User.id == sp.farmer_id).first()
            if farmer:
                final_kg = sp.actual_weight_kg if sp.actual_weight_kg is not None else sp.pledged_weight_kg

                squad_roster.append({
                    "pledge_id": sp.id,
                    "farmer_id": farmer.id,
                    "name": farmer.full_name,
                    "pledge_kg": sp.pledged_weight_kg,
                    "actual_kg": sp.actual_weight_kg,
                    "payout_kes": final_kg * req.price_per_kg,
                    "status": sp.status,
                    "notes": sp.notes
                })

        candidates_db = db.query(models.SquadCandidate).filter(models.SquadCandidate.bulk_request_id == req.id).all()
        candidates_list = []
        for c in candidates_db:
            candidates_list.append({
                "candidate_id": c.id,
                "farmer_id": c.farmer_id,
                "farmer_name": c.farmer.full_name if c.farmer else "Unknown",
                "pitch": c.pitch,
                "votes": c.votes
            })

        has_voted = db.query(models.SquadVote).filter(
            models.SquadVote.bulk_request_id == req.id,
            models.SquadVote.farmer_id == current_user.id
        ).first() is not None

        buyer_phone = "No phone available"
        if req.buyer_id:
            buyer = db.query(models.User).filter(models.User.id == req.buyer_id).first()
            if buyer and buyer.phone_number:
                buyer_phone = buyer.phone_number

        result.append({
            "id": p.id,
            "pledged_weight_kg": p.pledged_weight_kg,
            "actual_weight_kg": p.actual_weight_kg,
            "status": p.status,
            "bulk_request": {
                "id": req.id, "buyer_name": req.buyer_name, "crop_name": req.crop_name,
                "buyer_phone": buyer_phone,
                "target_weight_kg": req.target_weight_kg, "price_per_kg": req.price_per_kg,
                "county": req.county, "ward": req.ward, "urgency": req.urgency,
                "squad_status": req.squad_status, "coordinator_id": req.coordinator_id,
                "squad_roster": squad_roster, "candidates": candidates_list, "has_voted": has_voted,
                "deadline_time": req.deadline_time.isoformat() if getattr(req, 'deadline_time', None) else None,
                "payment_status": getattr(req, 'payment_status', 'pending'),
                "payment_method": getattr(req, 'payment_method', 'pay_now')
            }
        })

    if db_needs_commit:
        db.commit()

    return result


@router.put("/api/pledges/{pledge_id}", response_model=PledgeRead)
def update_pledge(pledge_id: int, payload: PledgeUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id, models.Pledge.farmer_id == current_user.id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found.")

    try:
        pledge.pledged_weight_kg = payload.pledged_weight_kg
        db.flush()

        bulk_req = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
        total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == bulk_req.id).scalar() or 0.0

        if total_pledged < bulk_req.target_weight_kg:
            if getattr(bulk_req, 'payment_status', 'pending') != 'deposit_paid':
                bulk_req.status = "Open"
        else:
            bulk_req.status = "fulfilled"

        db.commit()
        db.refresh(pledge)
        return pledge
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to update pledge.")


@router.put("/api/qa/pledges/{pledge_id}/status")
def update_pledge_qa_status(pledge_id: int, payload: dict, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Handles the Buyer accepting or rejecting individual farmer drop-offs."""
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found.")

    farmer = db.query(models.User).filter(models.User.id == pledge.farmer_id).first()
    pool = db.query(models.BulkRequest).filter(models.BulkRequest.id == pledge.bulk_request_id).first()
    if not pool:
        raise HTTPException(status_code=404, detail="Parent contract not found.")

    new_status = payload.get("status")

    if new_status == "paid" or new_status == "completed":
        actual_kg = pledge.actual_kg if pledge.actual_kg else pledge.pledged_weight_kg
        payout_amount = actual_kg * pool.price_per_kg
        payment_method = getattr(pool, 'payment_method', 'pay_now')

        if payment_method == 'pay_now':
            if farmer and (farmer.escrow_balance or 0.0) >= payout_amount:
                farmer.escrow_balance -= payout_amount
                farmer.available_balance = (farmer.available_balance or 0.0) + payout_amount
        else:
            if farmer:
                farmer.available_balance = (farmer.available_balance or 0.0) + payout_amount

    elif new_status == "disputed" or new_status == "rejected":
        pledge.dispute_notes = payload.get("notes", "Rejected during QA inspection.")

    pledge.status = new_status
    db.commit()
    return {"message": f"Pledge QA updated to {new_status}"}


@router.delete("/api/pledges/{pledge_id}")
def delete_pledge(pledge_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id, models.Pledge.farmer_id == current_user.id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found.")

    try:
        req_id = pledge.bulk_request_id
        db.delete(pledge)
        db.flush()

        bulk_req = db.query(models.BulkRequest).filter(models.BulkRequest.id == req_id).first()

        db.query(models.SquadCandidate).filter(
            models.SquadCandidate.bulk_request_id == req_id,
            models.SquadCandidate.farmer_id == current_user.id
        ).delete()

        db.query(models.SquadVote).filter(
            models.SquadVote.bulk_request_id == req_id,
            models.SquadVote.farmer_id == current_user.id
        ).delete()

        if bulk_req.coordinator_id == current_user.id:
            bulk_req.coordinator_id = None
            bulk_req.squad_status = "voting"

        total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == req_id).scalar() or 0.0

        if total_pledged < bulk_req.target_weight_kg:
            if getattr(bulk_req, 'payment_status', 'pending') != 'deposit_paid':
                bulk_req.status = "Open"
        else:
            bulk_req.status = "fulfilled"

        if total_pledged == 0:
            bulk_req.squad_status = "gathering"
            bulk_req.coordinator_id = None
            db.query(models.SquadCandidate).filter(models.SquadCandidate.bulk_request_id == req_id).delete()
            db.query(models.SquadVote).filter(models.SquadVote.bulk_request_id == req_id).delete()

        db.commit()
        return {"message": "Pledge deleted successfully."}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to delete pledge.")


@router.put("/pledges/{pledge_id}/complete", response_model=PledgeRead)
def complete_pledge_delivery(pledge_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    pledge = db.query(models.Pledge).filter(models.Pledge.id == pledge_id).first()
    if not pledge:
        raise HTTPException(status_code=404, detail="Pledge not found")

    if current_user.role != "buyer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Security Error: Only the Corporate Buyer can verify quality and release Escrow funds."
        )

    if pledge.status != "received_at_hub":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot complete order. Current status is '{pledge.status}', but it must be 'received_at_hub' first."
        )

    pledge.status = "completed"
    db.commit()
    db.refresh(pledge)

    return pledge


@router.post("/bulk-requests/", response_model=BulkRequestRead)
def create_bulk_request(request: BulkRequestCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "buyer":
        raise HTTPException(status_code=403, detail="Only Corporate Buyers can post bulk requests.")

    deadline = datetime.utcnow() + timedelta(hours=request.deadline_hours)

    new_request = models.BulkRequest(
        buyer_id=current_user.id,
        buyer_name=current_user.full_name,
        crop_name=request.crop_name,
        target_weight_kg=request.target_weight_kg,
        price_per_kg=request.price_per_kg,
        county=request.county,
        urgency=request.urgency,
        status="Open",
        squad_status="gathering",
        deadline_time=deadline,
        payment_method="pay_on_delivery"
    )

    try:
        db.add(new_request)
        db.commit()
        db.refresh(new_request)
        return new_request
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to broadcast contract to the network.")


@router.get("/bulk-requests/")
def get_active_bulk_requests(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    requests = db.query(models.BulkRequest).filter(
        models.BulkRequest.status.in_(["Open", "fulfilled"]),
        ~models.BulkRequest.buyer_name.like("Hub Pool:%")
    ).all()

    results = []
    for req in requests:
        has_pledged = any(p.farmer_id == current_user.id for p in req.pledges)
        total_pledged = sum((p.pledged_weight_kg or 0) for p in req.pledges)

        results.append({
            "id": req.id, "crop_name": req.crop_name, "target_weight_kg": req.target_weight_kg,
            "total_pledged": total_pledged, "price_per_kg": req.price_per_kg,
            "buyer_name": req.buyer_name, "county": req.county,
            "ward": req.ward, "urgency": req.urgency,
            "deadline_time": req.deadline_time.isoformat() + "Z" if getattr(req, 'deadline_time', None) else None,
            "has_pledged": has_pledged
        })
    return results


@router.post("/bulk-requests/{request_id}/pledge", response_model=PledgeRead)
def create_pledge(request_id: int, pledge: PledgeBase, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != "farmer":
        raise HTTPException(status_code=403, detail="Only farmers can pledge.")

    bulk_req = db.query(models.BulkRequest).filter(models.BulkRequest.id == request_id).first()
    if not bulk_req:
        raise HTTPException(status_code=404, detail="Bulk request not found.")

    existing_pledge = db.query(models.Pledge).filter(
        models.Pledge.bulk_request_id == request_id,
        models.Pledge.farmer_id == current_user.id
    ).first()

    if existing_pledge:
        raise HTTPException(status_code=400, detail="You have already pledged to this request.")

    current_total = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == request_id).scalar() or 0.0

    if current_total >= bulk_req.target_weight_kg:
        raise HTTPException(status_code=400, detail="This Hub Pool is already 100% full!")

    if current_total + pledge.pledged_weight_kg > bulk_req.target_weight_kg:
        remaining = bulk_req.target_weight_kg - current_total
        raise HTTPException(status_code=400, detail=f"Cannot over-pledge. Only {remaining}kg remaining to fill the pool.")

    new_pledge = models.Pledge(
        bulk_request_id=request_id,
        farmer_id=current_user.id,
        pledged_weight_kg=pledge.pledged_weight_kg,
        status="pledged"
    )

    try:
        db.add(new_pledge)
        db.flush()

        total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == request_id).scalar() or 0.0

        if total_pledged >= bulk_req.target_weight_kg:
            bulk_req.status = "fulfilled"

            if bulk_req.buyer_name.startswith("Hub Pool:"):
                bulk_req.squad_status = "active"
            else:
                unique_farmers = db.query(models.Pledge.farmer_id).filter(models.Pledge.bulk_request_id == request_id).distinct().count()
                if unique_farmers == 1:
                    bulk_req.coordinator_id = current_user.id
                    bulk_req.squad_status = "active"
                else:
                    bulk_req.squad_status = "voting"

        db.commit()
        db.refresh(new_pledge)
        return new_pledge

    except Exception as e:
        db.rollback()
        print(f"DB Error during pledge creation: {e}")
        raise HTTPException(status_code=500, detail="Failed to process your pledge.")
