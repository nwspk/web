module EventsHelper
  # The event share link: the URL shape that yields a per-event social preview
  # card. The id reaches the server (so the meta tags can name the event) while
  # the fragment scrolls to the row. A bare "#event-N" can't do the first half,
  # which is why sharing goes through here — see CLAUDE.md, "social previews".
  def event_share_path(event)
    events_path(id: event.id, anchor: event_anchor(event))
  end

  def event_share_url(event)
    events_url(id: event.id, anchor: event_anchor(event))
  end

  # DOM id of an event row, and the fragment the share link points at.
  def event_anchor(event)
    "event-#{event.id}"
  end
end
