"""Catch-all route: anything that isn't a page (e.g. the old /tasks) lands here."""

import from web.trip.Logo { Logo }
import from web.trip.theme { apply_season }

def:pub page -> JsxPage {
    apply_season("");
    return
        <div class="trip-root">
            <nav class="masthead">
                <Logo/>
            </nav>
            <header class="hero">
                <h1 class="ask">Nothing on this page.</h1>
                <p class="auth-lede">It may have moved, or it was never here.</p>
                <div class="controls">
                    <a class="go" href="/">Back to planning</a>
                </div>
            </header>
        </div>;
}
