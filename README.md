# DAY//TRIP — a day-trip planner in Jac

**Name:** Casey Feng
**UMID:** 68967179

DAY//TRIP plans a one-day trip in a city, hour by hour, and keeps it with you
while you travel. Pick a city, a date, the hours you have (8 AM–10 PM,
11 AM–5 PM, an evening…), and a vibe. You get a timeline of landmarks and food
stops with real photos, three restaurant choices for each meal, Google Maps
directions, and a dress code for the city and season. Trips are saved to your
account, so you can plan on the web, check off stops on your phone, and add or
review trips from the terminal.

## Features

- **Itineraries planned by Claude** for any city (`by llm()` in
  `core/trip/models.jac`), using the time window, season and vibe you pick.
  Without an API key the app falls back to hand-written plans for New York,
  Paris, Tokyo and Chicago, plus a generic template for other cities.
- **Time constraints:** start and end times (`8am`, `17:00`, …). Claude plans
  within the window. Sample plans keep only the stops that fit, or re-time
  their best stops evenly when the window is unusual (e.g. 2–4 AM).
- **Landmarks and food spots** with photos from Wikipedia/Wikimedia (fetched
  in one batched request per trip), plus 3 restaurant options with a price
  level and a dish to try.
- **Dress code** based on the city's style, the season (taken from the date
  if you don't pick one) and the vibe.
- **Saved and per-user:** trips persist in the Jac graph (`root → Trip → Stop`)
  under each signed-in user, so they survive server restarts.
- **Progress tracking:** check stops off from any client; the web, phone and
  CLI all show the same progress.
- **"Today" view:** shows today's trip, otherwise the next upcoming one,
  otherwise the most recent.

## Prerequisites

- **Jac 0.37** (the native `jac` binary). Install it with:
  `curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash`.
  Check it with `jac -V`; it should say 0.37.x.
  If an older `jac` (e.g. 0.16 from a Python venv) is first on your `PATH`,
  run `deactivate` or call `~/.local/bin/jac` directly.
- **Optional:** `ANTHROPIC_API_KEY` for Claude planning
  (`export ANTHROPIC_API_KEY=sk-ant-...`). Without it the app still works
  with the sample plans.
- **Mobile, native only:** Xcode (iOS simulator) or an Android emulator/device
  with Expo Go. The browser preview needs nothing extra.

## Run it

```bash
jac run            # web app + server on http://localhost:8000
```

The first `jac run` installs the npm and Python dependencies itself (this was
verified from a clean copy; a separate `jac install` is not needed).

`jac run` starts the default app (`web`), and the `trips` service app runs in
the same process. Open http://localhost:8000, create an account, and plan a
trip.

### Web

1. Sign up or sign in.
2. Fill in the sentence ("A day in ___, kept ___"), and optionally a date,
   hours (or a preset: Full day / Morning / Midday / Evening) and season.
3. **Plan the day.** The trip is saved under "Your trips".
4. Click a stop's marker to check it off, and use the map links for directions.

### Mobile app

The mobile app (`mobile/main.jac`) is a React Native app built with
`@jac/mobui`. It has three tabs: **Today** (today's trip; check off stops),
**Trips** (all saved trips) and **Plan** (city, hours, vibe). It calls the
same `trips` service walkers as the web app, on the same store and the same
accounts, so sign in with your web account.

```bash
jac setup mobile                                  # one time: Expo/Metro scaffold
jac run --dev mobile                              # native: press i (iOS simulator) / a (Android), or scan the QR code with Expo Go
jac run --dev --platform web --port 8100 mobile   # browser preview at http://localhost:8100 (phone-sized window)
```

The mobile dev loop starts its own API process (it prints the API URL), which
hosts the same `trips` service and data store. A physical phone reaches it
over your LAN; the dev loop detects your LAN address automatically (override
with `JAC_RN_DEV_HOST`).

**Web and mobile at the same time:** the web dev server and the mobile
preview share build files under `.jac/client`. If you want both open, start
the web app with `jac run --no-dev` instead of `jac run`.

### CLI

The CLI (`cli/main.jac`) talks to the running server's `trips` service
(`POST /api/trips/walker/<Name>`) with your session token (stored in `~/.daytrip/session.json`). Use
`DAYTRIP_SERVER=http://host:port` to point it at another server.

```bash
jac run cli -- signup casey                       # or: login casey
jac run cli -- plan "Paris" --from 11am --to 5pm --vibe foodie --date 2026-10-12
jac run cli -- today                              # today's (or next) trip, numbered stops
jac run cli -- done 2                             # check off stop 2 (undo 2 to un-check)
jac run cli -- trips                              # all saved trips
jac run cli -- show 1                             # full itinerary of trip 1
jac run cli -- done 3 --trip 1                    # check off a stop on a specific trip
jac run cli -- pack 2                             # tick dress-code item 2 as packed (again to untick)
jac run cli -- delete 1
jac run cli -- whoami | logout
jac run cli -- --help
```

## How the pieces fit together

```
            ┌──────────── trips service app (core/trip/walkers.jac) ────────────┐
            │ walker:protect PlanTrip · ListTrips · TodayTrip · GetTrip ·      │
            │                ToggleStop · DeleteTrip                            │
            │ graph per user: root ──> Trip ──> Stop        (persisted)         │
            │ core/trip/models.jac  by llm() → Claude                           │
            │ core/trip/engine.py   sample plans, time windows, photos, maps    │
            └──────────────▲───────────────────▲────────────────────▲──────────┘
                           │ walker bridge     │ walker bridge      │ POST /api/trips/walker/*
                web (web/, React)      mobile (mobile/, mobUI)    cli (cli/, terminal)
```

- **Server:** `core/trip/walkers.jac` is a `service` app. Its `:protect`
  walkers are the only API. Each runs from the caller's own root, so every
  user's trips are private and persisted. `jac run` hosts it inside the web
  server.
- **Web** (`web/`): the browser UI, with sign-in, planning, saved trips and
  check-off. It spawns the walkers directly (`root spawn PlanTrip(...)`).
- **Mobile** (`mobile/`): the same walkers from React Native, focused on using
  the plan during the day.
- **CLI** (`cli/`): a Jac `argparse` program for quick planning and checking
  off stops from the terminal, signed in with the same account.

## What makes it impressive

- **One backend for three clients:** one set of walkers and one data model,
  with no route handlers, serializers or database code. A stop checked off on
  the phone shows up in the CLI and on the web right away.
- **AI with a safety net:** Claude fills a typed `TripPlan` schema (`obj`s
  with `sem` hints) under the time window, and every plan, from Claude or not,
  goes through the same window fitting, photo lookup and dress-code steps.
- **Real photos at no cost:** one batched Wikipedia request per itinerary
  turns landmark and dish names into real photos.

## Project layout

```
jac.toml                 apps: web (default), trips (service), mobile, cli; Claude model
core/trip/models.jac     Trip/Stop nodes, AI types, plan_trip by llm()
core/trip/walkers.jac    the trips service: per-user walkers
core/trip/engine.py      sample plans, time windows, dress codes, photos, maps links
web/                     web app (pages/, trip/ components, trip.css)
mobile/main.jac          mobUI app (Today / Trips / Plan)
cli/main.jac, session.jac   terminal client
```

