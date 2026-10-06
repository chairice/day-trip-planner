"""Mobile app: check today's trip on the go, browse saved trips, plan new ones.

Same walkers as the web app (core/trip/walkers.jac), bridged over HTTP to
the server that `jac run` starts.
"""

import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn }
import from "@jac/mobui" {
    View,
    Text,
    Pressable,
    TextInput,
    ScrollView,
    Image,
    ActivityIndicator,
    StatusBar,
    StyleSheet,
    Linking,
    Platform,
    useWindowDimensions
}

import from core.trip.walkers {
    PlanTrip,
    ListTrips,
    TodayTrip,
    GetTrip,
    ToggleStop,
    TogglePacked
}

# --- Native styles: the same sea-glass guidebook palette as the web app ---

glob C: dict[str, str] = {
         "paper": "#e9f2ef",
         "paper2": "#d9e9e5",
         "ink": "#16262b",
         "inkSoft": "#3a4f55",
         "muted": "#52696f",
         "rule": "#b4cdc9",
         "accent": "#2c6a99",
         "green": "#2f7356"
     };

glob SERIF: str = Platform.select({"ios": "Georgia", "android": "serif", "default": "Fraunces, Georgia, serif"});
glob MONO: str = Platform.select({"ios": "Menlo", "android": "monospace", "default": "'IBM Plex Mono', ui-monospace, monospace"});

