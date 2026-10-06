"""Day-trip engine: curated sample itineraries, any-city plans from real
places (OpenStreetMap + Wikipedia), dress codes, and photo lookup.

Photos come from Wikipedia (real photos of the named landmark or dish);
when a page has none the image is left empty and the UI shows a placeholder.
"""

import json
import math
import os
import re
from datetime import date, datetime
import ssl
import time
import urllib.parse
import urllib.request


def _stop(time, title, kind, area, blurb, tip, wiki, options=None):
    return {
        "time": time,
        "title": title,
        "kind": kind,
        "area": area,
        "blurb": blurb,
        "tip": tip,
        "wiki": wiki,
        "options": options or [],
    }


def _food(name, cuisine, price, dish, wiki):
    return {"name": name, "cuisine": cuisine, "price": price, "dish": dish, "wiki": wiki}


CITIES = {
    "new york": {
        "city": "New York City",
        "tagline": "Skyline, slices, and a sunset over the Hudson.",
        "wiki": "Midtown Manhattan",
        "style": "city-smart",
        "stops": [
            _stop("8:30 AM", "Coffee & bagels", "food", "Lower East Side",
                  "Fuel up like a local before the subway rush.",
                  "Order 'everything, scallion cream cheese' and don't overthink it.",
                  "Bagel", [
                      _food("Russ & Daughters", "Appetizing shop", "$$", "Lox bagel", "Russ & Daughters"),
                      _food("Ess-a-Bagel", "Bagels", "$", "Everything bagel", "Bagel"),
                      _food("Katz's Delicatessen", "Jewish deli", "$$", "Pastrami on rye", "Katz's Delicatessen"),
                  ]),
            _stop("10:00 AM", "Brooklyn Bridge walk", "landmark", "DUMBO ↔ Manhattan",
                  "Cross the 1883 suspension bridge on foot for the best skyline views in the city.",
                  "Start on the Brooklyn side so Manhattan is in front of you the whole way.",
                  "Brooklyn Bridge"),
            _stop("12:00 PM", "9/11 Memorial & One World Trade", "landmark", "Financial District",
                  "Twin reflecting pools on the original tower footprints, under the tallest building in the West.",
                  "The memorial plaza is free; book the observatory ahead for a fast-track slot.",
                  "National September 11 Memorial & Museum"),
            _stop("1:30 PM", "Lunch break", "food", "Chelsea / West Village",
                  "Pick a quick bite near the High Line.",
                  "Chelsea Market gets packed after 1 PM — grab and walk.",
                  "Chelsea Market", [
                      _food("Joe's Pizza", "NY slice", "$", "Cheese slice", "New York-style pizza"),
                      _food("Chelsea Market", "Food hall", "$$", "Lobster roll", "Chelsea Market"),
                      _food("Xi'an Famous Foods", "Northwest Chinese", "$", "Hand-ripped noodles", "Biangbiang noodles"),
                  ]),
            _stop("3:00 PM", "The High Line", "landmark", "Meatpacking → Hudson Yards",
                  "A 1.45-mile elevated park on an old freight rail line, lined with gardens and public art.",
                  "Walk north and end at the Vessel in Hudson Yards.",
                  "High Line"),
            _stop("5:00 PM", "Central Park", "landmark", "Midtown → Upper East Side",
                  "Bethesda Terrace, Bow Bridge, and the Mall — the park's greatest hits in an hour.",
                  "Rent a rowboat at the Loeb Boathouse if the line is short.",
                  "Central Park"),
            _stop("7:30 PM", "Dinner", "food", "Midtown / East Village",
                  "Wind down with a proper New York dinner.",
                  "Reservations open 30 days out — set a reminder.",
                  "Ramen", [
                      _food("Peter Luger", "Steakhouse", "$$$$", "Porterhouse", "Peter Luger Steak House"),
                      _food("Ippudo NY", "Ramen", "$$", "Tonkotsu ramen", "Tonkotsu ramen"),
                      _food("Lombardi's", "Coal-oven pizza", "$$", "Margherita pie", "Lombardi's"),
                  ]),
            _stop("9:30 PM", "Times Square at night", "landmark", "Midtown",
                  "End under a canyon of billboards — loud, bright, and absolutely worth seeing once.",
                  "Climb the red TKTS steps for the classic photo.",
                  "Times Square"),
        ],
    },
    "paris": {
        "city": "Paris",
        "tagline": "Croissants, cathedrals, and the tower sparkling at night.",
        "wiki": "Paris",
        "style": "chic",
        "stops": [
            _stop("8:30 AM", "Café breakfast", "food", "Le Marais",
                  "Sit on a terrace and watch Paris wake up.",
                  "Order at the counter ('au comptoir') — it's cheaper than a table.",
                  "Croissant", [
                      _food("Du Pain et des Idées", "Boulangerie", "$", "Pain des amis", "Croissant"),
                      _food("Café de Flore", "Classic café", "$$$", "Café crème", "Café de Flore"),
                      _food("Stohrer", "Pâtisserie", "$$", "Baba au rhum", "Rum baba"),
                  ]),
            _stop("10:00 AM", "Louvre Museum", "landmark", "1st arr.",
                  "The world's most-visited museum: the Mona Lisa, Winged Victory, and I. M. Pei's glass pyramid.",
                  "Use the Carrousel entrance underground to skip the pyramid line.",
                  "Louvre"),
            _stop("12:30 PM", "Notre-Dame & Île de la Cité", "landmark", "4th arr.",
                  "The restored Gothic cathedral, reopened in December 2024 after the fire.",
                  "Cross to Île Saint-Louis afterward for Berthillon ice cream.",
                  "Notre-Dame de Paris"),
            _stop("1:30 PM", "Lunch break", "food", "Latin Quarter",
                  "A long French lunch is the point, not a detour.",
                  "Look for a 'formule midi' chalkboard — set lunch for a fraction of dinner prices.",
                  "Croque monsieur", [
                      _food("Bouillon Chartier", "Classic bouillon", "$", "Œufs mayonnaise", "Bouillon Chartier"),
                      _food("L'As du Fallafel", "Falafel", "$", "Falafel special", "Falafel"),
                      _food("Le Relais de l'Entrecôte", "Steak frites", "$$", "Entrecôte", "Steak frites"),
                  ]),
            _stop("3:30 PM", "Montmartre & Sacré-Cœur", "landmark", "18th arr.",
                  "Hilltop basilica, painters on Place du Tertre, and the best free view in the city.",
                  "Take the funicular up and walk down Rue Lepic.",
                  "Sacré-Cœur, Paris"),
            _stop("6:00 PM", "Arc de Triomphe & Champs-Élysées", "landmark", "8th arr.",
                  "Climb 284 steps for the star-shaped view down twelve avenues.",
                  "Use the underground passage — never cross the roundabout.",
                  "Arc de Triomphe"),
            _stop("8:00 PM", "Dinner", "food", "Saint-Germain",
                  "Bistro classics with a glass of something red.",
                  "Dinner starts late here; 8 PM is early.",
                  "Bistro", [
                      _food("Le Comptoir du Relais", "Bistro", "$$$", "Duck confit", "Confit de canard"),
                      _food("Bistrot Paul Bert", "Bistro", "$$$", "Steak au poivre", "Steak au poivre"),
                      _food("Breizh Café", "Crêperie", "$$", "Galette complète", "Galette"),
                  ]),
            _stop("10:00 PM", "Eiffel Tower sparkle", "landmark", "Trocadéro",
                  "The tower glitters for five minutes at the top of every hour after dark.",
                  "Watch from Trocadéro for the full-frame view.",
                  "Eiffel Tower"),
        ],
    },
    "tokyo": {
        "city": "Tokyo",
        "tagline": "Shrines at dawn, neon at night, ramen in between.",
        "wiki": "Tokyo",
        "style": "streetwear",
        "stops": [
            _stop("7:30 AM", "Tsukiji Outer Market breakfast", "food", "Tsukiji",
                  "Graze on the freshest seafood in the world.",
                  "Bring cash and eat at the stall — walking while eating is frowned upon.",
                  "Tsukiji Outer Market", [
                      _food("Sushi Dai", "Sushi", "$$$", "Omakase", "Sushi"),
                      _food("Tamagoyaki stalls", "Street food", "$", "Tamagoyaki", "Tamagoyaki"),
                      _food("Kitsuneya", "Donburi", "$", "Horumon-don", "Donburi"),
                  ]),
            _stop("9:30 AM", "Senso-ji Temple", "landmark", "Asakusa",
                  "Tokyo's oldest temple, through the giant red lantern of Kaminarimon.",
                  "Draw an omikuji fortune — tie it to the rack if it's bad luck.",
                  "Sensō-ji"),
            _stop("11:30 AM", "Tokyo Skytree", "landmark", "Sumida",
                  "634 m tall — on clear days you can see Mount Fuji.",
                  "Morning visibility is best; skip it if it's hazy.",
                  "Tokyo Skytree"),
            _stop("1:00 PM", "Lunch break", "food", "Ginza / Shinjuku",
                  "Ticket-machine ramen, counter-seat bliss.",
                  "Slurping is polite. Tipping is not.",
                  "Ramen", [
                      _food("Ichiran", "Tonkotsu ramen", "$", "Solo-booth ramen", "Tonkotsu ramen"),
                      _food("Tsuta", "Shoyu ramen", "$$", "Truffle shoyu soba", "Ramen"),
                      _food("Tonkatsu Maisen", "Tonkatsu", "$$", "Kurobuta katsu", "Tonkatsu"),
                  ]),
            _stop("3:00 PM", "Meiji Shrine", "landmark", "Harajuku",
                  "A forested Shinto shrine steps from the madness of Takeshita Street.",
                  "Bow once at the torii gate on the way in.",
                  "Meiji Shrine"),
            _stop("5:00 PM", "Shibuya Crossing", "landmark", "Shibuya",
                  "The world's busiest scramble — up to 3,000 people per green light.",
                  "Shibuya Sky rooftop gives the god's-eye view at sunset.",
                  "Shibuya Crossing"),
            _stop("7:30 PM", "Dinner", "food", "Shinjuku",
                  "Smoke, skewers, and a cold highball.",
                  "Many izakaya charge a small 'otoshi' cover — it's normal.",
                  "Yakitori", [
                      _food("Omoide Yokocho", "Yakitori alley", "$$", "Yakitori", "Yakitori"),
                      _food("Gonpachi", "Izakaya", "$$", "Soba & skewers", "Izakaya"),
                      _food("Uobei", "Conveyor sushi", "$", "Bullet-train sushi", "Conveyor belt sushi"),
                  ]),
            _stop("9:30 PM", "Golden Gai & Kabukicho lights", "landmark", "Shinjuku",
                  "Six tiny alleys of 200+ bars, some seating only five people.",
                  "Some bars charge a seat fee — check the sign on the door.",
                  "Golden Gai"),
        ],
    },
    "chicago": {
        "city": "Chicago",
        "tagline": "Architecture, deep dish, and the lake that looks like an ocean.",
        "wiki": "Chicago",
        "style": "midwest-layers",
        "stops": [
            _stop("8:30 AM", "Breakfast", "food", "West Loop",
                  "Start with a Midwest-sized breakfast.",
                  "Weekend lines start at 9 — go early.",
                  "Pancake", [
                      _food("Lou Mitchell's", "Diner", "$", "Double-yolk eggs", "Lou Mitchell's"),
                      _food("Wildberry", "Brunch", "$$", "Berry bliss pancakes", "Pancake"),
                      _food("Do-Rite Donuts", "Donuts", "$", "Old-fashioned donut", "Doughnut"),
                  ]),
            _stop("10:00 AM", "Millennium Park & Cloud Gate", "landmark", "The Loop",
                  "Anish Kapoor's mirrored 'Bean' and the Crown Fountain faces.",
                  "Go before 10:30 for a Bean photo without crowds.",
                  "Cloud Gate"),
            _stop("11:30 AM", "Art Institute of Chicago", "landmark", "The Loop",
                  "Nighthawks, American Gothic, and Seurat's island Sunday.",
                  "Head straight to Gallery 240 for the Impressionists.",
                  "Art Institute of Chicago"),
            _stop("1:30 PM", "Lunch break", "food", "River North",
                  "Deep dish or a Chicago dog — choose wisely.",
                  "Deep dish takes 45 minutes; order before you sit.",
                  "Chicago-style pizza", [
                      _food("Lou Malnati's", "Deep dish", "$$", "Buttercrust deep dish", "Lou Malnati's Pizzeria"),
                      _food("Portillo's", "Hot dogs", "$", "Chicago-style hot dog", "Chicago-style hot dog"),
                      _food("Al's #1 Italian Beef", "Italian beef", "$", "Italian beef, dipped", "Italian beef"),
                  ]),
            _stop("3:00 PM", "Architecture river cruise", "landmark", "Chicago River",
                  "90 minutes past a century of skyscrapers from the water.",
                  "Sit on the top deck, left side, for the best angles.",
                  "Chicago River"),
            _stop("5:00 PM", "Willis Tower Skydeck", "landmark", "The Loop",
                  "Step onto The Ledge — a glass box 1,353 feet above the street.",
                  "Sunset slots sell out; book a timed ticket.",
                  "Willis Tower"),
            _stop("7:30 PM", "Dinner", "food", "Fulton Market",
                  "Restaurant Row in the West Loop.",
                  "Bar seating is walk-in friendly.",
                  "Steak", [
                      _food("Girl & the Goat", "New American", "$$$", "Goat empanadas", "Goat meat"),
                      _food("Au Cheval", "Burgers", "$$", "Double cheeseburger", "Cheeseburger"),
                      _food("Gibsons", "Steakhouse", "$$$$", "Bone-in ribeye", "Rib eye steak"),
                  ]),
            _stop("9:30 PM", "Navy Pier & the lakefront", "landmark", "Streeterville",
                  "The Centennial Wheel and skyline lights across Lake Michigan.",
                  "Summer Wednesdays and Saturdays end with fireworks.",
                  "Navy Pier"),
        ],
    },
}

