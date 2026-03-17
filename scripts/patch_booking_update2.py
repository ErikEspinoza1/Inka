from pathlib import Path

path = Path(__file__).resolve().parents[1] / "api" / "routers" / "bookings.py"
text = path.read_text(encoding='utf-8')

start_marker = "for key, value in update_data.dict(exclude_unset=True).items():"
end_marker = "db.commit()\n    db.refresh(booking)\n    return booking"

start = text.find(start_marker)
if start == -1:
    raise SystemExit("Could not find start of update loop")

end = text.find(end_marker, start)
if end == -1:
    raise SystemExit("Could not find end of update block")

# include the end marker in replacement
end += len(end_marker)

new_block = """for key, value in update_data.dict(exclude_unset=True).items():
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
    return booking"""

new_text = text[:start] + new_block + text[end:]
path.write_text(new_text, encoding='utf-8')
print('Patched update_booking loop successfully')
