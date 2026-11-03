(() => {
  "use strict";
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => [...el.querySelectorAll(s)];
  let currentUser = null, supabaseClient = null;
  try {
    const cfg = window.VOID_SUPABASE;
    if (window.supabase?.createClient && cfg?.url && cfg?.anonKey)
      supabaseClient = window.supabase.createClient(cfg.url, cfg.anonKey);
  } catch (e) { console.error("Supabase:", e); }
  const NAME_KEY = "void-local-name", SCRIPTS_KEY = "void-local-scripts", ID_KEY = "void-local-id";
  const getLocalId = () => {
    if (currentUser?.id) return currentUser.id;
    let id = localStorage.getItem(ID_KEY);
    if (!id) { id = "local-" + crypto.randomUUID(); localStorage.setItem(ID_KEY, id); }
    return id;
  };
  const getLocalName = () => currentUser?.user_metadata?.display_name || localStorage.getItem(NAME_KEY) || "Usuario VOID";
  const setLocalName = name => {
    const clean = (name || "").trim().slice(0, 32) || "Usuario VOID";
    localStorage.setItem(NAME_KEY, clean);
    return clean;
  };
  const loadLocalScripts = () => { try { return JSON.parse(localStorage.getItem(SCRIPTS_KEY) || "[]"); } catch { return []; } };
  const saveLocalScripts = list => localStorage.setItem(SCRIPTS_KEY, JSON.stringify(list));
  const panels = $$(".panel"), navItems = $$(".nav-item");
  function showPanel(id) {
    panels.forEach(p => p.classList.toggle("active", p.id === "panel-" + id));
    navItems.forEach(n => n.classList.toggle("active", n.dataset.panel === id));
    window.scrollTo({ top: 0, behavior: "smooth" });
    if (id === "scripts" || id === "home") loadScripts();
  }
  navItems.forEach(btn => btn.addEventListener("click", () => showPanel(btn.dataset.panel)));
  document.querySelectorAll("[data-go]").forEach(btn => {
    btn.addEventListener("click", () => {
      const t = btn.dataset.go;
      if (t === "auth") { if (currentUser) $("#btn-account")?.click(); else authModal("login"); return; }
      showPanel(t);
    });
  });
  const themeSelect = $("#theme-select");
  const savedTheme = localStorage.getItem("void-theme") || "void";
  document.documentElement.setAttribute("data-theme", savedTheme === "void" ? "" : savedTheme);
  if (themeSelect) themeSelect.value = savedTheme;
  themeSelect?.addEventListener("change", () => {
    localStorage.setItem("void-theme", themeSelect.value);
    document.documentElement.setAttribute("data-theme", themeSelect.value === "void" ? "" : themeSelect.value);
  });
  function escapeHtml(v) {
    return String(v ?? "").replace(/[&<>"']/g, c => ({ "&": "&", "<": "<", ">": ">", '"': """, "'": "&#39;" }[c]));
  }
  function openModal(title, body) {
    $("#void-modal")?.remove();
    const modal = document.createElement("div");
    modal.id = "void-modal";
    modal.className = "void-modal";
    modal.innerHTML = `<div class=\"void-modal-backdrop\" data-close></div>
      <section class=\"void-modal-card\" role=\"dialog\" aria-modal=\"true\">
        <button class=\"void-modal-close\" type=\"button\" data-close>×</button>
        <h2>${escapeHtml(title)}</h2>
        <div class=\"void-modal-body\">${body}</div>
      </section>`;
    document.body.append(modal);
    modal.querySelectorAll("[data-close]").forEach(b => b.addEventListener("click", () => modal.remove()));
    return modal;
  }
  function notice(message, title = "VOID Hub") {
    const m = openModal(title, `<div class=\"notice-content\"><span class=\"notice-mark\">✓</span><p>${escapeHtml(message)}</p></div>
      <div class=\"modal-actions\"><button type=\"button\" class=\"btn-primary\" data-close>Entendido</button></div>`);
    m.querySelectorAll("[data-close]").forEach(b => b.addEventListener("click", () => m.remove()));
  }
  function askConfirm(message, title = "Confirmar") {
    return new Promise(resolve => {
      const m = openModal(title, `<div class=\"notice-content\"><span class=\"notice-mark warning\">!</span><p>${escapeHtml(message)}</p></div>
        <div class=\"modal-actions\"><button type=\"button\" class=\"btn-sm\" id=\"cf-no\">Cancelar</button>
        <button type=\"button\" class=\"btn-primary\" id=\"cf-yes\">Sí, continuar</button></div>`);
      $("#cf-no", m).onclick = () => { m.remove(); resolve(false); };
      $("#cf-yes", m).onclick = () => { m.remove(); resolve(true); };
      m.querySelectorAll("[data-close]").forEach(b => b.addEventListener("click", () => { m.remove(); resolve(false); }));
    });
  }
  function usernameToEmail(name) {
    const slug = name.normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9._-]/g, "");
    return slug + "@users.p-gina.invalid";
  }
  function updateAccountUI() {
    const button = $("#btn-account");
    if (button) button.textContent = currentUser ? getLocalName() : "Iniciar sesión";
    const status = $("#account-status");
    if (status) status.textContent = currentUser ? "Sesión iniciada como " + getLocalName() : "No has iniciado sesión";
    const homeAuth = $("#home-auth-btn");
    if (homeAuth) homeAuth.textContent = currentUser ? "Mi cuenta" : "Iniciar sesión";
    const statAccount = $("#stat-account");
    if (statAccount) statAccount.textContent = currentUser ? getLocalName().slice(0, 10) : "Invitado";
    const statMode = $("#stat-mode");
    if (statMode) statMode.textContent = supabaseClient ? "Cloud" : "Local";
  }
  function authModal(initialTab = "register") {
    if (!supabaseClient) {
      const modal = openModal("Modo local",
        '<p class="note">Supabase no está configurado. Usa un nombre local en este navegador.</p>' +
        '<form id="local-name-form" class="auth-form"><label>Nombre local<input id="local-name-input" type="text" maxlength="24" value="' +
        escapeHtml(getLocalName()) + '" required></label><button class="btn-primary" type="submit">Guardar nombre</button></form>' +
        '<p class="note">Rellena url y anonKey en supabase-config.js para cuentas reales.</p>');
      $("#local-name-form", modal)?.addEventListener("submit", e => {
        e.preventDefault();
        const name = $("#local-name-input", modal).value.trim();
        if (name.length < 2) return notice("Escribe un nombre válido.");
        setLocalName(name); updateAccountUI(); modal.remove();
        notice("Nombre local guardado: " + name);
      });
      return;
    }
    const markup = '<p class="note">Crea tu cuenta o inicia sesión.</p>' +
      '<div class="auth-tabs"><button type="button" class="btn-sm auth-tab" data-auth-tab="register">Crear cuenta</button>' +
      '<button type="button" class="btn-sm auth-tab" data-auth-tab="login">Iniciar sesión</button></div>' +
      '<form id="register-form" class="auth-form"><label>Nombre<input id="register-name" type="text" minlength="3" maxlength="24" required pattern="[A-Za-z0-9_.-]+"></label>' +
      '<label>Contraseña<input id="register-password" type="password" minlength="8" required></label>' +
      '<button class="btn-primary" type="submit">Crear mi cuenta</button></form>' +
      '<form id="login-form" class="auth-form" hidden><label>Nombre<input id="login-name" type="text" maxlength="24" required></label>' +
      '<label>Contraseña<input id="login-password" type="password" required></label><button class="btn-primary" type="submit">Entrar</button></form>' +
      '<p id="auth-message" class="note" role="status"></p>';
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
      if (!/^[A-Za-z0-9_.-]{3,24}$/.test(name)) { message.textContent = "Usuario: 3–24 caracteres (letras, números, . _ -)."; return; }
      if (password.length < 8) { message.textContent = "Mínimo 8 caracteres de contraseña."; return; }
      const submit = registerForm.querySelector('button[type="submit"]');
      submit.disabled = true; submit.textContent = "Creando…";
      try {
        const result = await supabaseClient.auth.signUp({ email: usernameToEmail(name), password, options: { data: { display_name: name } } });
        if (result.error) throw result.error;
        if (!result.data.session) {
          message.textContent = "Cuenta creada, pero falta desactivar Confirm email en Supabase.";
          return;
        }
        currentUser = result.data.user; localStorage.setItem(NAME_KEY, name);
        updateAccountUI(); modal.remove(); notice("¡Cuenta creada!");
      } catch (error) {
        message.textContent = error.message || "No se pudo crear la cuenta.";
      } finally { submit.disabled = false; submit.textContent = "Crear mi cuenta"; }
    });
    loginForm.addEventListener("submit", async event => {
      event.preventDefault();
      const name = $("#login-name", modal).value.trim(), password = $("#login-password", modal).value;
      if (!name || !password) { message.textContent = "Escribe nombre y contraseña."; return; }
      const submit = loginForm.querySelector('button[type="submit"]');
      submit.disabled = true; submit.textContent = "Entrando…";
      try {
        const result = await supabaseClient.auth.signInWithPassword({ email: usernameToEmail(name), password });
        if (result.error) throw result.error;
        currentUser = result.data.user;
        localStorage.setItem(NAME_KEY, currentUser.user_metadata?.display_name || name);
        updateAccountUI(); modal.remove(); notice("Sesión iniciada.");
      } catch (error) {
        message.textContent = error.message || "No se pudo iniciar sesión.";
      } finally { submit.disabled = false; submit.textContent = "Entrar"; }
    });
    setTab(initialTab);
  }
  async function signOut() {
    if (!supabaseClient || !currentUser) { authModal(); return; }
    const result = await supabaseClient.auth.signOut();
    if (result.error) { notice(result.error.message || "No se pudo cerrar la sesión."); return; }
    currentUser = null; updateAccountUI(); notice("Sesión cerrada.");
  }
  $("#btn-account")?.addEventListener("click", () => {
    if (!currentUser) { authModal(); return; }
    const modal = openModal("Tu cuenta", "<p>Sesión como <strong>" + escapeHtml(getLocalName()) +
      '</strong>.</p><button type="button" class="btn-primary" id="account-signout">Cerrar sesión</button>');
    $("#account-signout", modal).addEventListener("click", async () => { modal.remove(); await signOut(); });
  });
  if (supabaseClient) {
    supabaseClient.auth.onAuthStateChange((_e, session) => {
      currentUser = session?.user || null;
      if (currentUser?.user_metadata?.display_name) localStorage.setItem(NAME_KEY, currentUser.user_metadata.display_name);
      updateAccountUI();
    });
    supabaseClient.auth.getSession().then(({ data }) => {
      currentUser = data.session?.user || null; updateAccountUI(); loadScripts();
    }).catch(e => console.error(e));
  }
  const scriptList = $("#script-list"), scriptForm = $("#script-upload-form");
  function openScriptModal(s) {
    const modal = openModal(s.title, `<p>${escapeHtml(s.description || "")}</p><pre class=\"script-code-view\"><code>${escapeHtml(s.code)}</code></pre>
      <p class=\"note\">Por ${escapeHtml(s.author_name || "Usuario VOID")}</p>`);
    const copy = document.createElement("button");
    copy.className = "btn-primary"; copy.textContent = "Copiar código";
    copy.onclick = async () => {
      try { await navigator.clipboard.writeText(s.code); copy.textContent = "¡Copiado!"; }
      catch {
        const a = document.createElement("textarea"); a.value = s.code; modal.append(a); a.select();
        document.execCommand("copy"); a.remove(); copy.textContent = "¡Copiado!";
      }
    };
    $(".void-modal-body", modal).append(copy);
  }
  function renderScripts(items) {
    const count = $("#stat-scripts");
    if (count) count.textContent = String(items.length);
    if (!scriptList) return;
    if (!items.length) {
      scriptList.innerHTML = '<div class="empty-feed">Todavía no hay scripts. Publica el primero desde Subir.</div>';
      return;
    }
    const myId = getLocalId();
    scriptList.innerHTML = items.map(s => `<article class=\"script-card\">
      <div class=\"script-icon\">⌘</div>
      <div class=\"script-info\"><h3>${escapeHtml(s.title)}</h3>
      <p>${escapeHtml(s.description || "Script de la comunidad")}</p>
      <small>${escapeHtml(s.author_name || "Usuario VOID")}</small></div>
      <button class=\"btn-sm\" type=\"button\" data-open-script=\"${s.id}\">Abrir</button>
      ${s.author_id === myId ? `<button class=\"btn-sm danger-btn\" type=\"button\" data-delete-script=\"${s.id}\">Eliminar</button>` : ""}
    </article>`).join("");
    scriptList.querySelectorAll("[data-open-script]").forEach(b => b.addEventListener("click", () => {
      const s = items.find(x => x.id === b.dataset.openScript); if (s) openScriptModal(s);
    }));
    scriptList.querySelectorAll("[data-delete-script]").forEach(b => b.addEventListener("click", async () => {
      if (!(await askConfirm("¿Eliminar este script?", "Eliminar"))) return;
      const list = loadLocalScripts().filter(s => s.id !== b.dataset.deleteScript);
      saveLocalScripts(list); renderScripts(list); renderHomeScripts(list); notice("Script eliminado.");
    }));
  }
  function renderHomeScripts(items) {
    const homeList = $("#home-script-list");
    if (!homeList) return;
    const recent = items.slice(0, 4);
    if (!recent.length) {
      homeList.innerHTML = '<div class="empty-feed">Todavía no hay scripts. Publica el primero desde <strong>Publicar</strong>.</div>';
      return;
    }
    homeList.innerHTML = recent.map(s => `<article class=\"script-card\">
      <div class=\"script-icon\">⌘</div>
      <div class=\"script-info\"><h3>${escapeHtml(s.title)}</h3>
      <p>${escapeHtml(s.description || "Script de la comunidad")}</p>
      <small>${escapeHtml(s.author_name || "Usuario VOID")}</small></div>
      <button class=\"btn-sm\" type=\"button\" data-open-script=\"${s.id}\">Abrir</button>
    </article>`).join("");
    homeList.querySelectorAll("[data-open-script]").forEach(b => b.addEventListener("click", () => {
      const s = items.find(x => x.id === b.dataset.openScript); if (s) openScriptModal(s);
    }));
  }
  function loadScripts() {
    const items = loadLocalScripts();
    if (scriptList) renderScripts(items);
    else { const c = $("#stat-scripts"); if (c) c.textContent = String(items.length); }
    renderHomeScripts(items);
  }
  scriptForm?.addEventListener("submit", e => {
    e.preventDefault();
    if (supabaseClient && !currentUser) return authModal("register");
    const title = $("#script-title").value.trim();
    const description = $("#script-description").value.trim();
    const code = $("#script-code").value.trim();
    if (!title || !code) return notice("Escribe el nombre y el código del script.");
    const button = $("#btn-script-upload");
    button.disabled = true; button.textContent = "Publicando…";
    try {
      const list = loadLocalScripts();
      list.unshift({ id: crypto.randomUUID(), author_id: getLocalId(), author_name: getLocalName(), title, description, code, created_at: new Date().toISOString() });
      saveLocalScripts(list); scriptForm.reset(); loadScripts();
      notice("Script guardado en este dispositivo.");
    } catch (err) { notice(err.message || "No se pudo guardar."); }
    finally { button.disabled = false; button.textContent = "Publicar"; }
  });
  $("#btn-send-support")?.addEventListener("click", async () => {
    const message = $("#support-msg")?.value.trim();
    if (!message) return notice("Escribe un mensaje primero.");
    try { await navigator.clipboard.writeText(message); notice("Mensaje copiado. Aún no hay canal de soporte."); }
    catch {
      const a = document.createElement("textarea"); a.value = message; document.body.append(a); a.select();
      const ok = document.execCommand("copy"); a.remove();
      notice(ok ? "Mensaje copiado. Aún no hay canal de soporte." : "No se pudo copiar.");
    }
  });
  $("#lang-select")?.addEventListener("change", e => {
    if (e.target.value === "en") notice("La traducción al inglés todavía no está disponible.");
  });
  updateAccountUI();
  loadScripts();
})();
