"""Top-level planner UI: gates on login, then composes the feature panels."""

import from "@jac/runtime" { jacLogout, jacIsLoggedIn }

import from .AuthForm { AuthForm }
import from .Header { Header }
import from .TasksPanel { TasksPanel }
import from .ShoppingPanel { ShoppingPanel }

def:pub PlannerApp -> JsxElement {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True;

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    def handleAuth {
        isLoggedIn = True;
    }

    def handleLogout {
        jacLogout();
        isLoggedIn = False;
    }

    if checkingAuth {
        return
            <div class="auth-loading">Loading...</div>;
    }

    if isLoggedIn {
        return
            <div class="container">
                <Header onLogout={handleLogout}/>
                <div class="two-column">
                    <TasksPanel/>
                    <ShoppingPanel/>
                </div>
            </div>;
    }

    return
        <AuthForm onAuth={handleAuth}/>;
}