ALIASES = {
    "nyc": "new york", "new york city": "new york", "manhattan": "new york", "ny": "new york",
    "paris, france": "paris", "tokyo, japan": "tokyo", "chi": "chicago", "chicago, il": "chicago",
}

STYLE_BASE = {
    "city-smart": ("Downtown smart-casual", ["Dark jeans or chinos", "Crisp tee or button-down", "Clean white sneakers"]),
    "chic": ("Effortless Parisian chic", ["Neutral palette (navy, black, cream)", "Tailored trousers or midi skirt", "Leather loafers or ballet flats"]),
    "streetwear": ("Tokyo street-smart", ["Layered oversized tee or overshirt", "Wide-leg trousers", "Slip-on shoes (easy off at shrines)"]),
    "midwest-layers": ("Lakefront layers", ["Denim or chinos", "Flannel or knit layer", "Comfortable sneakers"]),
    "generic": ("Explorer casual", ["Breathable tee", "Comfortable trousers", "Broken-in walking shoes"]),
}

SEASON = {
    "spring": ("Light jacket + umbrella", ["Packable rain shell", "Light scarf"]),
    "summer": ("Breathable + sun-ready", ["Sunglasses & SPF", "Linen or cotton fabrics", "Refillable water bottle"]),
    "fall": ("Layer for crisp evenings", ["Light jacket or trench", "A sweater for after dark"]),
    "winter": ("Bundle up", ["Insulated coat", "Hat, gloves, and a warm scarf", "Waterproof boots"]),
}

