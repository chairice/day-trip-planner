"""Sign-in gate for the trip planner: trips are saved per user."""

import from "@jac/runtime" { jacLogout, jacIsLoggedIn }

import from web.planner.AuthForm { AuthForm }
import from .TripApp { TripApp }
import from .Logo { Logo }
import from .theme { apply_season }

def:pub TripHome -> JsxElement {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True;

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    def handleLogout {
        jacLogout();
        isLoggedIn = False;
    }

    apply_season("");

    if checkingAuth {
        return <div class="trip-root"></div>;
    }
    if isLoggedIn {
        return <TripApp onLogout={handleLogout}/>;
    }
    return
        <div class="trip-root trip-auth">
            <nav class="masthead">
                <Logo/>
            </nav>
            <div class="auth-hero">
                <h1 class="ask">A day somewhere, planned hour by hour.</h1>
                <p class="auth-lede">Sign in to save your trips and tick off stops as you go.</p>
            </div>
            <AuthForm onAuth={lambda { isLoggedIn = True; }}/>
        </div>;
}
