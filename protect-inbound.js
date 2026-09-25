// Best-effort UI patch: hides the delete button on the row whose
// remark is "جینکس | Super JinX", so it can't be accidentally
// removed from the panel UI. This does NOT touch the backend API —
// it's a front-end convenience only, and 3x-ui's static asset paths
// can change between versions, so double-check this still matches
// after you update the panel.
//
// How to use: 3x-ui doesn't officially support custom JS injection,
// so the cleanest way is to serve this file yourself (e.g. via a
// tiny reverse-proxy in front of the panel) and inject a
// <script src="/protect-inbound.js"></script> tag into the
// inbounds page response. If that's more than you want to maintain,
// it's simplest to just remember not to click delete on this one —
// the API-level protection (re-creation on every boot in
// setup-inbound.sh) matters more anyway, since it means even if the
// inbound IS deleted, it comes back on the next restart/redeploy.
(function () {
  const PROTECTED_REMARK = "جینکس | Super JinX";

  function hideDeleteButtons() {
    document.querySelectorAll("tr").forEach((row) => {
      if (row.textContent.includes(PROTECTED_REMARK)) {
        row.querySelectorAll("button, .el-button").forEach((btn) => {
          const label = (btn.textContent || "").trim().toLowerCase();
          if (label.includes("delete") || label.includes("حذف")) {
            btn.style.display = "none";
          }
        });
      }
    });
  }

  const observer = new MutationObserver(hideDeleteButtons);
  observer.observe(document.body, { childList: true, subtree: true });
  hideDeleteButtons();
})();