VIBE = {
    "classic": "Keep it polished — you'll pass through museums and a nice dinner spot.",
    "foodie": "Go for an elastic waistband and a dark top that hides sauce. You've been warned.",
    "adventure": "Prioritise shoes: you'll walk 20,000+ steps. Pack a light crossbody bag.",
    "chill": "Comfort first — soft layers and shoes you can wear for 12 hours.",
}


def dress_code(style, season, vibe):
    headline, base = STYLE_BASE.get(style, STYLE_BASE["generic"])
    season_head, season_items = SEASON.get(season, SEASON["fall"])
    return {
        "headline": headline,
        "season": season_head,
        "items": base + season_items,
        "note": VIBE.get(vibe, VIBE["classic"]),
    }


def generic_city(city):
    name = city.strip().title()
    return {
        "city": name,
        "tagline": f"A sample day in {name} — switch on AI mode for local picks.",
        "wiki": name,
        "style": "generic",
        "stops": [
            _stop("9:00 AM", "Neighborhood café", "food", "City center",
                  "Start slow with coffee and a pastry.", "Ask the barista for their favourite lunch spot.", "Coffee", [
                      _food("Local roaster", "Coffee", "$", "Flat white", "Flat white"),
                      _food("Corner bakery", "Bakery", "$", "Fresh pastry", "Pastry"),
                  ]),
            _stop("10:30 AM", f"Historic heart of {name}", "landmark", "Old town",
                  f"Wander the oldest streets in {name}.", "Join a free walking tour (tip-based).", name),
            _stop("1:00 PM", "Lunch break", "food", "Market district",
                  "Find the food hall or main market.", "Follow the longest local queue.", "Street food", [
                      _food("Central market", "Food hall", "$", "Local specialty", "Street food"),
                      _food("Family-run bistro", "Regional", "$$", "Daily special", "Bistro"),
                  ]),
            _stop("3:00 PM", "Main museum", "landmark", "Cultural district",
                  "The city's flagship collection.", "Many museums are free one evening a week.", "Museum"),
            _stop("7:30 PM", "Dinner", "food", "Downtown",
                  "A sit-down dinner of the regional cuisine.", "Book a table by mid-afternoon.", "Restaurant", [
                      _food("Chef's tasting spot", "Modern", "$$$", "Tasting menu", "Tasting menu"),
                      _food("Neighborhood favourite", "Local", "$$", "House classic", "Restaurant"),
                  ]),
        ],
    }


