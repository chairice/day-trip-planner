"""Web app entry: file-based routing over web/pages/."""

import "./trip/trip.css";

import from .trip.FlightTrail { FlightTrail }

def:pub app(children: any) -> JsxElement {
    return <><FlightTrail/>{children}</>;
}