glob S: any = StyleSheet.create(
    {
        "root": {"flex": 1, "backgroundColor": C["paper"]},
        "scroll": {"padding": 18, "paddingBottom": 110, "gap": 16},
        "center": {"flex": 1, "justifyContent": "center", "backgroundColor": C["paper"], "padding": 24},
        "logo": {"color": C["ink"], "fontSize": 24, "fontFamily": SERIF, "fontStyle": "italic"},
        "label": {"color": C["accent"], "fontSize": 11, "fontFamily": MONO, "letterSpacing": 1.2, "textTransform": "uppercase"},
        "h1": {"color": C["ink"], "fontSize": 34, "fontFamily": SERIF, "lineHeight": 38},
        "h2": {"color": C["ink"], "fontSize": 22, "fontFamily": SERIF, "fontStyle": "italic"},
        "muted": {"color": C["muted"], "fontSize": 14},
        "mono": {"color": C["muted"], "fontSize": 12, "fontFamily": MONO},
        "header": {"flexDirection": "row", "justifyContent": "space-between", "alignItems": "flex-end", "paddingTop": 54, "paddingBottom": 10, "marginHorizontal": 18, "borderBottomWidth": 3, "borderBottomColor": C["ink"]},
        "input": {"color": C["ink"], "borderBottomColor": C["ink"], "borderBottomWidth": 2, "paddingVertical": 10, "fontSize": 22, "fontFamily": SERIF},
        "button": {"backgroundColor": C["ink"], "paddingVertical": 15, "alignItems": "center", "shadowColor": C["accent"], "shadowOffset": {"width": 4, "height": 4}, "shadowOpacity": 1, "shadowRadius": 0, "elevation": 0, "borderRightWidth": 4, "borderBottomWidth": 4, "borderColor": C["accent"]},
        "buttonText": {"color": C["paper"], "fontWeight": "600", "fontSize": 16},
        "link": {"color": C["muted"], "fontSize": 12, "fontFamily": MONO, "textTransform": "uppercase", "letterSpacing": 1},
        "error": {"color": C["accent"], "fontFamily": MONO, "fontSize": 13},
        "chips": {"flexDirection": "row", "flexWrap": "wrap", "gap": 16},
        "chip": {"paddingVertical": 4, "borderBottomWidth": 1, "borderBottomColor": C["rule"]},
        "chipOn": {"borderBottomColor": C["accent"], "borderBottomWidth": 2},
        "chipText": {"color": C["inkSoft"], "fontSize": 15, "textTransform": "capitalize"},
        "chipTextOn": {"color": C["accent"]},
        "photo": {"backgroundColor": C["paper2"], "padding": 6, "borderWidth": 1, "borderColor": C["rule"]},
        "hero": {"height": 210},
        "rule": {"height": 1, "backgroundColor": C["rule"]},
        "progress": {"height": 3, "backgroundColor": C["rule"]},
        "progressFill": {"height": 3, "backgroundColor": C["accent"]},
        "stop": {"paddingVertical": 20, "borderBottomWidth": 1, "borderBottomColor": C["rule"], "gap": 8},
        "stopImg": {"height": 170},
        "photoBox": {"alignItems": "center", "justifyContent": "center"},
        "photoLabel": {"position": "absolute", "color": C["muted"], "fontSize": 18, "fontFamily": SERIF, "fontStyle": "italic", "textAlign": "center", "paddingHorizontal": 12},
        "fill": {"position": "absolute", "top": 0, "left": 0, "right": 0, "bottom": 0},
        "imgDone": {"opacity": 0.45},
        "row": {"flexDirection": "row", "alignItems": "center", "gap": 10},
        "time": {"color": C["ink"], "fontWeight": "600", "fontSize": 14, "fontFamily": MONO},
        "stopTitle": {"color": C["ink"], "fontSize": 24, "fontFamily": SERIF, "lineHeight": 28},
        "titleDone": {"textDecorationLine": "line-through", "textDecorationColor": C["accent"], "color": C["muted"]},
        "area": {"color": C["muted"], "fontSize": 13, "textDecorationLine": "underline", "textDecorationStyle": "dotted"},
        "body": {"color": C["inkSoft"], "fontSize": 15, "lineHeight": 22},
        "tip": {"color": C["inkSoft"], "fontSize": 14, "lineHeight": 20, "fontStyle": "italic"},
        "tipLabel": {"color": C["accent"], "fontSize": 11, "fontFamily": MONO, "fontStyle": "normal"},
        "check": {"flexDirection": "row", "alignItems": "center", "gap": 8},
        "box": {"width": 18, "height": 18, "borderWidth": 1.5, "borderColor": C["muted"], "alignItems": "center", "justifyContent": "center"},
        "boxOn": {"borderColor": C["accent"]},
        "boxTick": {"color": C["accent"], "fontSize": 13, "fontWeight": "700", "lineHeight": 15},
        "dish": {"flexDirection": "row", "alignItems": "baseline", "gap": 8},
        "dishName": {"color": C["ink"], "fontSize": 17, "fontFamily": SERIF},
        "dishDots": {"flex": 1, "borderBottomWidth": 2, "borderBottomColor": C["rule"], "borderStyle": "dotted", "marginBottom": 4},
        "dishPrice": {"color": C["green"], "fontSize": 13, "fontFamily": MONO},
        "directions": {"color": C["ink"], "fontSize": 13, "fontFamily": MONO, "textDecorationLine": "underline"},
        "dress": {"backgroundColor": C["paper2"], "borderTopWidth": 3, "borderTopColor": C["ink"], "padding": 16, "gap": 4},
        "dressRow": {"paddingVertical": 8, "borderBottomWidth": 1, "borderBottomColor": C["rule"], "borderStyle": "dashed"},
        "dressText": {"color": C["ink"], "fontSize": 15, "flex": 1},
        "tripRow": {"flexDirection": "row", "backgroundColor": C["paper2"], "borderLeftWidth": 2, "borderLeftColor": C["rule"], "borderStyle": "dashed"},
        "thumb": {"width": 72, "height": 80, "backgroundColor": C["rule"]},
        "tabs": {"position": "absolute", "left": 0, "right": 0, "bottom": 0, "flexDirection": "row", "backgroundColor": C["paper"], "borderTopColor": C["ink"], "borderTopWidth": 3, "paddingBottom": 24, "paddingTop": 12},
        "tab": {"flex": 1, "alignItems": "center"},
        "tabText": {"color": C["muted"], "fontSize": 12, "fontFamily": MONO, "textTransform": "uppercase", "letterSpacing": 1.2},
        "tabOn": {"color": C["accent"]}
    }
);

def openMap(url: str) {
    if url {
        Linking.openURL(url);
    }
}