_IMG_CACHE = {}

try:
    import certifi

    _SSL = ssl.create_default_context(cafile=certifi.where())
except Exception:
    _SSL = ssl.create_default_context()




def wiki_images(titles):
    """Look up photos for many Wikipedia titles in one batched API call."""
    wanted = [t for t in dict.fromkeys(titles) if t and t not in _IMG_CACHE]
    if wanted:
        params = urllib.parse.urlencode({
            "action": "query", "format": "json", "redirects": 1,
            "prop": "pageimages", "piprop": "thumbnail", "pithumbsize": 800,
            "titles": "|".join(wanted[:50]),
        })
        req = urllib.request.Request(
            "https://en.wikipedia.org/w/api.php?" + params,
            headers={"User-Agent": "daytrip-planner/0.1 (student project)"},
        )
        try:
            with urllib.request.urlopen(req, timeout=8, context=_SSL) as resp:
                query = json.loads(resp.read().decode()).get("query", {})
            # Map requested titles through normalization/redirects to the final page.
            alias = {}
            for step in ("normalized", "redirects"):
                for m in query.get(step, []):
                    alias[m["from"]] = m["to"]
            found = {pg.get("title"): pg.get("thumbnail", {}).get("source", "")
                     for pg in query.get("pages", {}).values()}
            for t in wanted:
                final = t
                while final in alias:
                    final = alias[final]
                if found.get(final):
                    _IMG_CACHE[t] = found[final]
        except Exception as e:
            print(f"wiki image lookup failed: {e}")
    # No photo -> "" and the UI draws a placeholder; a random stock photo
    # of the wrong place would be worse than none.
    return {t: _IMG_CACHE.get(t, "") for t in titles if t}


def attach_images(plan):
    titles = [plan.get("wiki", "")]
    for s in plan["stops"]:
        titles.append(s.get("wiki", ""))
        titles += [o.get("wiki", "") for o in s.get("options", [])]
    found = wiki_images(titles)
    plan["image"] = found.get(plan.get("wiki", ""), "")
    for s in plan["stops"]:
        s["image"] = found.get(s.get("wiki", ""), "")
        for o in s.get("options", []):
            o["image"] = found.get(o.get("wiki", ""), "")
    return plan


# --- Any-city planner: real places from OpenStreetMap and Wikipedia ---

_UA = {"User-Agent": "daytrip-planner/0.1 (student project)"}
_DISCOVER_CACHE = {}

