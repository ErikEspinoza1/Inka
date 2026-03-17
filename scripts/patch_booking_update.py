from pathlib import Path

path = Path(__file__).resolve().parents[1] / "api" / "routers" / "bookings.py"
text = path.read_text(encoding='utf-8')

old = """    for key, value in update_data.dict(exclude_unset=True).items():
        setattr(booking, key, value)
        
    db.commit()
    db.refresh(booking)
    return booking
"""

if old not in text:
    start = text.find('for key, value in update_data')
    print('OLD block not found; snippet:')
    print(text[start:start+400])
    raise SystemExit(1)

new = """    for key, value in update_data.dict(exclude_unset=True).items():
        if key == \"client_accepted\" and is_client:
            setattr(booking, key, value)
        elif key in {\"artist_accepted\", \"status\", \"price_quote\", \"booking_date\"} and is_artist:
            setattr(booking, key, value)
        else:
            raise HTTPException(status_code=403, detail=f\"Not allowed to update field: {key}\")

    # Auto-transition to accepted when both sides have agreed
    if booking.client_accepted and booking.artist_accepted:
        booking.status = models.BookingStatus.aceptado

    db.commit()
    db.refresh(booking)
    return booking
"""

path.write_text(text.replace(old, new), encoding='utf-8')
print('Replaced block successfully')
