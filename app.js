(() => {
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => [...el.querySelectorAll(s)];

  // Navigation
  const panels = $$(".panel");
  const navItems = $$(".nav-item");

  function showPanel(id) {
    panels.forEach((p) => p.classList.toggle("active", p.id === `panel-${id}`));
    navItems.forEach((n) => n.classList.toggle("active", n.dataset.panel === id));
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  navItems.forEach((btn) => {
    btn.addEventListener("click", () => showPanel(btn.dataset.panel));
  });

  // Theme
  const themeSelect = $("#theme-select");
  const savedTheme = localStorage.getItem("void-theme") || "void";
  document.documentElement.setAttribute("data-theme", savedTheme === "void" ? "" : savedTheme);
  if (themeSelect) themeSelect.value = savedTheme;

  themeSelect?.addEventListener("change", () => {
    const v = themeSelect.value;
    localStorage.setItem("void-theme", v);
    document.documentElement.setAttribute("data-theme", v === "void" ? "" : v);
  });

  // Upload form
  const form = $("#upload-form");
  const fileInput = $("#up-file");
  const fileZone = $("#file-zone");
  const preview = $("#preview");
  const feed = $("#feed");
  let currentFile = null;
  let currentDataUrl = null;

  ["dragenter", "dragover"].forEach((ev) => {
    fileZone?.addEventListener(ev, (e) => {
      e.preventDefault();
      fileZone.classList.add("drag");
    });
  });
  ["dragleave", "drop"].forEach((ev) => {
    fileZone?.addEventListener(ev, (e) => {
      e.preventDefault();
      fileZone.classList.remove("drag");
    });
  });

  fileZone?.addEventListener("drop", (e) => {
    const f = e.dataTransfer.files?.[0];
    if (f) handleFile(f);
  });

  fileInput?.addEventListener("change", () => {
    const f = fileInput.files?.[0];
    if (f) handleFile(f);
  });

  function handleFile(file) {
    if (!file.type.startsWith("image/") && !file.type.startsWith("video/")) {
      alert("Solo se permiten fotos o videos.");
      return;
    }
    currentFile = file;
    const reader = new FileReader();
    reader.onload = () => {
      currentDataUrl = reader.result;
      preview.hidden = false;
      if (file.type.startsWith("video/")) {
        preview.innerHTML = `<video src="${currentDataUrl}" controls playsinline></video>`;
      } else {
        preview.innerHTML = `<img src="${currentDataUrl}" alt="preview" />`;
      }
    };
    reader.readAsDataURL(file);
  }

  // Feed (localStorage for demo — public within the same browser)
  const STORAGE_KEY = "void-hub-feed";

  function loadFeed() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
    } catch {
      return [];
    }
  }

  function saveFeed(items) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
  }

  function renderFeed() {
    const items = loadFeed();
    if (!items.length) {
      feed.innerHTML = `<div class="empty-feed">Aún no hay publicaciones.<br>Sé el primero en subir algo 🚀</div>`;
      return;
    }
    feed.innerHTML = items
      .map(
        (p) => `
      <article class="post">
        <div class="post-media">
          ${
            p.type === "video"
              ? `<video src="${p.data}" controls playsinline></video>`
              : `<img src="${p.data}" alt="${escapeHtml(p.title)}" />`
          }
        </div>
        <div class="post-body">
          <h4>${escapeHtml(p.title)}</h4>
          ${p.comment ? `<p>${escapeHtml(p.comment)}</p>` : ""}
          <div class="post-meta">${p.date} · público</div>
        </div>
      </article>`
      )
      .join("");
  }

  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  form?.addEventListener("submit", (e) => {
    e.preventDefault();
    const title = $("#up-title").value.trim();
    const comment = $("#up-comment").value.trim();
    if (!title) return;
    if (!currentDataUrl) {
      alert("Agrega una foto o video.");
      return;
    }

    const items = loadFeed();
    items.unshift({
      id: Date.now(),
      title,
      comment,
      data: currentDataUrl,
      type: currentFile.type.startsWith("video/") ? "video" : "image",
      date: new Date().toLocaleString("es", {
        day: "2-digit",
        month: "short",
        hour: "2-digit",
        minute: "2-digit",
      }),
    });
    // Keep only last 30 to avoid huge localStorage
    saveFeed(items.slice(0, 30));

    // reset
    form.reset();
    preview.hidden = true;
    preview.innerHTML = "";
    currentFile = null;
    currentDataUrl = null;
    renderFeed();
    showPanel("upload");
  });

  // Support mock
  $("#btn-send-support")?.addEventListener("click", () => {
    const t = $("#support-msg");
    if (!t.value.trim()) return;
    alert("Mensaje enviado (demo). Crea una cuenta para soporte real.");
    t.value = "";
  });

  $("#btn-account")?.addEventListener("click", () => {
    alert("Función de cuenta en desarrollo. Pronto podrás crear una.");
  });

  // Init
  renderFeed();
})();
