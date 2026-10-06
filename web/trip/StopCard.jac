"""One itinerary stop: a timetable row for a sight, or a food stop with a short menu."""

def:pub StopCard(stop: any, onToggle: Callable[[], None]) -> JsxElement {
    isFood = stop["kind"] == "food";
    return
        <article
            class={
                "stop "
                    + ("stop-food" if isFood else "stop-sight")
                    + (" stop-done" if stop["done"] else "")
            }
        >
            <div class="stop-when">
                <time class="stop-time">{stop["time"]}</time>
                <button
                    class="tick"
                    aria-pressed={stop["done"]}
                    title={("Mark not visited" if stop["done"] else "Mark visited")}
                    onClick={lambda { onToggle(); }}
                >
                    <span class="tick-box"></span>
                    {("Been" if stop["done"] else "Go")}
                </button>
            </div>
            <div class="stop-main">
                <div class="stop-meta">
                    <span class="stop-kind">{("Eat" if isFood else "See")}</span>
                    <a class="stop-area" href={stop["map"]} target="_blank" rel="noopener noreferrer">
                        {stop["area"]}
                    </a>
                </div>
                <h3 class="stop-title">
                    {(
                        <a href={stop["map"]} target="_blank" rel="noopener noreferrer">{stop["title"]}</a>
                    ) if not isFood else stop["title"]}
                </h3>
                <p class="stop-blurb">{stop["blurb"]}</p>
                <p class="stop-tip"><span>Tip</span>{stop["tip"]}</p>
                {(
                    <ul class="menu">
                        {[
                            <li class="dish" key={o["name"]}>
                                <span class="dish-img" data-label={o["name"][0]}>
                                    {(<img src={o["image"]} alt="" loading="lazy" onError={lambda (e: any) { e.target.style.display = "none"; }}/>) if o["image"] else None}
                                </span>
                                <div class="dish-body">
                                    <div class="dish-line">
                                        <a class="dish-name" href={o["map"]} target="_blank" rel="noopener noreferrer">
                                            {o["name"]}
                                        </a>
                                        <span class="dish-dots"></span>
                                        <span class="dish-price">{o["price"]}</span>
                                    </div>
                                    <span class="dish-sub">{(o["cuisine"] + ", get the " + o["dish"]) if o["dish"] else o["cuisine"]}</span>
                                </div>
                            </li> for o in stop["options"]
                        ]}
                    </ul>
                ) if isFood and stop["options"] else None}
                {(
                    <a class="directions" href={stop["map"]} target="_blank" rel="noopener noreferrer">
                        Directions ↗
                    </a>
                ) if not isFood else None}
            </div>
            <figure class="stop-photo" data-label={stop["title"]}>
                {(<img src={stop["image"]} alt={stop["title"]} loading="lazy" onError={lambda (e: any) { e.target.style.display = "none"; }}/>) if stop["image"] else None}
            </figure>
        </article>;
}
