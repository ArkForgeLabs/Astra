// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded affix "><a href="introduction.html">Introduction</a></li><li class="chapter-item expanded affix "><a href="getting_started.html">Getting Started</a></li><li class="chapter-item expanded affix "><li class="part-title">API</li><li class="chapter-item expanded "><a href="std/http/main.html"><strong aria-hidden="true">1.</strong> HTTP</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="std/http/http_server.html"><strong aria-hidden="true">1.1.</strong> HTTP Server</a></li><li class="chapter-item expanded "><a href="std/http/http_client.html"><strong aria-hidden="true">1.2.</strong> HTTP Client</a></li></ol></li><li class="chapter-item expanded "><a href="std/templating.html"><strong aria-hidden="true">2.</strong> Templating</a></li><li class="chapter-item expanded "><a href="std/validation.html"><strong aria-hidden="true">3.</strong> Validation</a></li><li class="chapter-item expanded "><a href="std/sql_driver.html"><strong aria-hidden="true">4.</strong> SQL Driver</a></li><li class="chapter-item expanded "><a href="std/file_io.html"><strong aria-hidden="true">5.</strong> File IO</a></li><li class="chapter-item expanded "><a href="std/crypto.html"><strong aria-hidden="true">6.</strong> Crypto</a></li><li class="chapter-item expanded "><a href="std/serde.html"><strong aria-hidden="true">7.</strong> Serialization &amp; Deserialization</a></li><li class="chapter-item expanded "><a href="std/datetime.html"><strong aria-hidden="true">8.</strong> DateTime</a></li><li class="chapter-item expanded "><a href="std/utilities.html"><strong aria-hidden="true">9.</strong> Utilities</a></li><li class="chapter-item expanded "><a href="std/mem_stores.html"><strong aria-hidden="true">10.</strong> In-Memory Stores</a></li><li class="chapter-item expanded affix "><li class="part-title">Extending Astra</li><li class="chapter-item expanded "><a href="internals/structure.html"><strong aria-hidden="true">11.</strong> Structure</a></li><li class="chapter-item expanded "><a href="internals/adding_components.html"><strong aria-hidden="true">12.</strong> Adding Components</a></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split("#")[0].split("?")[0];
        if (current_page.endsWith("/")) {
            current_page += "index.html";
        }
        var links = Array.prototype.slice.call(this.querySelectorAll("a"));
        var l = links.length;
        for (var i = 0; i < l; ++i) {
            var link = links[i];
            var href = link.getAttribute("href");
            if (href && !href.startsWith("#") && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The "index" page is supposed to alias the first chapter in the book.
            if (link.href === current_page || (i === 0 && path_to_root === "" && current_page.endsWith("/index.html"))) {
                link.classList.add("active");
                var parent = link.parentElement;
                if (parent && parent.classList.contains("chapter-item")) {
                    parent.classList.add("expanded");
                }
                while (parent) {
                    if (parent.tagName === "LI" && parent.previousElementSibling) {
                        if (parent.previousElementSibling.classList.contains("chapter-item")) {
                            parent.previousElementSibling.classList.add("expanded");
                        }
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', function(e) {
            if (e.target.tagName === 'A') {
                sessionStorage.setItem('sidebar-scroll', this.scrollTop);
            }
        }, { passive: true });
        var sidebarScrollTop = sessionStorage.getItem('sidebar-scroll');
        sessionStorage.removeItem('sidebar-scroll');
        if (sidebarScrollTop) {
            // preserve sidebar scroll position when navigating via links within sidebar
            this.scrollTop = sidebarScrollTop;
        } else {
            // scroll sidebar to current active section when navigating via "next/previous chapter" buttons
            var activeSection = document.querySelector('#sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        var sidebarAnchorToggles = document.querySelectorAll('#sidebar a.toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(function (el) {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define("mdbook-sidebar-scrollbox", MDBookSidebarScrollbox);