def:pub StopRow(stop: any, onToggle: Callable[[], None]) -> JsxElement {
    isFood = stop["kind"] == "food";
    return
        <View style={S.stop}>
            <View style={[S.photo, S.photoBox]}>
                <View style={S.stopImg}/>
                <Text style={S.photoLabel}>{stop["title"]}</Text>
                {(
                    <Image source={{"uri": stop["image"]}} style={[S.fill, {"margin": 6}, S.imgDone if stop["done"] else {}]}/>
                ) if stop["image"] else None}
            </View>
            <View style={[S.row, {"justifyContent": "space-between"}]}>
                <View style={S.row}>
                    <Text style={S.time}>{stop["time"]}</Text>
                    <Text style={[S.label, {"color": C["green"]} if isFood else {}]}>
                        {("Eat" if isFood else "See")}
                    </Text>
                </View>
                <Pressable testID="check-stop" style={S.check} onPress={lambda { onToggle(); }}>
                    <View style={[S.box, S.boxOn if stop["done"] else {}]}>
                        <Text style={S.boxTick}>{("✓" if stop["done"] else "")}</Text>
                    </View>
                    <Text style={[S.link, S.tabOn if stop["done"] else {}]}>{("Been" if stop["done"] else "Go")}</Text>
                </Pressable>
            </View>
            <Pressable onPress={lambda { openMap(stop["map"]); }} disabled={isFood}>
                <Text style={[S.stopTitle, S.titleDone if stop["done"] else {}]}>{stop["title"]}</Text>
            </Pressable>
            <Pressable onPress={lambda { openMap(stop["map"]); }}>
                <Text style={S.area}>{stop["area"]}</Text>
            </Pressable>
            <Text style={S.body}>{stop["blurb"]}</Text>
            <Text style={S.tip}><Text style={S.tipLabel}>TIP  </Text>{stop["tip"]}</Text>
            {[
                <Pressable key={o["name"]} onPress={lambda { openMap(o["map"]); }}>
                    <View style={S.dish}>
                        <Text style={S.dishName}>{o["name"]} ↗</Text>
                        <View style={S.dishDots}/>
                        <Text style={S.dishPrice}>{o["price"]}</Text>
                    </View>
                    <Text style={S.mono}>{(o["cuisine"] + ", get the " + o["dish"]) if o["dish"] else o["cuisine"]}</Text>
                </Pressable> for o in stop["options"]
            ]}
            {(
                <Pressable onPress={lambda { openMap(stop["map"]); }}>
                    <Text style={S.directions}>Directions ↗</Text>
                </Pressable>
            ) if not isFood else None}
        </View>;
}

def:pub TripView(
    trip: any,
    onToggle: Callable[[str], None],
    onPack: Callable[[str], None]
) -> JsxElement {
    packed = trip["packed"] or [];
    pct = int(100 * trip["done_count"] / max(1, trip["stop_count"]));
    return
        <View style={{"gap": 16}}>
            <View style={[S.photo, S.photoBox]}>
                <View style={S.hero}/>
                <Text style={[S.photoLabel, {"fontSize": 28}]}>{trip["city"]}</Text>
                {(<Image source={{"uri": trip["image"]}} style={[S.fill, {"margin": 6}]}/>) if trip["image"] else None}
            </View>
            <View style={{"gap": 8}}>
                <Text style={S.label}>{trip["date"]} · {trip["window"]} · {trip["season"]} · {trip["vibe"]}</Text>
                <Text style={S.h1}>{trip["city"]}</Text>
                <Text style={[S.body, {"fontFamily": SERIF, "fontStyle": "italic", "fontSize": 18}]}>{trip["tagline"]}</Text>
            </View>
            <View style={{"gap": 8}}>
                <Text style={S.mono}>{trip["done_count"]} of {trip["stop_count"]} stops visited</Text>
                <View style={S.progress}>
                    <View style={[S.progressFill, {"width": str(pct) + "%"}]}/>
                </View>
            </View>
            <View style={S.dress}>
                <Text style={S.h2}>What to wear</Text>
                <Text style={S.muted}>{trip["dress"]["headline"]} / {trip["dress"]["season"]}</Text>
                {[
                    <Pressable
                        key={item}
                        testID="check-pack"
                        style={[S.row, S.dressRow]}
                        onPress={lambda { onPack(item); }}
                    >
                        <View style={[S.box, S.boxOn if item in packed else {}]}>
                            <Text style={S.boxTick}>{("✓" if item in packed else "")}</Text>
                        </View>
                        <Text style={[S.dressText, S.titleDone if item in packed else {}]}>{item}</Text>
                    </Pressable> for item in trip["dress"]["items"]
                ]}
                <Text style={[S.tip, {"marginTop": 8}]}>{trip["dress"]["note"]}</Text>
                {(
                    <View style={[S.photo, {"marginTop": 12}]}>
                        <Image source={{"uri": trip["outfit"]["photo"]}} style={{"height": 260}}/>
                    </View>
                ) if trip["outfit"] and "photo" in trip["outfit"] else None}
            </View>
            <View>
                {[
                    <StopRow
                        key={s["id"]}
                        stop={s}
                        onToggle={lambda { onToggle(s["id"]); }}
                    /> for s in trip["stops"]
                ]}
            </View>
        </View>;
}