# Wikipedia descriptions that mark an article as a place to live/pass through,
# not a place to visit.
_NOT_SIGHTS = (
    "school", "college campus", "station", "census", "unincorporated", "county",
    "city in", "town in", "village in", "neighborhood", "neighbourhood", "district",
    "street", "road", "highway", "freeway", "interstate", "airport", "hospital",
    "company", "newspaper", "radio", "television", "former", "defunct", "demolished",
    "cemetery", "apartment", "office building", "shopping mall", "subdivision",
    "military", "base", "headquarters", "electoral", "parish", "suburb",
    "human settlement", "community in", "place in", "area of", "region of",
    # events and organisations have coordinates but nothing to visit
    "battle", "siege", "war", "festival", "concert", "massacre", "earthquake", "fire of",
    "riot", "protest", "election", "treaty", "incident", "shooting", "police", "agency",
    "organization", "organisation", "party", "club", "team", "band", "album", "film",
    "novel", "song", "event", "expedition", "conference", "dynasty", "parade",
    "force", "gendarmerie", "army", "ministry", "government", "council", "court of",
    "show", "annual", "tournament", "championship", "race", "competition", "diocese",
)

# Descriptions that sound like somewhere worth going; these rank first.
_SIGHT_WORDS = (
    "museum", "park", "garden", "aquarium", "zoo", "cathedral", "church", "basilica",
    "temple", "shrine", "mosque", "synagogue", "monastery", "abbey", "mission", "castle",
    "palace", "fort", "tower", "bridge", "lighthouse", "monument", "memorial", "statue",
    "fountain", "square", "plaza", "market", "beach", "pier", "wharf", "harbor", "harbour",
    "waterfront", "promenade", "boardwalk", "theatre", "theater", "opera", "gallery",
    "historic", "landmark", "viewpoint", "lookout", "observatory", "library", "lift",
    "funicular", "gate", "arch", "ruins", "old town", "quarter", "trail", "lake", "island",
)

# Sights that still make sense after dark.
_EVENING_WORDS = (
    "square", "plaza", "bridge", "monument", "memorial", "statue", "fountain", "pier",
    "wharf", "waterfront", "promenade", "boardwalk", "beach", "harbor", "harbour", "street",
    "tower", "lookout", "viewpoint", "old town", "quarter", "theatre", "theater", "opera",
)

_CUISINE_WIKI = {
    "coffee_shop": "Coffee", "coffee": "Coffee", "cafe": "Coffee", "bakery": "Bakery",
    "breakfast": "Breakfast", "brunch": "Brunch", "donut": "Doughnut", "bagel": "Bagel",
    "pizza": "Pizza", "burger": "Hamburger", "sushi": "Sushi", "ramen": "Ramen",
    "japanese": "Japanese cuisine", "chinese": "Chinese cuisine", "thai": "Thai cuisine",
    "indian": "Indian cuisine", "mexican": "Mexican cuisine", "italian": "Italian cuisine",
    "french": "French cuisine", "seafood": "Seafood", "fish": "Seafood", "steak_house": "Steak",
    "american": "American cuisine", "vietnamese": "Vietnamese cuisine", "korean": "Korean cuisine",
    "greek": "Greek cuisine", "mediterranean": "Mediterranean cuisine", "spanish": "Spanish cuisine",
    "barbecue": "Barbecue", "sandwich": "Sandwich", "ice_cream": "Ice cream", "tapas": "Tapas",
}


def _get_json(url, params, timeout=10, data=None):
    full = url + "?" + urllib.parse.urlencode(params) if params else url
    body = urllib.parse.urlencode(data).encode() if data else None
    req = urllib.request.Request(full, data=body, headers=_UA)
    with urllib.request.urlopen(req, timeout=timeout, context=_SSL) as resp:
        return json.loads(resp.read().decode())


def _clean(text):
    """Drop parentheticals (pronunciations, native names) and collapse whitespace."""
    prev = None
    while prev != text:
        prev, text = text, re.sub(r"\s*[(\[][^()\[\]]*[)\]]", "", text)
    return re.sub(r"\s+", " ", text).strip()


def _km(a, b):
    """Great-circle distance in km between (lat, lon) pairs."""
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(h))


def _walk_note(km):
    if km < 2.5:
        return f"About {round(km * 1000 / 80)} min on foot from the last stop ({km:.1f} km)."
    return f"{km:.1f} km from the last stop, so take a bus, taxi or bike."


def _geocode(city):
    hits = _get_json("https://nominatim.openstreetmap.org/search", {
        "q": city, "format": "json", "limit": 8, "addressdetails": 1, "extratags": 1,
        "accept-language": "en",
    })
    if not hits:
        return None
    # "Monterey, California" also matches Monterey County; prefer the town itself.
    towns = ("city", "town", "village", "hamlet", "municipality", "suburb", "borough", "quarter")
    h = next((x for x in hits if x.get("addresstype") in towns), hits[0])
    wiki = h.get("extratags", {}).get("wikipedia", "")
    return {
        "lat": float(h["lat"]),
        "lon": float(h["lon"]),
        "name": h.get("name") or city.strip().title(),
        "wiki": wiki.split(":", 1)[1] if wiki.startswith("en:") else "",
    }


