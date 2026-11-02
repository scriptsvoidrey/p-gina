(() => {
  "use strict";
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => [...el.querySelectorAll(s)];

  // Autenticación real mediante Supabase; las contraseñas nunca se guardan en el navegador.
  let currentUser = null;
  let supabaseClient = null;
  try {
    const cfg = window.VOID_SUPABASE;
    if (window.supabase?.createClient && cfg?.url && cfg?.anonKey) supabaseClient = window.supabase.createClient(cfg.url, cfg.anonKey);
  } catch (error) { console.error("Supabase:", error); }
  const LOCAL_NAME_KEY = "void-local-name";
  const LOCAL_SCRIPTS_KEY = "void-local-scripts";
  const LOCAL_POSTS_KEY = "void-local-posts";
  const LOCAL_ID_KEY = "void-local-id";

  function getLocalId() {
    if (currentUser?.id) return currentUser.id;
    let id = localStorage.getItem(LOCAL_ID_KEY);
    if (!id) {
      id = "local-" + crypto.randomUUID();
      localStorage.setItem(LOCAL_ID_KEY, id);
    }
    return id;
  }

  function getLocalName() {
    return currentUser?.user_metadata?.display_name || localStorage.getItem(LOCAL_NAME_KEY) || "Usuario VOID";
  }

  function setLocalName(name) {
    const clean = (name || "").trim().slice(0, 32) || "Usuario VOID";
    localStorage.setItem(LOCAL_NAME_KEY, clean);
    return clean;
  }

  function loadLocalScripts() {
    try {
      return JSON.parse(localStorage.getItem(LOCAL_SCRIPTS_KEY) || "[]");
    } catch {
      return [];
    }
  }

  function saveLocalScripts(list) {
    localStorage.setItem(LOCAL_SCRIPTS_KEY, JSON.stringify(list));
  }

  function loadLocalPosts() {
    try {
      return JSON.parse(localStorage.getItem(LOCAL_POSTS_KEY) || "[]");
    } catch {
      return [];
    }
  }

  function saveLocalPosts(list) {
    localStorage.setItem(LOCAL_POSTS_KEY, JSON.stringify(list));
  }

  let currentFile = null;
  let previewUrl = null;

  // Navegación
  const panels = $$(".panel");
  const navItems = $$(".nav-item");
  function showPanel(id) {
    panels.forEach(p => p.classList.toggle("active", p.id === `panel-${id}`));
    navItems.forEach(n => n.classList.toggle("active", n.dataset.panel === id));
    window.scrollTo({ top: 0, behavior: "smooth" });
    if (id === "upload") loadFeed();
    if (id === "scripts") loadScripts();
  }
  navItems.forEach(btn => btn.addEventListener("click", () => showPanel(btn.dataset.panel)));

  // Temas
  const themeSelect = $("#theme-select");
  const savedTheme = localStorage.getItem("void-theme") || "void";
  document.documentElement.setAttribute("data-theme", savedTheme === "void" ? "" : savedTheme);
  if (themeSelect) themeSelect.value = savedTheme;
  themeSelect?.addEventListener("change", () => {
    localStorage.setItem("void-theme", themeSelect.value);
    document.documentElement.setAttribute("data-theme", themeSelect.value === "void" ? "" : themeSelect.value);
  });

  function notice(message, title = "VOID Hub") { showDialog(title, message, false); }
  function askConfirm(message, title = "Confirmar acción") { return showDialog(title, message, true); }
  function showDialog(title, message, confirmMode) {
    return new Promise(resolve => {
      $("#void-modal")?.remove();
      const modal = document.createElement("div"); modal.id = "void-modal"; modal.className = "void-modal";
      const backdrop = document.createElement("div"); backdrop.className = "void-modal-backdrop";
      const card = document.createElement("section"); card.className = "void-modal-card"; card.setAttribute("role", "dialog"); card.setAttribute("aria-modal", "true");
      const close = document.createElement("button"); close.className = "void-modal-close"; close.type = "button"; close.textContent = "×"; close.setAttribute("aria-label", "Cerrar");
      const heading = document.createElement("h2"); heading.textContent = title;
      const body = document.createElement("div"); body.className = "void-modal-body";
      const content = document.createElement("div"); content.className = "notice-content";
      const mark = document.createElement("span"); mark.className = "notice-mark" + (confirmMode ? " warning" : ""); mark.textContent = confirmMode ? "!" : "✓";
      const p = document.createElement("p"); p.textContent = message; content.append(mark, p); body.append(content);
      const actions = document.createElement("div"); actions.className = "modal-actions";
      const finish = value => { modal.remove(); resolve(value); };
      close.addEventListener("click", () => finish(false));
      backdrop.addEventListener("click", () => finish(false));
      if (confirmMode) {
        const cancel = document.createElement("button"); cancel.className = "btn-sm"; cancel.textContent = "Cancelar";
        cancel.addEventListener("click", () => finish(false)); actions.append(cancel);
      }
      const ok = document.createElement("button"); ok.className = "btn-primary"; ok.textContent = confirmMode ? "Sí, continuar" : "Entendido";
      ok.addEventListener("click", () => finish(confirmMode)); actions.append(ok);
      card.append(close, heading, body, actions); modal.append(backdrop, card); document.body.append(modal);
    });
  }

  function escapeHtml(value) {
    return String(value ?? "").replace(/[&<>"']/g, c => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[c]));
  }

  function formatDate(value) {
    return new Intl.DateTimeFormat("es", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
  }

  // Ventana modal reutilizable
  function openModal(title, body, footer = "") {
    $("#void-modal")?.remove();
    const modal = document.createElement("div");
    modal.id = "void-modal";
    modal.className = "void-modal";
    modal.innerHTML = `<div class="void-modal-backdrop" data-close></div>
      <section class="void-modal-card" role="dialog" aria-modal="true" aria-labelledby="void-modal-title">
        <button class="void-modal-close" type="button" aria-label="Cerrar" data-close>×</button>
        <h2 id="void-modal-title">${escapeHtml(title)}</h2>
        <div class="void-modal-body">${body}</div>${footer}
      </section>`;
    document.body.append(modal);
    modal.querySelectorAll("[data-close]").forEach(b => b.addEventListener("click", () => modal.remove()));
    return modal;
  }

  // ——— Registro, inicio y cierre de sesión ———
  function usernameToEmail(name) {
    const slug = name.normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9._-]/g, "");
    return slug + "@users.p-gina.invalid";
  }
  function updateAccountUI() {
    const button = $("#btn-account");
    if (button) button.textContent = currentUser ? getLocalName() : "Crear cuenta / Entrar";
    const status = $("#account-status");
    if (status) status.textContent = currentUser ? "Sesión iniciada como " + getLocalName() : "No has iniciado sesión";
  }
  function authModal(initialTab = "register") {
    if (!supabaseClient) return notice("No se pudo conectar con el servicio de cuentas. Revisa la configuración de Supabase.");
    const markup = '<p class="note">Regístrate con tu nombre de usuario y una contraseña. No necesitas correo electrónico.</p>' +
      '<div class="auth-tabs"><button type="button" class="btn-sm" data-auth-tab="register">Crear cuenta</button><button type="button" class="btn-sm" data-auth-tab="login">Iniciar sesión</button></div>' +
      '<form id="register-form" class="auth-form"><label>Nombre de usuario<input id="register-name" type="text" minlength="3" maxlength="24" autocomplete="username" placeholder="Tu nombre" required pattern="[A-Za-z0-9_.-]+"></label>' +
      '<label>Contraseña<input id="register-password" type="password" minlength="8" autocomplete="new-password" placeholder="Mínimo 8 caracteres" required></label>' +
      '<button class="btn-primary" type="submit">Crear mi cuenta</button></form>' +
      '<form id="login-form" class="auth-form" hidden><label>Nombre de usuario<input id="login-name" type="text" maxlength="24" autocomplete="username" placeholder="Tu nombre de usuario" required></label>' +
      '<label>Contraseña<input id="login-password" type="password" autocomplete="current-password" placeholder="Tu contraseña" required></label><button class="btn-primary" type="submit">Entrar</button></form>' +
      '<p id="auth-message" class="note" role="status" aria-live="polite"></p>';
    const modal = openModal("Tu cuenta P-GINA", markup);
    const registerForm = $("#register-form", modal), loginForm = $("#login-form", modal), message = $("#auth-message", modal);
    const setTab = tab => {
      registerForm.hidden = tab !== "register"; loginForm.hidden = tab !== "login";
      modal.querySelectorAll("[data-auth-tab]").forEach(b => b.classList.toggle("active", b.dataset.authTab === tab));
      message.textContent = "";
    };
    modal.querySelectorAll("[data-auth-tab]").forEach(b => b.addEventListener("click", () => setTab(b.dataset.authTab)));
    registerForm.addEventListener("submit", async event => {
      event.preventDefault();
      const name = $("#register-name", modal).value.trim(), password = $("#register-password", modal).value;
      if (!/^[A-Za-z0-9_.-]{3,24}$/.test(name)) { message.textContent = "El nombre debe tener 3–24 caracteres: letras, números, punto, guion o guion bajo."; return; }
      if (password.length < 8) { message.textContent = "La contraseña debe tener al menos 8 caracteres."; return; }
      const submit = registerForm.querySelector('button[type="submit"]');
      submit.disabled = true; submit.textContent = "Creando cuenta…";
      try {
        const result = await supabaseClient.auth.signUp({ email: usernameToEmail(name), password, options: { data: { display_name: name } } });
        if (result.error) throw result.error;
        if (!result.data.session) { message.textContent = "Supabase exige confirmar un correo. Para registro solo con nombre, desactiva la confirmación de email en Authentication → Providers → Email."; return; }
        currentUser = result.data.user; localStorage.setItem(LOCAL_NAME_KEY, name); updateAccountUI(); modal.remove(); notice("¡Cuenta creada! Ya puedes usar P-GINA.");
      } catch (error) { message.textContent = error.message || "No se pudo crear la cuenta."; }
      finally { submit.disabled = false; submit.textContent = "Crear mi cuenta"; }
    });
    loginForm.addEventListener("submit", async event => {
      event.preventDefault();
      const name = $("#login-name", modal).value.trim(), password = $("#login-password", modal).value;
      if (!name || !password) { message.textContent = "Escribe tu nombre y contraseña."; return; }
      const submit = loginForm.querySelector('button[type="submit"]');
      submit.disabled = true; submit.textContent = "Entrando…";
      try {
        const result = await supabaseClient.auth.signInWithPassword({ email: usernameToEmail(name), password });
        if (result.error) throw result.error;
        currentUser = result.data.user; localStorage.setItem(LOCAL_NAME_KEY, currentUser.user_metadata?.display_name || name);
        updateAccountUI(); modal.remove(); notice("Sesión iniciada. ¡Bienvenido a P-GINA!");
      } catch (error) { message.textContent = "No se pudo iniciar sesión. Comprueba tu nombre y contraseña."; }
      finally { submit.disabled = false; submit.textContent = "Entrar"; }
    });
    setTab(initialTab);
  }
  async function signOut() {
    if (!supabaseClient || !currentUser) { authModal("login"); return; }
    const result = await supabaseClient.auth.signOut();
    if (result.error) { notice(result.error.message || "No se pudo cerrar la sesión."); return; }
    currentUser = null; updateAccountUI(); notice("Sesión cerrada correctamente.");
  }
  $("#btn-account")?.addEventListener("click", () => {
    if (!currentUser) { authModal("register"); return; }
    const markup = '<p>Sesión iniciada como <strong>' + escapeHtml(getLocalName()) + '</strong>.</p><button type="button" class="btn-primary" id="account-signout">Cerrar sesión</button>';
    const modal = openModal("Tu cuenta", markup);
    $("#account-signout", modal).addEventListener("click", async () => { modal.remove(); await signOut(); });
  });
  if (supabaseClient) {
    supabaseClient.auth.onAuthStateChange((_event, session) => {
      currentUser = session?.user || null;
      if (currentUser?.user_metadata?.display_name) localStorage.setItem(LOCAL_NAME_KEY, currentUser.user_metadata.display_name);
      updateAccountUI();
    });
    supabaseClient.auth.getSession().then(({ data }) => {
      currentUser = data.session?.user || null; updateAccountUI(); loadFeed(); loadScripts();
    }).catch(error => console.error("Error recuperando sesión:", error));
  }

  // ——— Scripts (localStorage) ———

  const scriptList = $("#script-list");
  const scriptForm = $("#script-upload-form");

  function renderScripts(items) {
    const count = $("#stat-scripts");
    if (count) count.textContent = String(items.length);
    if (!items.length) {
      scriptList.innerHTML = '<div class="empty-feed">Todavía no hay scripts. Publica el primero desde Subir.</div>';
      return;
    }
    const myId = getLocalId();
    scriptList.innerHTML = items.map(s => `<article class="script-card">
      <div class="script-icon">⌘</div>
      <div class="script-info">
        <h3>${escapeHtml(s.title)}</h3>
        <p>${escapeHtml(s.description || "Script de la comunidad")}</p>
        <small>${escapeHtml(s.author_name || "Usuario VOID")}</small>
      </div>
      <button class="btn-sm" type="button" data-open-script="${s.id}">Abrir</button>
      ${s.author_id === myId ? `<button class="btn-sm danger-btn" type="button" data-delete-script="${s.id}">Eliminar</button>` : ""}
    </article>`).join("");

    scriptList.querySelectorAll("[data-open-script]").forEach(b => b.addEventListener("click", () => {
      const s = items.find(x => x.id === b.dataset.openScript);
      if (!s) return;
      const modal = openModal(s.title, `<p>${escapeHtml(s.description || "")}</p><pre class="script-code-view"><code>${escapeHtml(s.code)}</code></pre><p class="note">Publicado por ${escapeHtml(s.author_name || "Usuario VOID")}</p>`);
      const copy = document.createElement("button");
      copy.className = "btn-primary";
      copy.textContent = "Copiar código";
      copy.addEventListener("click", async () => {
        try {
          await navigator.clipboard.writeText(s.code);
          copy.textContent = "¡Código copiado!";
        } catch {
          const area = document.createElement("textarea");
          area.value = s.code;
          modal.append(area);
          area.select();
          document.execCommand("copy");
          area.remove();
          copy.textContent = "¡Código copiado!";
        }
      });
      $(".void-modal-body", modal).append(copy);
    }));

    scriptList.querySelectorAll("[data-delete-script]").forEach(b => b.addEventListener("click", async () => {
      if (!await askConfirm("¿Eliminar este script? Esta acción no se puede deshacer.", "Eliminar script")) return;
      const list = loadLocalScripts().filter(s => s.id !== b.dataset.deleteScript);
      saveLocalScripts(list);
      renderScripts(list);
      notice("Script eliminado.");
    }));
  }

  function loadScripts() {
    if (!scriptList) return;
    const items = loadLocalScripts();
    renderScripts(items);
  }

  scriptForm?.addEventListener("submit", e => {
    e.preventDefault();
    if (!currentUser) return authModal("register");
    const title = $("#script-title").value.trim();
    const description = $("#script-description").value.trim();
    const code = $("#script-code").value.trim();
    if (!title || !code) return notice("Escribe el nombre y el código del script.");
    const button = $("#btn-script-upload");
    button.disabled = true;
    button.textContent = "Publicando…";
    try {
      const list = loadLocalScripts();
      list.unshift({
        id: crypto.randomUUID(),
        author_id: getLocalId(),
        author_name: getLocalName(),
        title,
        description,
        code,
        created_at: new Date().toISOString()
      });
      saveLocalScripts(list);
      scriptForm.reset();
      loadScripts();
      notice("Script guardado en este dispositivo.");
    } catch (err) {
      notice(err.message || "No se pudo guardar el script.");
    } finally {
      button.disabled = false;
      button.textContent = "Publicar";
    }
  });

  // ——— Feed y publicaciones (localStorage + data URLs) ———
  const form = $("#upload-form");
  const fileInput = $("#up-file");
  const fileZone = $("#file-zone");
  const preview = $("#preview");
  const feed = $("#feed");

  function resetPreview() {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    previewUrl = null;
    currentFile = null;
    if (preview) {
      preview.hidden = true;
      preview.replaceChildren();
    }
  }

  function handleFile(file) {
    if (!file) return;
    if (selectedMediaKind === "image" && !file.type.startsWith("image/")) return notice("Selecciona una foto en la opción Fotos.");
    if (selectedMediaKind === "video" && !file.type.startsWith("video/")) return notice("Selecciona un video en la opción Videos.");
    if (file.size > 4 * 1024 * 1024) return notice("El archivo supera el límite de 4 MB para el almacenamiento local.");
    resetPreview();
    currentFile = file;
    previewUrl = URL.createObjectURL(file);
    const media = document.createElement(file.type.startsWith("video/") ? "video" : "img");
    media.src = previewUrl;
    if (media.tagName === "VIDEO") {
      media.controls = true;
      media.playsInline = true;
    } else {
      media.alt = "Vista previa";
    }
    preview.replaceChildren(media);
    preview.hidden = false;
  }

  let selectedMediaKind = "image";
  const mediaKindButtons = $$(".media-kind-btn");
  const zoneTitle = $("#file-zone-title");
  const zoneHelp = $("#file-zone-help");
  mediaKindButtons.forEach(button => button.addEventListener("click", () => {
    selectedMediaKind = button.dataset.mediaKind;
    mediaKindButtons.forEach(item => {
      const active = item === button;
      item.classList.toggle("active", active);
      item.setAttribute("aria-pressed", String(active));
    });
    resetPreview();
    if (fileInput) {
      fileInput.value = "";
      fileInput.accept = selectedMediaKind === "video" ? "video/*" : "image/*";
    }
    if (zoneTitle) zoneTitle.textContent = selectedMediaKind === "video" ? "Selecciona o arrastra tus videos" : "Selecciona o arrastra tus fotos";
    if (zoneHelp) zoneHelp.textContent = selectedMediaKind === "video" ? "MP4, WEBM y otros formatos de video" : "JPG, PNG y otros formatos de imagen";
  }));

  fileInput?.addEventListener("change", () => handleFile(fileInput.files?.[0]));
  ["dragenter", "dragover"].forEach(ev => fileZone?.addEventListener(ev, e => {
    e.preventDefault();
    fileZone.classList.add("drag");
  }));
  ["dragleave", "drop"].forEach(ev => fileZone?.addEventListener(ev, e => {
    e.preventDefault();
    fileZone.classList.remove("drag");
  }));
  fileZone?.addEventListener("drop", e => handleFile(e.dataTransfer.files?.[0]));

  function fileToDataURL(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(new Error("No se pudo leer el archivo"));
      reader.readAsDataURL(file);
    });
  }

  function renderPosts(posts) {
    const postCount = $("#stat-members");
    if (postCount) postCount.textContent = String(posts.length);
    if (!posts.length) {
      feed.innerHTML = '<div class="empty-feed">Todavía no hay publicaciones.<br>¡Comparte la primera!</div>';
      return;
    }
    const myId = getLocalId();
    feed.innerHTML = posts.map(p => {
      const media = p.media_type === "video"
        ? `<video src="${escapeHtml(p.media_url)}" controls playsinline preload="metadata"></video>`
        : `<img src="${escapeHtml(p.media_url)}" alt="${escapeHtml(p.title)}" loading="lazy">`;
      const own = p.author_id === myId;
      return `<article class="post">
        <div class="post-media">${media}</div>
        <div class="post-body">
          <h4>${escapeHtml(p.title)}</h4>
          ${p.comment ? `<p>${escapeHtml(p.comment)}</p>` : ""}
          <div class="post-meta">${escapeHtml(p.author_name || "Usuario VOID")} · ${escapeHtml(formatDate(p.created_at))}</div>
          ${own ? `<button class="btn-sm danger-btn" type="button" data-delete-post="${p.id}">Eliminar publicación</button>` : ""}
        </div>
      </article>`;
    }).join("");

    feed.querySelectorAll("[data-delete-post]").forEach(b => b.addEventListener("click", async () => {
      if (!await askConfirm("¿Eliminar tu publicación?", "Eliminar publicación")) return;
      const list = loadLocalPosts().filter(p => p.id !== b.dataset.deletePost);
      saveLocalPosts(list);
      renderPosts(list);
      notice("Publicación eliminada.");
    }));
  }

  function loadFeed() {
    if (!feed) return;
    const posts = loadLocalPosts();
    renderPosts(posts);
  }

  form?.addEventListener("submit", async e => {
    e.preventDefault();
    if (!currentUser) return authModal("register");
    if (!currentFile) return notice("Selecciona una foto o un video primero.");
    const title = $("#up-title").value.trim();
    const comment = $("#up-comment").value.trim();
    if (!title) return notice("Escribe un título para la publicación.");
    const submit = $("#btn-upload");
    submit.disabled = true;
    submit.textContent = "Publicando…";
    try {
      const dataUrl = await fileToDataURL(currentFile);
      const list = loadLocalPosts();
      list.unshift({
        id: crypto.randomUUID(),
        author_id: getLocalId(),
        author_name: getLocalName(),
        title,
        comment,
        media_url: dataUrl,
        media_type: currentFile.type.startsWith("video/") ? "video" : "image",
        created_at: new Date().toISOString()
      });
      saveLocalPosts(list);
      form.reset();
      resetPreview();
      loadFeed();
      notice("¡Publicación guardada en este dispositivo!");
    } catch (err) {
      notice(err.message || "No se pudo guardar. Inténtalo de nuevo.");
    } finally {
      submit.disabled = false;
      submit.textContent = "Publicar";
    }
  });

  // Soporte
  $("#btn-send-support")?.addEventListener("click", async () => {
    const message = $("#support-msg")?.value.trim();
    if (!message) return notice("Escribe un mensaje primero.");
    try {
      await navigator.clipboard.writeText(message);
      notice("Mensaje copiado. Todavía no hay un canal de soporte conectado.");
    } catch {
      const area = document.createElement("textarea");
      area.value = message; document.body.append(area); area.select();
      const copied = document.execCommand("copy"); area.remove();
      notice(copied ? "Mensaje copiado. Todavía no hay un canal de soporte conectado." : "No se pudo copiar el mensaje.");
    }
  });

  // Idioma
  $("#lang-select")?.addEventListener("change", e => {
    if (e.target.value === "en") notice("La traducción al inglés todavía no está disponible.");
  });

  // Inicio
  function init() {
    updateAccountUI();
    loadFeed();
    loadScripts();
  }
  init();
})();
