// ==UserScript==
// @name            launch
// @author          eissar
// @onlyonce
// ==/UserScript==
// TODO: bind to menu or sub-menu so we can do some chording.
/**
 * Finds and activates a tab based on the specified target host.
 *
 * @param {string} target_host -  host name of the target URI to find and activate.
 */
function find_and_activate(target_host) {
    console.log('finding...');
    let found = false;
    UC_API.Windows.forEach((_document, window) => {
        if (found) return;
        const tabs = window.gBrowser.browsers;
        for (let i = 0; i < tabs.length; i++) {
            if (tabs[i].currentURI.asciiHost === target_host) {
                found = true;
                // console.log(window.gBrowser,i, tabs[i]);
                // console.log(tabs[i].currentURI.asciiSpec);
                const switchToUri = tabs[i].currentURI.asciiSpec;
                //switchToTabHavingURI(switchToUri, false, { adoptIntoActiveWindow: true });
                switchToTabHavingURI(switchToUri, false);
                break;
            }
        }
    });
}
UC_API.Hotkeys.define({
    // one or more of: alt, shift, ctrl, meta, accel. separated by space, enclosed by quotes.
    modifiers: 'accel shift',
    // one of: A-Z, - (hyphen), or F1-F12. enclosed by quotes.
    key: 'l',
    // key ID. don't change this.
    id: 'key_runLaunch',
    command: () => find_and_activate('gemini.google.com'),
}).autoAttach({ suppressOriginal: true });
