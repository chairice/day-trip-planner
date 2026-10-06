"""Seasonal colour themes: trip.css defines one palette per season, keyed
off <html data-season="...">. Pages call apply_season() as they render."""

glob SEASONS: list[str] = ["spring", "summer", "fall", "winter"];

"""Northern-hemisphere season for today's date."""
def:pub season_today -> str {
    month: any = new(Date).getMonth();  # 0 = January
    if month >= 2 and month <= 4 {
        return "spring";
    }
    if month >= 5 and month <= 7 {
        return "summer";
    }
    if month >= 8 and month <= 10 {
        return "fall";
    }
    return "winter";
}

def:pub apply_season(season: str) {
    picked = season if season in SEASONS else season_today();
    html: any = document.documentElement;
    if html.getAttribute("data-season") != picked {
        html.setAttribute("data-season", picked);
    }
}
