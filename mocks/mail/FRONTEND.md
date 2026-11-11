# Tacit Mail frontend

Interactive QML prototype using Tacit.Kit. `MailWorkspace.qml` lays out the app, `MailState.qml` exposes its state to QML, and `mail-store.js` implements the state transitions. The prototype uses in-memory sample data. Sending, provider import and agent drafts are simulations. The Go backend and external services are outside this frontend.

## macOS preview

From `mocks/mail`, with Xcode Command Line Tools, CMake, Python 3, desktop Qt 6.8+ and a sibling `tacit-kit` checkout:

```sh
./mac-preview/run.sh
```

Pass `draft` as the first argument to start in the draft view. Set `QT_ROOT` if Qt is outside CMake's search path and `TACIT_KIT_DIR` if the Kit is elsewhere. For Qt Creator, open `mac-preview/CMakeLists.txt` with a desktop Qt kit.

The launcher builds the versioned host and stages the Kit and its fonts in the ignored `mac-preview/build-local/` directory. The staged copy gets the patch in `kit-style/` and 90% typography. The Mac host draws the Tacit window ground over native blur. Free areas can be used to drag the window.

Saving a mail QML or JavaScript file reloads the view in place and preserves the local mail model. A load error leaves the last working view open and is printed in the terminal. Restart with the launcher after changes to the native host or the staged Kit.

The **Preview** menu can simulate incoming mail, connectivity and sign-in, undo a send, or reset the session. **Preview → Palette** switches between Dusk, Moss and a Tacit `colors.json` file. Set `MAIL_PALETTE` to `dusk`, `moss` or the JSON file's absolute path to choose it at launch. A neighbouring `seethrough.json` can set the glass scale.

## Behaviour and boundaries

- The reader and message list share the window at wider sizes. At narrow widths they become separate views, with the mailbox menu providing access to folders, accounts and settings.
- Fixtures in `fixtures/` are local files. A click on an attachment chip saves a copy on macOS, and a double-click opens the preview. Sample PDF previews show a text summary.
- Quickshell starts the prototype through `mail.qml`. The shell owns sign-in, notifications and send-status UI. Integrations can listen for `authorizationRequested`, `notificationRequested` and `sendStatusChanged` on `MailState`. Call `completeAuthorization(email)`, `notificationAction(action)` or `act("undoSend")` to return the user's action.

## Checks

From `mocks/mail` with Node 18+ and Qt tools on PATH:

```sh
node tests/state.test.cjs
python3 mac-preview/prepare.py
for test in tst_frontend tst_responsive; do
    QT_QPA_PLATFORM=offscreen qmltestrunner -input "tests/$test.qml" -import mac-preview/build-local/qml || exit 1
done
```

The walkthrough test (`tests/tst_walkthrough.qml`) loads the Quickshell entry point and needs Quickshell and the Tacit shell imports.
