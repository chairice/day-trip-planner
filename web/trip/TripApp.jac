"""Day-trip planner: plan a city day, save it, and check off stops as you go."""

import from core.trip.walkers {
    PlanTrip,
    ListTrips,
    TodayTrip,
    GetTrip,
    ToggleStop,
    TogglePacked,
    SetOutfitPhoto,
    DeleteTrip
}

import from .StopCard { StopCard }
import from .DressCard { DressCard }
import from .Logo { Logo }
import from .theme { apply_season }

def:pub TripApp(onLogout: Callable[[], None]) -> JsxElement {
    has city: str = "New York",
        date: str = "",
        startTime: str = "08:00",
        endTime: str = "22:00",
        season: str = "",
        vibe: str = "classic",
        vibeOpen: bool = False,
        useAi: bool = True,
        loading: bool = False,
        error: str = "",
        trips: list[any] = [],
        plan: any = None,
        uploading: bool = False,
        uploadError: str = "";

    async can with entry {
        await refreshTrips();
        result = root spawn TodayTrip();
        plan = result.reports[0] if result.reports else None;
    }

    async def refreshTrips {
        result = root spawn ListTrips();
        trips = result.reports[0] if result.reports else [];
    }

    async def generate {
        if not city.strip() {
            error = "Pick a city first.";
            return;
        }
        error = "";
        loading = True;
        try {
            result = root spawn PlanTrip(
                city=city,
                date=date,
                start=startTime,
                end=endTime,
                season=season,
                vibe=vibe,
                use_ai=useAi
            );
            plan = result.reports[0] if result.reports else None;
            await refreshTrips();
        } except Exception as e {
            error = "Couldn't build that trip — try again.";
        }
        loading = False;
    }

    async def openTrip(tripId: str) {
        uploadError = "";
        result = root spawn GetTrip(trip_id=tripId);
        plan = result.reports[0] if result.reports else None;
    }

    async def toggleStop(stopId: str) {
        result = root spawn ToggleStop(trip_id=plan["id"], stop_id=stopId);
        if result.reports and result.reports[0] {
            plan = result.reports[0];
        }
        await refreshTrips();
    }

    async def togglePacked(item: str) {
        result = root spawn TogglePacked(trip_id=plan["id"], item=item);
        if result.reports and result.reports[0] {
            plan = result.reports[0];
        }
    }

    """Downscale a picked photo to a ~900px JPEG data URL before upload."""
    async def shrinkPhoto(file: any) -> str {
        bmp: any = await globalThis.createImageBitmap(file);
        scale = min(1, 900 / max(bmp.width, bmp.height));
        canvas: any = document.createElement("canvas");
        canvas.width = int(bmp.width * scale);
        canvas.height = int(bmp.height * scale);
        canvas.getContext("2d").drawImage(bmp, 0, 0, canvas.width, canvas.height);
        return canvas.toDataURL("image/jpeg", 0.82);
    }

    async def setPhoto(image: str) {
        result = root spawn SetOutfitPhoto(trip_id=plan["id"], image=image);
        if result.reports and result.reports[0] {
            plan = result.reports[0];
        }
    }

    async def addPhoto(file: any) {
        if not file {
            return;
        }
        uploadError = "";
        uploading = True;
        try {
            await setPhoto(await shrinkPhoto(file));
        } except Exception as e {
            uploadError = "Couldn't add that image. Try a JPG or PNG.";
        }
        uploading = False;
    }

    async def deleteTrip {
        root spawn DeleteTrip(trip_id=plan["id"]);
        plan = None;
        await refreshTrips();
    }

    def handleKeyPress(e: KeyboardEvent) {
        if e.key == "Enter" {
            generate();
        }
    }

    quickCities = ["New York", "Paris", "Tokyo", "Chicago"];
    seasons = ["", "spring", "summer", "fall", "winter"];
    # Colours follow the open trip's season, else the season picked in the form.
    apply_season(plan["season"] if plan else season);

    windows = [
        ("Full day", "08:00", "22:00"),
        ("Morning", "08:00", "12:00"),
        ("Midday", "11:00", "17:00"),
        ("Evening", "17:00", "23:00")
    ];
    vibes = ["classic", "foodie", "adventure", "chill"];

    return
        <div class="trip-root">
            <nav class="masthead">
                <Logo/>
                <div class="masthead-right">
                    <button class="nav-link" onClick={lambda { onLogout(); }}>Sign out</button>
                </div>
            </nav>

            <header class="hero">
                <h1 class="ask">
                    A day in
                    <input
                        class="blank blank-city"
                        value={city}
                        onChange={lambda (e: ChangeEvent) { city = e.target.value; }}
                        onKeyPress={handleKeyPress}
                        placeholder="anywhere"
                        aria-label="City"
                    />,
                    kept
                    <span class="pick">
                        <button
                            class="blank pick-btn"
                            aria-label="Vibe"
                            aria-haspopup="listbox"
                            aria-expanded={vibeOpen}
                            onClick={lambda { vibeOpen = not vibeOpen; }}
                        >{vibe}</button>
                        {(
                            <>
                                <button
                                    class="pick-scrim"
                                    aria-label="Close"
                                    tabIndex={-1}
                                    onClick={lambda { vibeOpen = False; }}
                                ></button>
                                <ul class="pick-menu" role="listbox" aria-label="Vibe">
                                    {[
                                        <li key={v}>
                                            <button
                                                role="option"
                                                aria-selected={v == vibe}
                                                class={"pick-opt " + ("on" if v == vibe else "")}
                                                onClick={lambda { vibe = v; vibeOpen = False; }}
                                            >{v}</button>
                                        </li> for v in vibes
                                    ]}
                                </ul>
                            </>
                        ) if vibeOpen else None}
                    </span>.
                </h1>

                <div class="fine">
                    <label class="field">
                        <span>Date</span>
                        <input
                            type="date"
                            value={date}
                            onChange={lambda (e: ChangeEvent) { date = e.target.value; }}
                            title="Blank means today"
                        />
                    </label>
                    <label class="field">
                        <span>From</span>
                        <input
                            type="time"
                            value={startTime}
                            onChange={lambda (e: ChangeEvent) { startTime = e.target.value; }}
                        />
                    </label>
                    <label class="field">
                        <span>To</span>
                        <input
                            type="time"
                            value={endTime}
                            onChange={lambda (e: ChangeEvent) { endTime = e.target.value; }}
                        />
                    </label>
                    <label class="field">
                        <span>Season</span>
                        <select
                            value={season}
                            onChange={lambda (e: ChangeEvent) { season = e.target.value; }}
                        >
                            {[<option key={s or "auto"} value={s}>{s or "from date"}</option> for s in seasons]}
                        </select>
                    </label>
                    <label class="ai-toggle">
                        <input
                            type="checkbox"
                            checked={useAi}
                            onChange={lambda { useAi = not useAi; }}
                        />
                        <span>Plan with Claude (works for any city)</span>
                    </label>
                </div>

                <div class="quick windows">
                    <span>hours</span>
                    {[
                        <button
                            key={w[0]}
                            class={
                                "quick-city "
                                    + ("on" if w[1] == startTime and w[2] == endTime else "")
                            }
                            onClick={lambda {
                                startTime = w[1];
                                endTime = w[2];
                            }}
                        >{w[0]}</button> for w in windows
                    ]}
                </div>

                <div class="controls">
                    <button class="go" onClick={lambda { generate(); }} disabled={loading}>
                        {("Planning…" if loading else "Plan the day")}
                    </button>
                    <div class="quick">
                        <span>or try</span>
                        {[
                            <button
                                key={c}
                                class={"quick-city " + ("on" if c == city else "")}
                                onClick={lambda { city = c; }}
                            >{c}</button> for c in quickCities
                        ]}
                    </div>
                </div>
                {(<p class="error">{error}</p>) if error else None}
            </header>

            {(
                <section class="saved">
                    <h2 class="saved-head">Your trips <span>{len(trips)}</span></h2>
                    <div class="saved-row">
                        {[
                            <button
                                key={t["id"]}
                                class={
                                    "stub "
                                        + ("on" if plan and plan["id"] == t["id"] else "")
                                }
                                onClick={lambda { openTrip(t["id"]); }}
                            >
                                <span class="stub-img">
                                    {(<img src={t["image"]} alt="" onError={lambda (e: any) { e.target.style.display = "none"; }}/>) if t["image"] else None}
                                </span>
                                <div class="stub-body">
                                    <b>{t["city"]}</b>
                                    <span>{t["date"]}</span>
                                    <span>{t["done_count"]} of {t["stop_count"]} stops</span>
                                    <div class="bar">
                                        <div
                                            class="bar-fill"
                                            style={{
                                                "width": str(
                                                    int(100 * t["done_count"] / max(1, t["stop_count"]))
                                                ) + "%"
                                            }}
                                        ></div>
                                    </div>
                                </div>
                            </button> for t in trips
                        ]}
                    </div>
                </section>
            ) if len(trips) > 0 else None}

            {(
                <div class="loading">
                    <span class="loading-route"></span>
                    <span>Walking the route…</span>
                </div>
            ) if loading else None}

            {(
                <main class="result">
                    <section class="cover">
                        <figure class="cover-photo" data-label={plan["city"]}>
                            <span class="postmark" aria-hidden="true">
                                <b>{plan["city"]}</b>
                                <i>{plan["date"]}</i>
                            </span>
                            {(<img src={plan["image"]} alt={plan["city"]} onError={lambda (e: any) { e.target.style.display = "none"; }}/>) if plan["image"] else None}
                        </figure>
                        <div class="cover-text">
                            <span class="cover-kicker">
                                {plan["date"]} · {plan["window"]} · {plan["season"]} · {plan["vibe"]}
                                {(" · planned by Claude" if plan["source"] == "ai" else "")}
                            </span>
                            <h2 class="cover-title">{plan["city"]}</h2>
                            <p class="cover-sub">{plan["tagline"]}</p>
                            <p class="cover-stats">
                                <span>{plan["done_count"]} of {plan["stop_count"]} visited</span>
                                <span>{plan["landmarks"]} sights</span>
                                <span>{plan["food_spots"]} places to eat</span>
                                <button class="delete" onClick={lambda { deleteTrip(); }}>Delete trip</button>
                            </p>
                        </div>
                    </section>
                    <div class="layout">
                        <section class="timeline">
                            {[
                                <StopCard
                                    key={s["id"]}
                                    stop={s}
                                    onToggle={lambda { toggleStop(s["id"]); }}
                                /> for s in plan["stops"]
                            ]}
                        </section>
                        <DressCard
                            dress={plan["dress"]}
                            packed={plan["packed"] or []}
                            photo={(plan["outfit"] or {})["photo"] if plan["outfit"] and "photo" in plan["outfit"] else ""}
                            uploading={uploading}
                            uploadError={uploadError}
                            onToggle={lambda (item: str) { togglePacked(item); }}
                            onPhoto={lambda (f: any) { addPhoto(f); }}
                            onRemovePhoto={lambda { setPhoto(""); }}
                        />
                    </div>
                </main>
            ) if plan and not loading else None}

            <footer class="foot">
                <span>Photos from Wikimedia Commons</span>
                <span>Directions open in Google Maps</span>
            </footer>
        </div>;
}
