"""Dress code as a packing checklist, plus a photo of the outfit you picked."""

def:pub DressCard(
    dress: any,
    packed: list[str],
    photo: str,
    uploading: bool,
    uploadError: str,
    onToggle: Callable[[str], None],
    onPhoto: Callable[[any], None],
    onRemovePhoto: Callable[[], None]
) -> JsxElement {
    done = len([i for i in dress["items"] if i in packed]);
    return
        <aside class="dress">
            <h3 class="dress-title">What to wear</h3>
            <p class="dress-head">{dress["headline"]} <em>/ {dress["season"]}</em></p>
            <ul class="dress-list">
                {[
                    <li key={item}>
                        <label class={"pack " + ("on" if item in packed else "")}>
                            <input
                                type="checkbox"
                                checked={item in packed}
                                onChange={lambda { onToggle(item); }}
                            />
                            <span class="pack-box"></span>
                            <span class="pack-text">{item}</span>
                        </label>
                    </li> for item in dress["items"]
                ]}
            </ul>
            <p class="dress-count">{done} of {len(dress["items"])} packed</p>
            <p class="dress-note">{dress["note"]}</p>

            <div class="outfit">
                <h4 class="outfit-title">Today's outfit</h4>
                {(
                    <figure class="outfit-photo">
                        <img src={photo} alt="Outfit for this trip"/>
                    </figure>
                ) if photo else None}
                <div class="outfit-actions">
                    <label class={"upload " + ("busy" if uploading else "")}>
                        <input
                            type="file"
                            accept="image/*"
                            disabled={uploading}
                            onChange={lambda (e: ChangeEvent) {
                                onPhoto(e.target.files[0] if e.target.files else None);
                                e.target.value = "";
                            }}
                        />
                        {("Adding…" if uploading else ("Replace photo" if photo else "Add outfit photo"))}
                    </label>
                    {(
                        <button class="delete" onClick={lambda { onRemovePhoto(); }}>Remove</button>
                    ) if photo and not uploading else None}
                </div>
                {(<p class="outfit-error">{uploadError}</p>) if uploadError else None}
            </div>
        </aside>;
}