def _landmarks(center, limit=5):
    """The most notable Wikipedia articles near the centre that look like sights.

    Notability is approximated by article length; page-view stats would be
    better but that API is heavily rate-limited. Four requests at most.
    """
    api = "https://en.wikipedia.org/w/api.php"
    data = _get_json(api, {
        "action": "query", "format": "json", "formatversion": 2,
        "generator": "geosearch", "ggscoord": f"{center[0]}|{center[1]}",
        "ggsradius": 10000, "ggslimit": 300,
        "prop": "coordinates|description|info", "colimit": "max",
    })
    found = []
    for pg in data.get("query", {}).get("pages", []):
        desc = (pg.get("description") or "").lower()
        coords = (pg.get("coordinates") or [{}])[0]
        gone = re.search(r"[–-]\s*\d{4}\)?$", desc)  # e.g. "Landmark in X (1898–2021)"
        if "lat" not in coords or gone or desc[:1].isdigit() or any(w in desc for w in _NOT_SIGHTS):
            continue
        pos = (coords["lat"], coords["lon"])
        found.append({
            "title": pg["title"], "desc": pg.get("description") or "",
            "pos": pos, "sight": any(w in desc for w in _SIGHT_WORDS),
            "evening": any(w in desc for w in _EVENING_WORDS),
            # Longer articles ~ more notable; discount the far edge of the 10 km radius.
            "score": pg.get("length", 0) / (1 + _km(center, pos) / 4),
        })
    # Stay walkable: keep to 5 km of the centre unless that leaves too few sights.
    close = [p for p in found if _km(center, p["pos"]) <= 5]
    found = close if len([p for p in close if p["sight"]]) >= limit else found
    found.sort(key=lambda p: (not p["sight"], -p["score"]))
    shortlist = found[:15]
    if not shortlist:
        return []
    # One more call for photos and two-sentence intros of the shortlist.
    extra = _get_json(api, {
        "action": "query", "format": "json", "formatversion": 2,
        "prop": "pageimages|extracts", "piprop": "name", "pilimit": "max",
        "exintro": 1, "explaintext": 1, "exsentences": 2, "exlimit": "max",
        "redirects": 1, "titles": "|".join(p["title"] for p in shortlist),
    })
    info = {pg["title"]: pg for pg in extra.get("query", {}).get("pages", [])}
    for p in shortlist:
        pg = info.get(p["title"], {})
        p["blurb"] = _clean(pg.get("extract", "")) or p["desc"]
        p["photo"] = "pageimage" in pg
    # Sights with a photo first, keeping the notability order otherwise.
    shortlist.sort(key=lambda p: (not p["sight"], not p["photo"], -p["score"]))
    return shortlist[:limit]


def _food_places(center):
    """Named cafés and restaurants within ~3 km, from OpenStreetMap via Nominatim.

    (Overpass would give more results but its public servers time out often.)
    Nominatim asks for at most one request per second, hence the pauses.
    """
    lat, lon = center
    dlat, dlon = 0.027, 0.027 / max(0.2, math.cos(math.radians(lat)))
    places = []
    for kind in ("cafe", "restaurant"):
        time.sleep(1.1)
        hits = _get_json("https://nominatim.openstreetmap.org/search", {
            "q": kind, "format": "json", "limit": 40, "bounded": 1, "extratags": 1,
            "accept-language": "en",
            "viewbox": f"{lon - dlon},{lat + dlat},{lon + dlon},{lat - dlat}",
        })
        for h in hits:
            t = h.get("extratags") or {}
            if h.get("type") not in ("cafe", "restaurant") or not h.get("name") or t.get("brand"):
                continue  # skip chains and stray matches
            places.append({
                "name": h["name"],
                "amenity": h["type"],
                "cuisines": [c.strip() for c in t.get("cuisine", "").split(";") if c.strip()],
                "pos": (float(h["lat"]), float(h["lon"])),
                "hours": t.get("opening_hours", ""),
                # Places with more tagged detail tend to be established spots.
                "detail": sum(k in t for k in ("cuisine", "website", "opening_hours", "phone")),
            })
    return places


MEAL_MINUTES = {"breakfast": 8 * 60 + 30, "lunch": 13 * 60, "dinner": 19 * 60 + 30}


def _open_at(hours, minute):
    """Rough check against OSM opening_hours time ranges (days ignored).
    Unknown or unparseable hours count as open."""
    ranges = re.findall(r"(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})", hours or "")
    if not ranges:
        return True
    for h1, m1, h2, m2 in ranges:
        a, b = int(h1) * 60 + int(m1), int(h2) * 60 + int(m2)
        if b <= a:
            b += 24 * 60
        if a <= minute <= b - 30:
            return True
    return False


def _cuisine_label(p):
    if not p["cuisines"]:
        return "Café" if p["amenity"] == "cafe" else "Restaurant"
    return ", ".join(c.replace("_", " ").title() for c in p["cuisines"][:2])


def _cuisine_wiki(p):
    for c in p["cuisines"]:
        if c in _CUISINE_WIKI:
            return _CUISINE_WIKI[c]
    return "Coffee" if p["amenity"] == "cafe" else "Restaurant"


