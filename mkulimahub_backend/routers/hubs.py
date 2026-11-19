from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
from datetime import datetime, timedelta
import numpy as np

import models
from schemas.hub import HubMessageCreate, HubMessageRead, HubPitchPayload, HubPoolCreate
from schemas.bulk_request import ProcessDeliveryPayload
from dependencies import get_db, get_current_user
from services.clustering import run_clustering_algorithm

router = APIRouter()


@router.post("/api/admin/trigger-clustering")
def admin_trigger_clustering(crop: str = "All", db: Session = Depends(get_db)):
    created = run_clustering_algorithm(db, target_crop=crop)
    return {"message": f"Successfully created {created} new permanent Hubs based on proximity and crop!"}


@router.get("/api/clusters")
def get_frozen_clusters(crop: str = None, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    query = db.query(models.Hub)
    if crop and crop != 'All':
        query = query.filter(models.Hub.crop.ilike(f"%{crop}%"))

    hubs = query.all()

    hub_ids = [h.id for h in hubs]
    all_hub_members = db.query(models.User).filter(
        models.User.hub_id.in_(hub_ids),
        models.User.role == "farmer"
    ).all()

    members_by_hub = {}
    for member in all_hub_members:
        if member.hub_id not in members_by_hub:
            members_by_hub[member.hub_id] = []
        members_by_hub[member.hub_id].append(member)

    indep_query = db.query(models.User).filter(
        models.User.latitude.isnot(None),
        models.User.longitude.isnot(None),
        models.User.hub_id == None,
        models.User.role == "farmer"
    )

    if crop and crop != 'All':
        indep_query = indep_query.filter(models.User.main_crops.ilike(f"%{crop}%"))

    independent_farmers = indep_query.all()

    final_hubs = []
    total_analyzed = len(independent_farmers)

    for h in hubs:
        hub_members = members_by_hub.get(h.id, [])
        if len(hub_members) == 0:
            continue

        total_analyzed += len(hub_members)

        final_hubs.append({
            "hub_id": h.id,
            "hub_name": h.name,
            "farmer_count": len(hub_members),
            "coordinator_id": h.coordinator_id,
            "farmers": [
                {
                    "name": f.full_name,
                    "ward": f.ward,
                    "village": f.village,
                    "crops": f.main_crops
                } for f in hub_members
            ]
        })

    indep_list = [
        {
            "name": f.full_name,
            "ward": f.ward,
            "village": f.village,
            "crops": f.main_crops
        } for f in independent_farmers
    ]

    all_squads = db.query(models.BulkRequest).filter(
        models.BulkRequest.squad_status.in_(["gathering", "voting", "active"]),
        models.BulkRequest.status != "completed"
    ).all()

    squads_db = []
    for req in all_squads:
        if req.squad_status in ["gathering", "voting"] and req.status == "Open":
            squads_db.append(req)
        elif req.squad_status == "active":
            if any(p.farmer_id == current_user.id for p in req.pledges):
                squads_db.append(req)

    active_squads_data = []

    for req in squads_db:
        has_voted = False
        if current_user:
            vote_check = db.query(models.SquadVote).filter(
                models.SquadVote.bulk_request_id == req.id,
                models.SquadVote.farmer_id == current_user.id
            ).first()
            if vote_check:
                has_voted = True

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

        active_squads_data.append({
            "id": req.id,
            "buyer_name": req.buyer_name,
            "crop_name": req.crop_name,
            "target_weight_kg": req.target_weight_kg,
            "price_per_kg": req.price_per_kg,
            "county": req.county,
            "squad_status": req.squad_status,
            "coordinator_id": req.coordinator_id,
            "deadline_time": req.deadline_time.isoformat() if getattr(req, 'deadline_time', None) else None,
            "pledges": [{"farmer_id": p.farmer_id} for p in req.pledges],
            "candidates": candidates_list,
            "has_voted": has_voted
        })

    return {
        "total_farmers_analyzed": total_analyzed,
        "total_hubs_found": len(final_hubs),
        "hubs": final_hubs,
        "independent_farmers": indep_list,
        "active_squads": active_squads_data
    }


@router.get("/api/hubs/{hub_name}/messages", response_model=List[HubMessageRead])
def get_hub_messages(hub_name: str, db: Session = Depends(get_db)):
    messages = db.query(models.HubMessage).filter(models.HubMessage.hub_name == hub_name).order_by(models.HubMessage.created_at.asc()).all()
    result = []

    for m in messages:
        msg_text = m.message
        if msg_text.startswith("POOL_REQ|"):
            parts = msg_text.split('|')
            if len(parts) >= 2:
                contract_id = int(parts[1])
                contract = db.query(models.BulkRequest).filter(models.BulkRequest.id == contract_id).first()
                if contract:
                    total_pledged = db.query(func.sum(models.Pledge.pledged_weight_kg)).filter(models.Pledge.bulk_request_id == contract_id).scalar() or 0.0
                    msg_text = f"{m.message}|{total_pledged}|{contract.status}"

        result.append({
            "id": m.id,
            "hub_name": m.hub_name,
            "message": msg_text,
            "created_at": m.created_at,
            "sender_name": m.sender.full_name if m.sender else "Unknown Farmer"
        })

    return result


@router.post("/api/hubs/{hub_name}/messages", response_model=HubMessageRead)
def post_hub_message(hub_name: str, msg: HubMessageCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    new_message = models.HubMessage(
        hub_name=hub_name,
        sender_id=current_user.id,
        message=msg.message
    )
    db.add(new_message)
    db.commit()
    db.refresh(new_message)

    return {
        "id": new_message.id,
        "hub_name": new_message.hub_name,
        "message": new_message.message,
        "created_at": new_message.created_at,
        "sender_name": current_user.full_name
    }


@router.get("/api/hubs/nearby")
def get_nearby_hubs(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.latitude is None or current_user.longitude is None:
        raise HTTPException(status_code=400, detail="Please update your profile with your location first.")

    hubs = db.query(models.Hub).all()
    if not hubs:
        return []

    kms_per_radian = 6371.0088
    hub_distances = []

    user_lat_rad = np.radians(current_user.latitude)
    user_lon_rad = np.radians(current_user.longitude)

    for hub in hubs:
        hub_lat_rad = np.radians(hub.center_latitude)
        hub_lon_rad = np.radians(hub.center_longitude)

        dlat = hub_lat_rad - user_lat_rad
        dlon = hub_lon_rad - user_lon_rad
        a = np.sin(dlat/2)**2 + np.cos(user_lat_rad) * np.cos(hub_lat_rad) * np.sin(dlon/2)**2
        c = 2 * np.arcsin(np.sqrt(a))
        distance_km = kms_per_radian * c

        hub_distances.append({
            "hub_id": hub.id,
            "hub_name": hub.name,
            "crop": hub.crop,
            "distance_km": round(distance_km, 1)
        })

    hub_distances.sort(key=lambda x: x["distance_km"])
    return hub_distances[:3]


@router.post("/api/hubs/{hub_id}/join")
def request_to_join_hub(hub_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.hub_id is not None:
        raise HTTPException(status_code=400, detail="You are already in a hub.")

    existing_req = db.query(models.HubRequest).filter(
        models.HubRequest.hub_id == hub_id,
        models.HubRequest.farmer_id == current_user.id
    ).first()

    if existing_req:
        return {"message": "You already have a pending request for this hub."}

    new_request = models.HubRequest(hub_id=hub_id, farmer_id=current_user.id, status="pending")
    db.add(new_request)
    db.commit()

    return {"message": "Request sent successfully! Waiting for coordinator approval."}


@router.get("/api/coordinator/requests")
def get_pending_requests(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    hub = db.query(models.Hub).filter(models.Hub.coordinator_id == current_user.id).first()
    if not hub:
        return []

    requests = db.query(models.HubRequest).filter(
        models.HubRequest.hub_id == hub.id,
        models.HubRequest.status == "pending"
    ).all()

    return [{
        "request_id": r.id,
        "farmer_name": r.farmer.full_name,
        "farmer_phone": r.farmer.phone_number,
        "crops": r.farmer.main_crops,
        "village": r.farmer.village
    } for r in requests]


@router.put("/api/coordinator/requests/{request_id}")
def respond_to_request(request_id: int, action: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    req = db.query(models.HubRequest).filter(models.HubRequest.id == request_id).first()

    if not req:
        raise HTTPException(status_code=404, detail="Request not found")

    hub = db.query(models.Hub).filter(models.Hub.id == req.hub_id).first()
    if hub.coordinator_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this hub.")

    if action == "approve":
        req.status = "approved"
        req.farmer.hub_id = hub.id
    elif action == "reject":
        req.status = "rejected"
    else:
        raise HTTPException(status_code=400, detail="Invalid action. Use 'approve' or 'reject'.")

    db.commit()
    return {"message": f"Farmer has been {action}d successfully."}


@router.post("/api/hubs/election/run")
def run_for_hub_coordinator(payload: HubPitchPayload, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.hub_id:
        raise HTTPException(status_code=400, detail="You must be in a Hub to run for Coordinator.")

    hub = db.query(models.Hub).filter(models.Hub.id == current_user.hub_id).first()
    if hub.coordinator_id is not None:
        raise HTTPException(status_code=400, detail="This hub already has a coordinator.")

    existing = db.query(models.HubCandidate).filter(
        models.HubCandidate.hub_id == current_user.hub_id,
        models.HubCandidate.farmer_id == current_user.id
    ).first()

    if existing:
        raise HTTPException(status_code=400, detail="You are already on the ballot!")

    new_candidate = models.HubCandidate(
        hub_id=current_user.hub_id,
        farmer_id=current_user.id,
        pitch=payload.pitch
    )
    db.add(new_candidate)
    db.commit()
    return {"message": "Candidacy submitted successfully!"}


@router.get("/api/hubs/election/ballot")
def get_election_ballot(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.hub_id:
        return {"status": "no_hub", "candidates": []}

    hub = db.query(models.Hub).filter(models.Hub.id == current_user.hub_id).first()
    if hub.coordinator_id is not None:
        return {"status": "election_over", "coordinator_id": hub.coordinator_id}

    candidates = db.query(models.HubCandidate).filter(models.HubCandidate.hub_id == hub.id).all()

    has_voted = db.query(models.HubVote).filter(
        models.HubVote.hub_id == hub.id,
        models.HubVote.voter_id == current_user.id
    ).first() is not None

    results = []
    for c in candidates:
        vote_count = db.query(models.HubVote).filter(models.HubVote.candidate_id == c.id).count()
        farmer = db.query(models.User).filter(models.User.id == c.farmer_id).first()

        results.append({
            "candidate_id": c.id,
            "farmer_name": farmer.full_name,
            "pitch": c.pitch,
            "votes": vote_count
        })

    return {
        "status": "voting_active",
        "has_voted": has_voted,
        "candidates": results
    }


@router.post("/api/hubs/election/vote/{candidate_id}")
def cast_vote(candidate_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.hub_id:
        raise HTTPException(status_code=400, detail="You must be in a Hub to vote.")

    existing_vote = db.query(models.HubVote).filter(
        models.HubVote.hub_id == current_user.hub_id,
        models.HubVote.voter_id == current_user.id
    ).first()

    if existing_vote:
        raise HTTPException(status_code=400, detail="You have already cast your vote.")

    candidate = db.query(models.HubCandidate).filter(models.HubCandidate.id == candidate_id).first()
    if not candidate:
        raise HTTPException(status_code=404, detail="Candidate not found.")

    if candidate.farmer_id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot vote for yourself. A true leader needs the community's backing!")

    vote = models.HubVote(hub_id=current_user.hub_id, voter_id=current_user.id, candidate_id=candidate_id)
    db.add(vote)
    db.commit()

    total_hub_members = db.query(models.User).filter(models.User.hub_id == current_user.hub_id).count()
    candidate_votes = db.query(models.HubVote).filter(models.HubVote.candidate_id == candidate_id).count()
    majority_threshold = (total_hub_members / 2) if total_hub_members > 2 else 0

    if candidate_votes > majority_threshold:
        hub = db.query(models.Hub).filter(models.Hub.id == current_user.hub_id).first()
        hub.coordinator_id = candidate.farmer_id
        db.commit()
        return {"message": "Vote cast! We have a winner! The election is over."}

    return {"message": "Vote cast successfully!"}


@router.post("/api/hubs/{hub_name}/pools")
def create_hub_pool(hub_name: str, payload: HubPoolCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # Give the hub pool an automatic 1-year deadline, since it's practically open-ended
    deadline = datetime.utcnow() + timedelta(days=365)
    new_pool = models.BulkRequest(
        buyer_name=f"Hub Pool: {hub_name}",
        crop_name=payload.crop_name,
        target_weight_kg=payload.target_weight_kg,
        price_per_kg=payload.price_per_kg,
        county="Hub Internal",
        status="Open",
        squad_status="gathering",
        deadline_time=deadline,
        coordinator_id=current_user.id
    )
    db.add(new_pool)
    db.commit()
    db.refresh(new_pool)

    chat_payload = f"POOL_REQ|{new_pool.id}|{payload.crop_name}|{payload.target_weight_kg}|{payload.price_per_kg}"
    chat_msg = models.HubMessage(
        hub_name=hub_name,
        sender_id=current_user.id,
        message=chat_payload
    )
    db.add(chat_msg)
    db.commit()

    return {"message": "Pool created and broadcasted!", "contract_id": new_pool.id}


@router.get("/api/hubs/deliveries")
def get_hub_deliveries(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    my_hub = db.query(models.Hub).filter(models.Hub.coordinator_id == current_user.id).first()

    active_pools = db.query(models.BulkRequest).filter(
        models.BulkRequest.squad_status.in_(["gathering", "voting", "active", "in_transit", "delivered"])
    ).all()

    results = []
    for pool in active_pools:
        is_hub_pool = pool.buyer_name and pool.buyer_name.startswith("Hub Pool:")
        is_authorized = False

        if is_hub_pool:
            if my_hub and pool.buyer_name == f"Hub Pool: {my_hub.name}":
                is_authorized = True
        else:
            if pool.coordinator_id == current_user.id:
                is_authorized = True

        if not is_authorized:
            continue

        if pool.squad_status == "gathering":
            continue

        pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == pool.id).all()
        if not pledges: continue

        roster = []
        has_pending_audit = False
        all_received = True

        for p in pledges:
            if p.status == 'pending_audit': has_pending_audit = True
            if p.status not in ['received', 'rejected', 'in_transit', 'delivered', 'completed', 'paid']: all_received = False

            farmer = db.query(models.User).filter(models.User.id == p.farmer_id).first()
            roster.append({
                "pledge_id": p.id,
                "farmer_id": farmer.id if farmer else 0,
                "farmer_name": farmer.full_name if farmer else "Unknown",
                "pledged_kg": p.pledged_weight_kg,
                "actual_kg": p.actual_weight_kg,
                "status": p.status,
                "notes": p.notes
            })

        total_pledged = sum(p.pledged_weight_kg for p in pledges if p.status != 'rejected')
        total_actual = sum((p.actual_weight_kg or 0) for p in pledges if p.status != 'rejected')

        ui_status = "delivered" if total_pledged >= pool.target_weight_kg else "in_transit"
        if has_pending_audit: ui_status = "pending_audit"
        elif all_received: ui_status = "received"

        coordinator_name = "Hub Drop-off"
        if pool.coordinator_id:
            coord_user = db.query(models.User).filter(models.User.id == pool.coordinator_id).first()
            if coord_user: coordinator_name = coord_user.full_name

        results.append({
            "squad_id": pool.id,
            "buyer_name": pool.buyer_name,
            "ward": pool.ward,
            "crop_name": pool.crop_name,
            "coordinator_name": coordinator_name,
            "total_pledged": total_pledged,
            "target_weight": pool.target_weight_kg,
            "total_actual": total_actual,
            "status": ui_status,
            "deadline_time": pool.deadline_time.isoformat() if getattr(pool, 'deadline_time', None) else None,
            "farmer_count": len([p for p in pledges if p.status != 'rejected']),
            "roster": roster
        })

    return results


@router.post("/api/hubs/deliveries/{squad_id}/process")
def process_hub_delivery(squad_id: int, payload: ProcessDeliveryPayload, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    squad = db.query(models.BulkRequest).filter(models.BulkRequest.id == squad_id).first()
    if not squad:
        raise HTTPException(status_code=404, detail="Squad not found.")

    pledges = db.query(models.Pledge).filter(models.Pledge.bulk_request_id == squad_id).all()

    if payload.action == "receive":
        actual_total = payload.actual_weight_kg or sum(p.pledged_weight_kg for p in pledges)
        pledged_total = sum(p.pledged_weight_kg for p in pledges)

        ratio = actual_total / pledged_total if pledged_total > 0 else 1.0

        for pledge in pledges:
            pledge.status = "received"
            pledge.actual_weight_kg = round(pledge.pledged_weight_kg * ratio, 2)
            pledge.notes = payload.notes or "Verified and stored at Hub."

    elif payload.action == "reject":
        for pledge in pledges:
            pledge.status = "rejected"
            pledge.notes = payload.notes or "Entire squad rejected at Hub Quality Control."

    db.commit()
    return {"message": "Squad Delivery Processed!"}
