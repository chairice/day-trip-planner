"""A faint dotted flight path that trails the paper-plane cursor.

Plain DOM + requestAnimationFrame rather than component state, so mouse
movement never re-renders the app. Skipped on touch screens and for
people who ask for reduced motion.
"""

glob TRAIL_DOTS: int = 9;

def startTrail {
    fine: any = window.matchMedia("(pointer: fine)");
    still: any = window.matchMedia("(prefers-reduced-motion: reduce)");
    if not fine.matches or still.matches or document.querySelector(".trail-dot") {
        return;
    }
    body: any = document.body;
    dots: list[any] = [];
    for i in range(TRAIL_DOTS) {
        el: any = document.createElement("span");
        el.className = "trail-dot";
        el.style.opacity = str(0.42 - i * 0.04);
        body.appendChild(el);
        dots.append({"el": el, "x": -40, "y": -40});
    }
    mouse: dict[str, float] = {"x": -40, "y": -40};
    window.addEventListener(
        "mousemove",
        lambda (e: any) {
            # Trail leaves from the plane's tail, not its nose.
            mouse["x"] = e.clientX + 15;
            mouse["y"] = e.clientY + 17;
        }
    );
    def step {
        x = mouse["x"];
        y = mouse["y"];
        for d in dots {
            d["x"] = d["x"] + (x - d["x"]) * 0.38;
            d["y"] = d["y"] + (y - d["y"]) * 0.38;
            d["el"].style.transform = "translate(" + str(d["x"]) + "px," + str(d["y"]) + "px)";
            x = d["x"];
            y = d["y"];
        }
        requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
}

def:pub FlightTrail -> JsxElement {
    can with entry {
        startTrail();
    }
    return <></>;
}