def _meal(places, near, kind, used, count=3):
    """Pick `count` distinct, well-tagged spots closest to `near`."""
    def fits(p):
        if p["name"] in used or not _open_at(p["hours"], MEAL_MINUTES[kind]):
            return False
        breakfasty = p["amenity"] == "cafe" or any(c in p["cuisines"] for c in ("breakfast", "brunch", "bakery", "coffee_shop", "donut", "bagel"))
        return breakfasty if kind == "breakfast" else p["amenity"] == "restaurant"

    pool = sorted((p for p in places if fits(p)), key=lambda p: (-p["detail"], _km(near, p["pos"])))
    pool = sorted(pool[:25], key=lambda p: _km(near, p["pos"]))
    picks, cuisines = [], set()
    for p in pool:
        key = tuple(p["cuisines"][:1])
        if key and key in cuisines:
            continue  # vary the cuisines on offer
        picks.append(p)
        cuisines.add(key)
        used.add(p["name"])
        if len(picks) == count:
            break
    return picks


def _route(center, sights):
    """Nearest-neighbour walking order starting from the city centre."""
    order, here, left = [], center, list(sights)
    while left:
        nxt = min(left, key=lambda s: _km(here, s["pos"]))
        order.append(nxt)
        left.remove(nxt)
        here = nxt["pos"]
    return order


def _maps_to(pos):
    return f"https://www.google.com/maps/dir/?api=1&destination={pos[0]:.6f},{pos[1]:.6f}"


def discover_city(city):
    """A full 8 AM–10 PM day built from real nearby places, or None if lookups fail."""
    key = city.strip().lower()
    if key in _DISCOVER_CACHE:
        return json.loads(json.dumps(_DISCOVER_CACHE[key]))
    try:
        geo = _geocode(city)
        if not geo:
            return None
        center = (geo["lat"], geo["lon"])
        found = _landmarks(center)
        if len(found) < 2:
            return None
        # Save an after-dark-friendly sight for the 9 PM slot; route the rest.
        night = next((p for p in reversed(found) if p["evening"]), None)
        sights = _route(center, [p for p in found if p is not night][:4]) + ([night] if night else [])
        try:
            places = _food_places(center)
        except Exception as e:
            print(f"food lookup failed for {city}: {e}")
            places = []
    except Exception as e:
        print(f"city lookup failed for {city}: {e}")
        return None

    name = city.strip().title() if "," in city else geo["name"]
    used = set()
    # 8:30 breakfast, two sights, 1:00 lunch, two sights, 7:30 dinner, last sight.
    layout = [("8:30 AM", "breakfast"), ("10:00 AM", 0), ("11:30 AM", 1), ("1:00 PM", "lunch"),
              ("2:30 PM", 2), ("4:30 PM", 3), ("7:30 PM", "dinner"), ("9:00 PM", 4)]
    if not night:
        layout = layout[:-1]
    meal_titles = {"breakfast": "Breakfast", "lunch": "Lunch break", "dinner": "Dinner"}
    stops, here, last_sight = [], center, ""
    for time, slot in layout:
        if isinstance(slot, int):
            if slot >= len(sights):
                continue
            s = sights[slot]
            title = re.sub(r"\s*\([^)]*\)$", "", s["title"])  # drop "(Asheville, North Carolina)"
            stops.append(_stop(time, title, "landmark", s["desc"][:1].upper() + s["desc"][1:] or name,
                               s["blurb"], _walk_note(_km(here, s["pos"])) if stops else "Start here and work outward on foot.",
                               s["title"]))
            stops[-1]["map"] = _maps_to(s["pos"])  # exact spot; sights can sit in a neighbouring town
            here, last_sight = s["pos"], title
            continue
        picks = _meal(places, here, slot, used)
        if not picks:
            continue
        options = [_food(p["name"], _cuisine_label(p), "", "", _cuisine_wiki(p)) for p in picks]
        for o, p in zip(options, picks):
            o["map"] = _maps_to(p["pos"])
        first = picks[0]
        stop = _stop(time, meal_titles[slot], "food", f"Near {last_sight}" if last_sight else name,
                     f"{len(picks)} independent spots close to where you are.",
                     f"{first['name']} hours: {first['hours']}." if first["hours"] else "Opening hours aren't listed, so check before you go.",
                     options[0]["wiki"], options)
        stop["map"] = _maps_to(picks[0]["pos"])
        stops.append(stop)
    plan = {
        "city": name,
        "tagline": f"Real sights and local food around {geo['name']}, from Wikipedia and OpenStreetMap.",
        "wiki": geo["wiki"] or name,
        "style": "generic",
        "stops": stops,
    }
    if places:
        _DISCOVER_CACHE[key] = json.loads(json.dumps(plan))
    return plan


def sample_plan(city: str) -> dict:
    """Curated plan for the built-in cities; real nearby places for any other
    city; a generic template only if the lookups fail (e.g. offline)."""
    key = city.strip().lower()
    key = ALIASES.get(key, key)
    base = CITIES.get(key)
    if base:
        return json.loads(json.dumps(base))
    return discover_city(city) or generic_city(city)


def maps_url(place: str, city: str) -> str:
    """Google Maps directions from the viewer's location to `place` in `city`."""
    query = f"{place}, {city}" if city and city.lower() not in place.lower() else place
    return "https://www.google.com/maps/dir/?api=1&destination=" + urllib.parse.quote(query)