def:pub AuthScreen(onAuth: Callable[[], None]) -> JsxElement {
    has username: str = "",
        password: str = "",
        signup: bool = False,
        busy: bool = False,
        error: str = "";

    async def submit {
        if not username.strip() or not password {
            error = "Enter a username and password.";
            return;
        }
        busy = True;
        error = "";
        if signup {
            made = await jacSignup(username, password);
            if not made["success"] {
                busy = False;
                error = str(made["error"]) if made["error"] else "Sign-up failed";
                return;
            }
        }
        ok = await jacLogin(username, password);
        busy = False;
        if ok {
            onAuth();
        } else {
            error = "Invalid username or password";
        }
    }

    return
        <View style={[S.center, {"gap": 16}]}>
            <Text style={S.logo}>Day Trip</Text>
            <Text style={S.h1}>A day somewhere, planned hour by hour.</Text>
            <Text style={S.label}>{("Create your account" if signup else "Welcome back")}</Text>
            <TextInput
                style={S.input}
                value={username}
                placeholder="Username"
                placeholderTextColor={C["rule"]}
                autoCapitalize="none"
                onChangeText={lambda (t: str) { username = t; }}
            />
            <TextInput
                style={S.input}
                value={password}
                placeholder="Password"
                placeholderTextColor={C["rule"]}
                secureTextEntry={True}
                onChangeText={lambda (t: str) { password = t; }}
            />
            {(<Text style={S.error}>{error}</Text>) if error else None}
            <Pressable style={S.button} onPress={lambda { submit(); }} disabled={busy}>
                <Text style={S.buttonText}>
                    {("…" if busy else ("Sign up" if signup else "Sign in"))}
                </Text>
            </Pressable>
            <Pressable onPress={lambda { signup = not signup; error = ""; }}>
                <Text style={[S.muted, {"textDecorationLine": "underline"}]}>
                    {("Have an account? Sign in" if signup else "New here? Create an account")}
                </Text>
            </Pressable>
        </View>;
}

