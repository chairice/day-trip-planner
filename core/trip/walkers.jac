"""Trip planner walkers: every user's trips live under their own root.

Graph: root --> Trip --> Stop. All walkers are `:protect`, so the web,
mobile and CLI apps each act on the signed-in user's saved trips.
"""

import from core.trip.engine {
    sample_plan,
    finalize,
    attach_maps,
    ai_available,
    today,
    now,
    season_for,
    by_date,
    pick_today,
    normalize_window,
    window_label,
    fit_window
}
import from core.trip.models { plan_trip, Trip, Stop }

def:priv ai_plan(
    city: str, season: str, vibe: str, start: str, end: str
) -> dict[str, any] {
    ai = plan_trip(city, season, vibe, start, end);
    return {
        "city": ai.city,
        "tagline": ai.tagline,
        "wiki": ai.wiki,
        "style": ai.style,
        "stops": [
            {
                "time": s.time,
                "title": s.title,
                "kind": "food" if s.kind.lower() == "food" else "landmark",
                "area": s.area,
                "blurb": s.blurb,
                "tip": s.tip,
                "wiki": s.wiki,
                "options": [
                    {
                        "name": o.name,
                        "cuisine": o.cuisine,
                        "price": o.price,
                        "dish": o.dish,
                        "wiki": o.wiki
                    } for o in s.options
                ]
            } for s in ai.stops
        ]
    };
}

def:priv stop_dict(s: Stop) -> dict[str, any] {
    return {
        "id": jid(s),
        "order": s.order,
        "time": s.time,
        "title": s.title,
        "kind": s.kind,
        "area": s.area,
        "blurb": s.blurb,
        "tip": s.tip,
        "image": s.image,
        "map": s.map,
        "options": s.options,
        "done": s.done
    };
}

def:priv trip_dict(t: Trip) -> dict[str, any] {
    stops = [stop_dict(s) for s in [t-->][?:Stop]];
    done = len([s for s in stops if s["done"]]);
    return attach_maps({
        "id": jid(t),
        "city": t.city,
        "tagline": t.tagline,
        "image": t.image,
        "date": t.date,
        "start": t.start,
        "end": t.end,
        "window": window_label(t.start, t.end),
        "season": t.season,
        "vibe": t.vibe,
        "source": t.source,
        "created": t.created,
        "dress": t.dress,
        "packed": t.packed,
        "outfit": t.outfit,
        "stops": stops,
        "stop_count": len(stops),
        "done_count": done,
        "landmarks": len([s for s in stops if s["kind"] == "landmark"]),
        "food_spots": sum([len(s["options"]) for s in stops if s["kind"] == "food"])
    });
}

def:priv find_trip(r: any, trip_id: str) -> Trip | None {
    for t in [r-->][?:Trip] {
        if jid(t) == trip_id {
            return t;
        }
    }
    return None;
}

"""Generate a day-trip itinerary (Claude when available) and save it."""
walker:protect PlanTrip {
    has city: str,
        date: str = "",
        start: str = "",
        end: str = "",
        season: str = "",
        vibe: str = "classic",
        use_ai: bool = True;

    can plan with Root entry {
        day: str = self.date or today();
        season: str = self.season or season_for(day);
        window = normalize_window(self.start, self.end);
        plan = None;
        source = "sample";
        if self.use_ai and ai_available() {
            try {
                plan = ai_plan(self.city, season, self.vibe, window[0], window[1]);
                source = "ai";
            } except Exception as e {
                print(f"Claude planning failed, using sample plan: {e}");
            }
        }
        if plan is None {
            plan = sample_plan(self.city);
        }
        plan = fit_window(plan, window[0], window[1]);
        plan = finalize(plan, season, self.vibe, source);
        t: Trip = Trip(
            city=plan["city"],
            tagline=plan["tagline"],
            image=plan["image"],
            date=day,
            start=window[0],
            end=window[1],
            season=season,
            vibe=self.vibe,
            source=source,
            created=now(),
            dress=plan["dress"]
        );
        here ++> t;
        i = 0;
        for s in plan["stops"] {
            t ++> Stop(
                order=i,
                time=s["time"],
                title=s["title"],
                kind=s["kind"],
                area=s["area"],
                blurb=s["blurb"],
                tip=s["tip"],
                image=s["image"],
                map=s["map"],
                options=s["options"]
            );
            i += 1;
        }
        report trip_dict(t);
    }
}

"""All saved trips, soonest date first (without stop details)."""
walker:protect ListTrips {
    can list with Root entry {
        trips = [trip_dict(t) for t in [here-->][?:Trip]];
        for t in trips {
            t["stops"] = [];
            t["outfit"] = {};  # photos are ~100 KB each; GetTrip carries them
        }
        report by_date(trips);
    }
}

"""One trip with its full itinerary."""
walker:protect GetTrip {
    has trip_id: str;

    can get with Root entry {
        t = find_trip(here, self.trip_id);
        report trip_dict(t) if t else None;
    }
}

"""Today's trip; else the next upcoming one; else the most recent."""
walker:protect TodayTrip {
    can get with Root entry {
        report pick_today([trip_dict(t) for t in [here-->][?:Trip]]);
    }
}

"""Mark a stop visited (or not). Reports the updated trip."""
walker:protect ToggleStop {
    has trip_id: str,
        stop_id: str,
        done: bool | None = None;

    can toggle with Root entry {
        t = find_trip(here, self.trip_id);
        if not t {
            report None;
            return;
        }
        for s in [t-->][?:Stop] {
            if jid(s) == self.stop_id {
                s.done = (not s.done) if self.done is None else self.done;
            }
        }
        report trip_dict(t);
    }
}

walker:protect DeleteTrip {
    has trip_id: str;

    can remove with Root entry {
        t = find_trip(here, self.trip_id);
        if t {
            for s in [t-->][?:Stop] {
                del s;
            }
            del t;
        }
        report {"deleted": self.trip_id};
    }
}

"""Tick (or untick) an item on the trip's what-to-wear list. Reports the trip."""
walker:protect TogglePacked {
    has trip_id: str,
        item: str;

    can toggle with Root entry {
        t = find_trip(here, self.trip_id);
        if not t {
            report None;
            return;
        }
        if self.item in t.packed {
            t.packed = [i for i in t.packed if i != self.item];
        } else {
            t.packed = t.packed + [self.item];
        }
        report trip_dict(t);
    }
}

"""Attach an outfit photo (a data: URL) to the trip; "" removes it. Reports the trip."""
walker:protect SetOutfitPhoto {
    has trip_id: str,
        image: str = "";

    can save with Root entry {
        t = find_trip(here, self.trip_id);
        if not t {
            report None;
            return;
        }
        if not self.image {
            t.outfit = {};
        } elif self.image.startswith("data:image/") and len(self.image) <= 3000000 {
            t.outfit = {"photo": self.image};
        }
        report trip_dict(t);
    }
}