def attach_maps(plan: dict) -> dict:
    """Fill in missing directions links (also back-fills trips saved before links existed)."""
    city = plan.get("city", "")
    for s in plan["stops"]:
        # Landmarks route to the named place; food stops to their neighborhood.
        place = (s.get("wiki") or s["title"]) if s["kind"] == "landmark" else s.get("area", "")
        s["map"] = s.get("map") or maps_url(place, city)
        for o in s.get("options", []):
            o["map"] = o.get("map") or maps_url(o["name"], city)
    return plan


def finalize(plan: dict, season: str, vibe: str, source: str) -> dict:
    plan["season"] = season
    plan["vibe"] = vibe
    plan["source"] = source
    plan["dress"] = dress_code(plan.get("style", "generic"), season, vibe)
    plan["stop_count"] = len(plan["stops"])
    plan["landmarks"] = len([s for s in plan["stops"] if s["kind"] == "landmark"])
    plan["food_spots"] = sum(len(s["options"]) for s in plan["stops"] if s["kind"] == "food")
    return attach_images(attach_maps(plan))


def ai_available() -> bool:
    """Claude planning needs an Anthropic key; without one we use sample plans."""
    return bool(os.environ.get("ANTHROPIC_API_KEY", "").strip())


def today() -> str:
    return date.today().isoformat()


def now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def season_for(day: str) -> str:
    """Default season from a YYYY-MM-DD date (northern hemisphere)."""
    try:
        month = int(day[5:7])
    except Exception:
        month = date.today().month
    return ["winter", "winter", "spring", "spring", "spring", "summer",
            "summer", "summer", "fall", "fall", "fall", "winter"][month - 1]


def by_date(trips: list) -> list:
    """Sort trip dicts soonest-first (ties broken by creation time)."""
    return sorted(trips, key=lambda t: (t.get("date", ""), t.get("created", "")))


def pick_today(trips: list):
    """Today's trip; else the next upcoming one; else the most recent."""
    day = today()
    trips = by_date(trips)
    todays = [t for t in trips if t["date"] == day]
    if todays:
        return todays[-1]
    upcoming = [t for t in trips if t["date"] > day]
    if upcoming:
        return upcoming[0]
    return trips[-1] if trips else None


# --- Time windows: "8 AM to 10 PM", "11:00-17:00", ... ---

DEFAULT_START, DEFAULT_END = "08:00", "22:00"
SLOT_MINUTES = 90  # rough time budget per stop when re-timing a plan


def parse_clock(text: str):
    """'8', '8am', '8:30 AM', '17:00', '5pm' -> minutes after midnight (or None)."""
    t = str(text or "").strip().lower().replace(" ", "").replace(".", "")
    if not t:
        return None
    suffix = ""
    if t.endswith(("am", "pm")):
        suffix, t = t[-2:], t[:-2]
    try:
        hh, _, mm = t.partition(":")
        h, m = int(hh), int(mm or 0)
    except ValueError:
        return None
    if suffix == "pm" and h != 12:
        h += 12
    if suffix == "am" and h == 12:
        h = 0
    if not (0 <= h <= 24 and 0 <= m < 60):
        return None
    return min(h * 60 + m, 24 * 60)


def hhmm(minutes: int) -> str:
    return f"{minutes // 60:02d}:{minutes % 60:02d}"


def clock_label(minutes: int) -> str:
    h, m = divmod(minutes % (24 * 60), 60)
    return f"{(h % 12) or 12}:{m:02d} {'AM' if h < 12 else 'PM'}"


def normalize_window(start: str, end: str) -> list:
    """Clean a start/end pair into ['HH:MM', 'HH:MM'] with end after start."""
    s = parse_clock(start)
    e = parse_clock(end)
    s = parse_clock(DEFAULT_START) if s is None else s
    e = parse_clock(DEFAULT_END) if e is None else e
    if e < s:
        s, e = e, s
    if e - s < 60:
        e = min(s + 4 * 60, 24 * 60)
    return [hhmm(s), hhmm(e)]


def window_label(start: str, end: str) -> str:
    return f"{clock_label(parse_clock(start))} – {clock_label(parse_clock(end))}"


def fit_window(plan: dict, start: str, end: str) -> dict:
    """Keep the stops that fall inside the window; if too few fit, re-time the
    plan's best stops evenly across the window instead."""
    s, e = parse_clock(start), parse_clock(end)
    stops = plan["stops"]
    inside = [st for st in stops
              if (parse_clock(st["time"]) is not None and s <= parse_clock(st["time"]) <= e - 30)]
    room = max(1, (e - s) // SLOT_MINUTES)
    if len(inside) >= min(2, room):
        plan["stops"] = inside
        return plan
    count = min(len(stops), room)
    # Start from the stop scheduled closest to the window's start.
    first = min(range(len(stops)),
                key=lambda i: abs((parse_clock(stops[i]["time"]) or 0) - s))
    first = min(first, len(stops) - count)
    picked = stops[first:first + count]
    step = (e - s) // max(1, count)
    for i, st in enumerate(picked):
        st["time"] = clock_label(s + i * step)
    plan["stops"] = picked
    return plan