def:pub app -> JsxElement {
    has loggedIn: bool = False,
        checking: bool = True,
        tab: str = "today",
        trip: any = None,
        trips: list[any] = [],
        busy: bool = False,
        error: str = "",
        city: str = "",
        vibe: str = "classic",
        hours: str = "Full day";

    # Fill the viewport so the paper background reaches the bottom on web too.
    win = useWindowDimensions();

    can with entry {
        loggedIn = jacIsLoggedIn();
        checking = False;
        if loggedIn {
            loadToday();
        }
    }

    async def loadToday {
        busy = True;
        try {
            res = root spawn TodayTrip();
            trip = res.reports[0] if res.reports else None;
        } except Exception as e {
            error = "Can't reach the server. Is `jac run` running?";
        }
        busy = False;
    }

    async def loadTrips {
        res = root spawn ListTrips();
        trips = res.reports[0] if res.reports else [];
    }

    async def openTrip(tripId: str) {
        res = root spawn GetTrip(trip_id=tripId);
        trip = res.reports[0] if res.reports else None;
        tab = "today";
    }

    async def pack(item: str) {
        res = root spawn TogglePacked(trip_id=trip["id"], item=item);
        if res.reports and res.reports[0] {
            trip = res.reports[0];
        }
    }

    async def toggle(stopId: str) {
        res = root spawn ToggleStop(trip_id=trip["id"], stop_id=stopId);
        if res.reports and res.reports[0] {
            trip = res.reports[0];
        }
    }

    async def plan {
        if not city.strip() {
            error = "Where to?";
            return;
        }
        busy = True;
        error = "";
        try {
            w = {
                "Full day": ["08:00", "22:00"],
                "Morning": ["08:00", "12:00"],
                "Midday": ["11:00", "17:00"],
                "Evening": ["17:00", "23:00"]
            }[hours];
            res = root spawn PlanTrip(city=city, vibe=vibe, start=w[0], end=w[1]);
            trip = res.reports[0] if res.reports else None;
            city = "";
            tab = "today";
        } except Exception as e {
            error = "Couldn't plan that trip — try again.";
        }
        busy = False;
    }

    def go(name: str) {
        tab = name;
        error = "";
        if name == "trips" {
            loadTrips();
        }
    }

    def logout {
        jacLogout();
        loggedIn = False;
        trip = None;
        trips = [];
    }

    if checking {
        return
            <View style={[S.center, {"minHeight": win.height}]}><ActivityIndicator color={C["accent"]}/></View>;
    }
    if not loggedIn {
        return
            <View style={[S.root, {"minHeight": win.height}]}>
                <StatusBar barStyle="dark-content"/>
                <AuthScreen onAuth={lambda { loggedIn = True; loadToday(); }}/>
            </View>;
    }

    body = None;
    if tab == "today" {
        body = (
            <View style={{"gap": 14}}>
                <Text style={S.label}>Today's plan</Text>
                {(<ActivityIndicator color={C["accent"]}/>) if busy else None}
                {(
                    <TripView
                        trip={trip}
                        onToggle={lambda (id: str) { toggle(id); }}
                        onPack={lambda (item: str) { pack(item); }}
                    />
                ) if trip else (
                    <View style={[S.dress, {"padding": 18, "gap": 12}]}>
                        <Text style={S.h2}>No trip yet</Text>
                        <Text style={S.muted}>Plan one here, on the web, or from the CLI.</Text>
                        <Pressable style={S.button} onPress={lambda { go("plan"); }}>
                            <Text style={S.buttonText}>Plan a trip</Text>
                        </Pressable>
                    </View>
                )}
            </View>
        );
    } elif tab == "trips" {
        body = (
            <View style={{"gap": 12}}>
                <Text style={S.h2}>Your trips <Text style={S.mono}>{len(trips)}</Text></Text>
                {[
                    <Pressable
                        key={t["id"]}
                        style={S.tripRow}
                        onPress={lambda { openTrip(t["id"]); }}
                    >
                        {(<Image source={{"uri": t["image"]}} style={S.thumb}/>) if t["image"] else <View style={S.thumb}/>}
                        <View style={{"flex": 1, "gap": 4, "padding": 12}}>
                            <Text style={[S.stopTitle, {"fontSize": 20}]}>{t["city"]}</Text>
                            <Text style={S.mono}>{t["date"]}</Text>
                            <Text style={S.mono}>{t["done_count"]} of {t["stop_count"]} visited</Text>
                        </View>
                    </Pressable> for t in trips
                ]}
            </View>
        );
    } else {
        body = (
            <View style={{"gap": 14}}>
                <Text style={S.label}>Plan a day</Text>
                <Text style={S.h1}>Where to?</Text>
                <TextInput
                    style={S.input}
                    value={city}
                    placeholder="e.g. Paris"
                    placeholderTextColor={C["rule"]}
                    onChangeText={lambda (t: str) { city = t; }}
                />
                <View style={S.chips}>
                    {[
                        <Pressable
                            key={c}
                            style={[S.chip, S.chipOn if c == city else {}]}
                            onPress={lambda { city = c; }}
                        ><Text style={[S.chipText, S.chipTextOn if c == city else {}]}>{c}</Text></Pressable>
                        for c in ["New York", "Paris", "Tokyo", "Chicago"]
                    ]}
                </View>
                <Text style={S.label}>Hours</Text>
                <View style={S.chips}>
                    {[
                        <Pressable
                            key={h}
                            style={[S.chip, S.chipOn if h == hours else {}]}
                            onPress={lambda { hours = h; }}
                        ><Text style={[S.chipText, S.chipTextOn if h == hours else {}]}>{h}</Text></Pressable>
                        for h in ["Full day", "Morning", "Midday", "Evening"]
                    ]}
                </View>
                <Text style={S.label}>Vibe</Text>
                <View style={S.chips}>
                    {[
                        <Pressable
                            key={v}
                            style={[S.chip, S.chipOn if v == vibe else {}]}
                            onPress={lambda { vibe = v; }}
                        ><Text style={[S.chipText, S.chipTextOn if v == vibe else {}]}>{v}</Text></Pressable>
                        for v in ["classic", "foodie", "adventure", "chill"]
                    ]}
                </View>
                <Pressable style={S.button} onPress={lambda { plan(); }} disabled={busy}>
                    <Text style={S.buttonText}>{("Planning…" if busy else "Plan the day")}</Text>
                </Pressable>
            </View>
        );
    }

    return
        <View style={[S.root, {"minHeight": win.height}]}>
            <StatusBar barStyle="dark-content"/>
            <View style={S.header}>
                <Text style={S.logo}>Day Trip</Text>
                <Pressable onPress={lambda { logout(); }}>
                    <Text style={S.link}>Sign out</Text>
                </Pressable>
            </View>
            <ScrollView contentContainerStyle={S.scroll}>
                {(<Text style={S.error}>{error}</Text>) if error else None}
                {body}
            </ScrollView>
            <View style={S.tabs}>
                {[
                    <Pressable key={k} style={S.tab} onPress={lambda { go(k); }}>
                        <Text style={[S.tabText, S.tabOn if tab == k else {}]}>{label}</Text>
                    </Pressable>
                    for (k, label) in [("today", "Today"), ("trips", "Trips"), ("plan", "Plan")]
                ]}
            </View>
        </View>;
}
