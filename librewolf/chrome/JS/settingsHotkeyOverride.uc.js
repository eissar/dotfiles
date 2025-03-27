// ==UserScript==
// @name            Open Settings Shortcut Override
// @author          eissar
// @onlyonce
// ==/UserScript==
UC_API.Hotkeys.define({
    // one or more of: alt, shift, ctrl, meta, accel. separated by space, enclosed by quotes.
    // ctrl + shift
    modifiers: 'accel',
    // one of: A-Z, - (hyphen), or F1-F12. enclosed by quotes.
    key: 'VK_OEM_COMMA',
    // key ID. don't change this.
    id: 'key_openSettings',
    command: (win) => {
        if (win === window) {
            URILoadingHelper.openTrustedLinkIn(window, 'about:preferences', 'tab');
        }
    },
}).attachToWindow(window, { suppressOriginal: true });
