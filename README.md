# Day Trip

**Name:** Casey Feng
**UMID:** 68967179

Day Trip plans one day in a city, hour by hour. You type a city, choose the
hours you have and a vibe (classic, foodie, adventure, chill), and get a
timeline of sights and meal stops with photos, a few restaurant picks for each
meal, Google Maps directions, and a packing list for the season. Trips are
saved to your account, and you can open them from the website, the phone app,
or the terminal.

## Features

- Works for any city. New York, Paris, Tokyo and Chicago have hand-written
  plans. Any other city gets a plan built from real places: the most notable
  sights nearby on Wikipedia and independent cafés and restaurants from
  OpenStreetMap, ordered as a walking route. With an Anthropic API key, Claude
  writes the plan instead.
- Start and end times: only the stops that fit your window are kept.
- Every sight, neighborhood and restaurant links to Google Maps directions.
- A "what to wear" checklist based on the city, season and vibe, plus a spot
  to attach a photo of your outfit.
- Check off stops as you go. Progress syncs between web, phone and terminal.
- Each user has their own saved trips, and they survive server restarts.
- The web UI is styled like a printed travel guide, and its colors change
  with the trip's season.

## Setup

You need **Jac 0.37** (the standalone `jac` binary):

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
jac -V   # should print 0.37.x
```

If an older `jac` from a Python virtualenv comes first on your `PATH`, run
`deactivate` or call `~/.local/bin/jac` directly.

Optional: set `ANTHROPIC_API_KEY` to have Claude write the itineraries.
Everything works without it.

## Running the web app

From the repository root:

```bash
jac run
```

The first run installs the npm and Python dependencies automatically. Then
open http://localhost:8000, create an account, and plan a trip. `jac run`
starts the default `web` app together with the `trips` server.

## Mobile app

The mobile app (`mobile/main.jac`) is built with Jac's React Native UI kit and
has three tabs: **Today** (check off stops), **Trips** (saved trips) and
**Plan** (plan a new day). Sign in with the same account you use on the web.

To preview it in a browser, build it once, then start the preview:

```bash
jac build mobile --platform web
jac run --dev --platform web --port 8100 mobile
```

Open http://localhost:8100 and make the window phone-sized. Rebuild after
editing `mobile/main.jac`.

To run it on a simulator or phone instead (needs Xcode, or Android Studio with
Expo Go):

```bash
jac setup mobile      # one time
jac run --dev mobile  # press i for iOS, a for Android, or scan the QR code
```

To run the website and the mobile preview at the same time, start the website
with `jac run --no-dev` instead of `jac run`. The two dev servers share build
files under `.jac/client`, and running both in dev mode makes them overwrite
each other.

## CLI

The CLI (`cli/main.jac`) talks to the server started by `jac run` at
http://localhost:8000. Set `DAYTRIP_SERVER` to use a different address.

```bash
jac run cli -- signup casey       # prompts for a password (or: login casey)
jac run cli -- plan "Monterey, California" --from 9am --to 6pm --vibe foodie
jac run cli -- today              # today's trip with numbered stops
jac run cli -- done 1             # check off stop 1 (undo 1 to reverse)
jac run cli -- pack 1             # tick packing item 1
jac run cli -- trips              # all saved trips
jac run cli -- show 2             # one trip in full
jac run cli -- delete 2
jac run cli -- --help             # everything else
```

## How it fits together

The project has four parts, all declared in `jac.toml`:

1. **Server** (`core/trip/`). `walkers.jac` is a Jac service app that holds
   all the logic. Its walkers (`PlanTrip`, `ListTrips`, `TodayTrip`,
   `ToggleStop`, `TogglePacked`, `SetOutfitPhoto`, ...) are the only API. Each
   one runs from the signed-in user's own graph (`root → Trip → Stop`), so
   trips are private and persistent. `engine.py` handles the curated plans,
   the real-place lookups, photos, map links and time windows.
2. **Web app** (`web/`). Calls the walkers directly with `root spawn`. Jac
   turns those calls into requests to the server.
3. **Mobile app** (`mobile/`). Calls the same walkers the same way.
4. **CLI** (`cli/`). Calls the same walkers over HTTP
   (`/api/trips/walker/<Name>`) with the session token from sign-in.

`jac run` starts the web app and runs the `trips` service in the same
process.

## What makes it interesting

- One backend serves three clients. There are no hand-written routes, no
  serializers and no database code. A stop checked off in the terminal shows
  up on the phone and the website.
- It works for any city without an API key, using free data from Wikipedia
  and OpenStreetMap, and the results are real places with real photos.
- When a key is available, Claude fills a typed `TripPlan` schema through
  Jac's `by llm()`, and its plans go through the same time-window, photo and
  map steps as the others.
