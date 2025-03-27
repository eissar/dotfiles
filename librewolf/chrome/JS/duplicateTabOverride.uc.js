// ==UserScript==
// @name            Duplicate Tab Shortcut Override
// @author          eissar
// @onlyonce
// ==/UserScript==

UC_API.Hotkeys.define({
    // one or more of: alt, shift, ctrl, meta, accel. separated by space, enclosed by quotes.
    // ctrl + shift
    modifiers: 'accel shift',
    // one of: A-Z, - (hyphen), or F1-F12. enclosed by quotes.
    key: 'K',
    // key ID. don't change this.
    id: 'key_duplicateTab',
    command: (win) => {
        if (win === window) {
            const nt = gBrowser.duplicateTab(gBrowser.selectedTab);
            gBrowser.selectedTab = nt;
        }
    },
}).attachToWindow(window, { suppressOriginal: true });

