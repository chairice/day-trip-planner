"""daytrip -- the terminal client for the DAY//TRIP planner.

    jac run cli -- login casey
    jac run cli -- plan "Paris" --date 2026-10-12 --vibe foodie
    jac run cli -- today
    jac run cli -- done 3
    jac run cli -- trips

Talks to the server `jac run` starts (DAYTRIP_SERVER, default
http://localhost:8000) through the same walkers the web and mobile apps use.
"""

import argparse;
import asyncio;
import getpass;
import sys;

import from cli.session {
    connect,
    call,
    ServerError,
    login,
    register,
    clear_session,
    load_session,
    server_url,
    warn
}

glob PROG: str = "daytrip",
     EXIT_OK: int = 0,
     EXIT_FAILURE: int = 1,
     EXIT_USAGE: int = 2,
     EXIT_UNAVAILABLE: int = 3,
     EXIT_REJECTED: int = 5;

def build_parser -> argparse.ArgumentParser {
    parser = argparse.ArgumentParser(
        prog=PROG,
        description="Plan, view, and check off one-day city trips from the terminal."
    );
    cmds = parser.add_subparsers(dest="command", metavar="<command>", required=True);

    for name in ["login", "signup"] {
        p = cmds.add_parser(
            name,
            help=("sign in" if name == "login" else "create an account and sign in")
        );
        p.add_argument("username");
        p.add_argument("--password", help="omit to be prompted");
    }
    cmds.add_parser("logout", help="forget the saved session");
    cmds.add_parser("whoami", help="show the signed-in user and server");

    plan = cmds.add_parser("plan", help="plan and save a day trip");
    plan.add_argument("city");
    plan.add_argument("--date", `default="", help="YYYY-MM-DD (default: today)");
    plan.add_argument(
        "--from",
        dest="start",
        `default="",
        help="start time, e.g. 11am or 11:00 (default 8am)"
    );
    plan.add_argument(
        "--to",
        dest="end",
        `default="",
        help="end time, e.g. 5pm or 17:00 (default 10pm)"
    );
    plan.add_argument(
        "--vibe",
        `default="classic",
        choices=["classic", "foodie", "adventure", "chill"]
    );
    plan.add_argument(
        "--season",
        `default="",
        choices=["", "spring", "summer", "fall", "winter"],
        help="default: from the date"
    );
    plan.add_argument("--no-ai", action="store_true", help="use a sample plan, skip Claude");

    cmds.add_parser("trips", help="list saved trips");
    cmds.add_parser("today", help="show today's (or the next) trip");
    show = cmds.add_parser("show", help="show a saved trip");
    show.add_argument("trip", `type=int, help="trip number from `trips`");

    for name in ["done", "undo"] {
        p = cmds.add_parser(
            name,
            help=("mark a stop visited" if name == "done" else "un-mark a stop")
        );
        p.add_argument("stop", `type=int, help="stop number shown by `today`/`show`");
        p.add_argument("--trip", `type=int, `default=0, help="trip number (default: today's)");
    }

    pack = cmds.add_parser("pack", help="tick (or untick) a dress-code item as packed");
    pack.add_argument("item", `type=int, help="item number shown under Dress code");
    pack.add_argument("--trip", `type=int, `default=0, help="trip number (default: today's)");

    rm = cmds.add_parser("delete", help="delete a saved trip");
    rm.add_argument("trip", `type=int);
    return parser;
}

# --- rendering ---

def render_trip(t: dict[str, any]) {
    tag = "Claude" if t["source"] == "ai" else "sample";
    print(f"\n  {t['city'].upper()}  ·  {t['date']}  ·  {t['window']}  ·  {t['season']} / {t['vibe']}  ({tag} plan)");
    print(f"  {t['tagline']}");
    print(f"  {t['done_count']}/{t['stop_count']} stops visited\n");
    i = 1;
    for s in t["stops"] {
        box = "[x]" if s["done"] else "[ ]";
        icon = "food" if s["kind"] == "food" else "see ";
        print(f"  {i:>2}. {box} {s['time']:>8}  {icon}  {s['title']}  — {s['area']}");
        for o in s["options"] {
            extra = (" (" + o["price"] + ")" if o["price"] else "")
                + (" — " + o["dish"] if o["dish"] else "");
            print(f"                       · {o['name']}{extra}");
        }
        i += 1;
    }
    d = t["dress"];
    packed = t.get("packed") or [];
    print(f"\n  Dress code: {d['headline']} — {d['season']}  ({len([x for x in d['items'] if x in packed])}/{len(d['items'])} packed)");
    j = 1;
    for item in d["items"] {
        box = "[x]" if item in packed else "[ ]";
        print(f"   {j:>2}. {box} {item}");
        j += 1;
    }
    print(f"    {d['note']}");
    outfit = t.get("outfit") or {};
    if outfit.get("photo") {
        print("    Outfit photo: saved (view it on the web or phone)");
    }
    print("");
}

def render_list(trips: list[dict[str, any]]) {
    if not trips {
        print("No trips yet. Try: jac run cli -- plan \"Paris\"");
        return;
    }
    i = 1;
    for t in trips {
        print(f"  {i:>2}. {t['date']}  {t['window']:<22} {t['city']:<16} {t['done_count']}/{t['stop_count']} visited");
        i += 1;
    }
}

# --- commands ---

async def trip_by_number(n: int) -> dict[str, any] | None {
    listed = call("ListTrips");
    trips = listed[0] if listed else [];
    if n < 1 or n > len(trips) {
        warn(f"daytrip: no trip #{n} (you have {len(trips)}); see `trips`");
        return None;
    }
    full = call("GetTrip", {"trip_id": trips[n - 1]["id"]});
    return full[0] if full else None;
}

async def run(ns: any) -> int {
    cmd = ns.command;
    if cmd in ["login", "signup"] {
        password = ns.password or getpass.getpass("Password: ");
        if cmd == "signup" {
            made = register(ns.username, password);
            if made.get("ok") is False {
                warn(f"daytrip: sign-up failed: {made.get('error')}");
                return EXIT_FAILURE;
            }
        }
        if not login(ns.username, password) {
            warn("daytrip: login failed (check username/password and that `jac run` is up)");
            return EXIT_REJECTED;
        }
        print(f"Signed in as {ns.username} on {server_url()}");
        return EXIT_OK;
    }
    if cmd == "logout" {
        clear_session();
        print("Signed out.");
        return EXIT_OK;
    }
    if cmd == "whoami" {
        s = load_session();
        print(f"{s.get('username', '(not signed in)')} @ {s.get('server', server_url())}");
        return EXIT_OK;
    }

    if not connect() {
        return EXIT_REJECTED;
    }
    if cmd == "plan" {
        print(f"Planning a day in {ns.city}…");
        planned = call(
            "PlanTrip",
            {
                "city": ns.city,
                "date": ns.date,
                "start": ns.start,
                "end": ns.end,
                "season": ns.season,
                "vibe": ns.vibe,
                "use_ai": not ns.no_ai
            }
        );
        render_trip(planned[0]);
        return EXIT_OK;
    }
    if cmd == "trips" {
        listed = call("ListTrips");
        render_list(listed[0] if listed else []);
        return EXIT_OK;
    }
    if cmd == "today" {
        todays = call("TodayTrip");
        t = todays[0] if todays else None;
        if not t {
            print("No trips yet. Try: jac run cli -- plan \"Paris\"");
        } else {
            render_trip(t);
        }
        return EXIT_OK;
    }
    if cmd == "show" {
        t = await trip_by_number(ns.trip);
        if not t {
            return EXIT_USAGE;
        }
        render_trip(t);
        return EXIT_OK;
    }
    if cmd in ["done", "undo"] {
        if ns.trip {
            t = await trip_by_number(ns.trip);
        } else {
            current = call("TodayTrip");
            t = current[0] if current else None;
        }
        if not t {
            warn("daytrip: no trip to update");
            return EXIT_USAGE;
        }
        if ns.stop < 1 or ns.stop > len(t["stops"]) {
            warn(f"daytrip: no stop #{ns.stop} (this trip has {len(t['stops'])})");
            return EXIT_USAGE;
        }
        stop = t["stops"][ns.stop - 1];
        toggled = call(
            "ToggleStop",
            {"trip_id": t["id"], "stop_id": stop["id"], "done": cmd == "done"}
        );
        updated = toggled[0];
        mark = "visited" if cmd == "done" else "not visited";
        print(f"{stop['title']} marked {mark} — {updated['done_count']}/{updated['stop_count']} done in {updated['city']}");
        return EXIT_OK;
    }
    if cmd == "pack" {
        if ns.trip {
            t = await trip_by_number(ns.trip);
        } else {
            current = call("TodayTrip");
            t = current[0] if current else None;
        }
        if not t {
            warn("daytrip: no trip to update");
            return EXIT_USAGE;
        }
        items = t["dress"]["items"];
        if ns.item < 1 or ns.item > len(items) {
            warn(f"daytrip: no item #{ns.item} (this dress code has {len(items)})");
            return EXIT_USAGE;
        }
        item = items[ns.item - 1];
        toggled = call("TogglePacked", {"trip_id": t["id"], "item": item});
        now_packed = item in (toggled[0].get("packed") or []);
        print(f"{item}: {('packed' if now_packed else 'not packed')}");
        return EXIT_OK;
    }
    if cmd == "delete" {
        t = await trip_by_number(ns.trip);
        if not t {
            return EXIT_USAGE;
        }
        call("DeleteTrip", {"trip_id": t["id"]});
        print(f"Deleted {t['city']} ({t['date']}).");
        return EXIT_OK;
    }
    warn(f"daytrip: unknown command {cmd}");
    return EXIT_USAGE;
}

async def main(argv: list[str]) -> int {
    ns = build_parser().parse_args(argv);
    try {
        return await run(ns);
    } except ServerError as e {
        warn(f"daytrip: {e}");
        return EXIT_UNAVAILABLE;
    }
}

with entry:__main__ {
    sys.`exit(asyncio.run(main(sys.argv[1:])));
}
