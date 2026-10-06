"""Wordmark: "Day Trip" with a little paper plane looping off on a dashed route."""

def:pub Logo -> JsxElement {
    return
        <a class="logo" href="/" aria-label="Day Trip home">
            Day Trip
            <svg class="logo-doodle" viewBox="0 0 64 28" aria-hidden="true">
                <path class="logo-route" d="M2 22 C 14 26, 22 4, 34 12 S 46 22, 50 9"/>
                <path class="logo-plane" d="M48 10 L62 3 L55 16 L53.5 11.5 Z"/>
                <path class="logo-fold" d="M53.5 11.5 L62 3"/>
            </svg>
        </a>;
}
