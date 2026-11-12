import QtQuick
import QtWebEngine
import Tacit.Kit as K
import Tacit.MailHtml
import "fixtures/roastmarket.js" as Roastmarket

Item {
    id: view

    required property string html
    property string fixture: ""
    readonly property string documentHtml: fixture === "roastmarket" ? Roastmarket.html : html
    readonly property bool ready: browser.loaded
    readonly property bool loading: browser.loadingMessage
    readonly property real progress: browser.displayProgress
    signal externalLinkRequested(url link)
    implicitHeight: browser.height
    clip: true

    function openLink(link) {
        if (/^https?:\/\//i.test(link.toString()))
            externalLinkRequested(link);
    }

    MailWebProfile {
        id: mailProfile
        onDownloadRequested: download => download.cancel()
    }

    WebEngineView {
        id: browser

        property bool loaded: false
        property bool loadingMessage: false
        property bool waitingForLayout: false
        property bool initialized: false
        property real displayProgress: 0
        property int documentRevision: 0
        width: parent.width
        height: 1
        profile: mailProfile
        backgroundColor: K.Kit.tokens.windowGround

        settings.javascriptEnabled: false
        settings.javascriptCanOpenWindows: false
        settings.localContentCanAccessFileUrls: false
        settings.localContentCanAccessRemoteUrls: false
        settings.dnsPrefetchEnabled: false
        settings.hyperlinkAuditingEnabled: false
        settings.errorPageEnabled: false
        settings.unknownUrlSchemePolicy: WebEngineSettings.DisallowUnknownUrlSchemes

        function loadMessage() {
            ++documentRevision;
            measureLayout.stop();
            waitingForLayout = false;
            loaded = false;
            displayProgress = 0;
            loadingMessage = true;
            height = 1;
            const t = K.Kit.tokens;
            loadHtml("<!doctype html><meta charset='utf-8'>"
                + "<meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; img-src data:; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'\">"
                + "<meta http-equiv='x-dns-prefetch-control' content='off'>"
                + "<style>body{margin:0;color:" + t.inkMain + ";background:" + t.windowGround
                + ";font:" + t.size.body + "px sans-serif;overflow-wrap:anywhere}"
                + "a{color:" + t.accent + "}img{max-width:100%;height:auto}</style>"
                + view.documentHtml);
        }
        function fitDocument() {
            const revision = documentRevision;
            const measuredWidth = width;
            // Query actual DOM geometry in our isolated world. The page's own scripts stay disabled.
            runJavaScript("Math.max(document.body.scrollHeight, document.body.offsetHeight)", 1, result => {
                if (revision !== documentRevision || measuredWidth !== width || (!waitingForLayout && !loaded))
                    return;
                if (!Number.isFinite(result)) {
                    loaded = false;
                    waitingForLayout = false;
                    loadingMessage = false;
                    return;
                }
                height = Math.max(1, Math.ceil(result));
                waitingForLayout = false;
                loaded = true;
                loadingMessage = false;
            });
        }

        Timer {
            id: measureLayout
            interval: 40
            onTriggered: browser.fitDocument()
        }

        Component.onCompleted: {
            initialized = true;
            loadMessage();
        }
        onWidthChanged: if (loaded || waitingForLayout) measureLayout.restart()
        onLoadProgressChanged: if (loadingMessage) displayProgress = Math.max(displayProgress, loadProgress / 100)
        onLoadingChanged: info => {
            if (info.status === WebEngineView.LoadSucceededStatus) {
                displayProgress = 1;
                waitingForLayout = true;
                measureLayout.restart();
            } else if (info.status === WebEngineView.LoadFailedStatus || info.status === WebEngineView.LoadStoppedStatus) {
                measureLayout.stop();
                waitingForLayout = false;
                loadingMessage = false;
            }
        }
        onRenderProcessTerminated: {
            measureLayout.stop();
            waitingForLayout = false;
            loaded = false;
            loadingMessage = false;
        }
        onNavigationRequested: request => {
            if (request.navigationType === WebEngineNavigationRequest.LinkClickedNavigation) {
                request.reject();
                view.openLink(request.url);
            } else if (!request.isMainFrame || request.navigationType !== WebEngineNavigationRequest.TypedNavigation
                       || !request.url.toString().startsWith("data:text/html")) {
                request.reject();
            }
        }
        onNewWindowRequested: request => {
            if (request.userInitiated)
                view.openLink(request.requestedUrl);
        }
        onContextMenuRequested: request => request.accepted = true
        onFileDialogRequested: request => request.dialogReject()
        onPermissionRequested: permission => permission.deny()
    }

    onDocumentHtmlChanged: if (browser.initialized) browser.loadMessage()
}
