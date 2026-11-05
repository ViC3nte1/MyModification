// Positive means next (incoming from the right); negative means previous.
function selectDirection(previous, current, entries) {
    if (!previous || !current || previous === current || !entries || entries.length < 2)
        return 0;

    let previousIndex = -1;
    let currentIndex = -1;
    for (let i = 0; i < entries.length; i++) {
        if (entries[i].path === previous)
            previousIndex = i;
        if (entries[i].path === current)
            currentIndex = i;
    }

    if (previousIndex < 0 || currentIndex < 0)
        return 0;

    // Check next first, matching the old renderer when two entries wrap both ways.
    if ((previousIndex + 1) % entries.length === currentIndex)
        return 1;
    if ((previousIndex - 1 + entries.length) % entries.length === currentIndex)
        return -1;
    return 0;
}
