"""Trip planner AI types: the shape `plan_trip` must fill in."""

obj FoodOption {
    has name: str,
        cuisine: str,
        price: str,
        dish: str,
        wiki: str;
}

obj TripStop {
    has time: str,
        title: str,
        kind: str,
        area: str,
        blurb: str,
        tip: str,
        wiki: str,
        options: list[FoodOption];
}

obj TripPlan {
    has city: str,
        tagline: str,
        wiki: str,
        style: str,
        stops: list[TripStop];
}

sem TripStop.kind = "Either 'landmark' or 'food'";
sem TripStop.wiki = "Exact English Wikipedia article title for a photo of this stop";
sem TripStop.options = "For food stops, 3 restaurant options; empty for landmarks";
sem FoodOption.wiki = "Exact English Wikipedia article title of the signature dish or the restaurant";
sem FoodOption.price = "One of $, $$, $$$, $$$$";
sem TripPlan.style = "One of city-smart, chic, streetwear, midwest-layers, generic";

def:priv plan_trip(city: str, season: str, vibe: str, start_time: str, end_time: str) -> TripPlan by llm();
sem plan_trip = "Plan an ideal day trip in the city that starts no earlier than start_time and ends by end_time (24-hour HH:MM). Fit as many famous landmarks as the window allows (about one stop per 90 minutes), include a meal stop only when the window covers that mealtime, and order stops in a walkable geographic route. Use 12-hour times like 9:30 AM. Keep blurbs and tips to one sentence.";

# --- Persisted graph: root --> Trip --> Stop ---

node Trip {
    has city: str,
        tagline: str = "",
        image: str = "",
        date: str = "",
        start: str = "08:00",
        end: str = "22:00",
        season: str = "fall",
        vibe: str = "classic",
        source: str = "sample",
        created: str = "",
        dress: dict[str, any] = {},
        packed: list[str] = [],
        outfit: dict[str, any] = {};  # {"photo": data URL} once the user adds one
}

node Stop {
    has order: int = 0,
        time: str = "",
        title: str = "",
        kind: str = "landmark",
        area: str = "",
        blurb: str = "",
        tip: str = "",
        image: str = "",
        map: str = "",
        options: list[dict[str, any]] = [],
        done: bool = False;
}
