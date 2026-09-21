// Theme: dark by default, light on request
(function () {
  var root = document.documentElement;
  var toggle = document.querySelector(".theme-toggle");
  var stored = null;
  try {
    stored = localStorage.getItem("theme");
  } catch (e) {}
  if (stored) root.dataset.theme = stored;

  toggle.addEventListener("click", function () {
    var next = root.dataset.theme === "light" ? "dark" : "light";
    root.dataset.theme = next;
    try {
      localStorage.setItem("theme", next);
    } catch (e) {}
  });
})();

// Install tabs
document.querySelectorAll(".tab").forEach(function (button) {
  button.addEventListener("click", function () {
    document.querySelectorAll(".tab").forEach(function (t) {
      t.classList.remove("active");
      t.setAttribute("aria-selected", "false");
    });
    document.querySelectorAll(".panel").forEach(function (p) {
      p.classList.remove("active");
      p.hidden = true;
    });
    button.classList.add("active");
    button.setAttribute("aria-selected", "true");
    var panel = document.getElementById(button.dataset.target);
    panel.classList.add("active");
    panel.hidden = false;
  });
});

// Lightbox
(function () {
  var box = document.getElementById("lightbox");
  var img = document.getElementById("lightbox-img");
  document.querySelectorAll(".showcase img").forEach(function (src) {
    src.addEventListener("click", function () {
      img.src = src.src;
      img.alt = src.alt;
      box.hidden = false;
    });
  });
  box.addEventListener("click", function () {
    box.hidden = true;
    img.src = "";
  });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && !box.hidden) box.click();
  });
})();

// Live sidebar demo
(function () {
  var treeEl = document.getElementById("demo-tree");
  var paneEl = document.getElementById("demo-pane");
  var WIDTH = 22;

  var rows = [
    { cls: "sess", pre: "", name: "work" },
    { cls: "win", pre: "├─ ", name: "code" },
    { cls: "", pre: "│  ├─ ", name: "claude", id: "claude" },
    { cls: "", pre: "│  └─ ", name: "zsh" },
    { cls: "win", pre: "└─ ", name: "infra" },
    { cls: "", pre: "   ├─ ", name: "lazygit" },
    { cls: "", pre: "   └─ ", name: "yazi" },
    { cls: "sess", pre: "", name: "notes" },
    { cls: "win", pre: "└─ ", name: "md" },
    { cls: "", pre: "   └─ ", name: "vim" },
  ];

  function esc(s) {
    return s.replace(/</g, "&lt;");
  }

  function renderTree(sel, badge) {
    return rows
      .map(function (r, i) {
        var label = r.pre + r.name;
        var pad = " ".repeat(Math.max(1, WIDTH - label.length - (r.id && badge ? 2 : 0)));
        var line =
          '<span class="line">' + esc(r.pre) + "</span>" +
          '<span class="' + r.cls + '">' + r.name + "</span>" +
          pad + (r.id && badge ? '<span class="badge">' + badge + "</span>" : "");
        var cursor = i === sel ? '<span class="cur">▶ </span>' : "  ";
        return i === sel
          ? '<span class="sel">' + cursor + line + "</span>"
          : cursor + line;
      })
      .join("\n");
  }

  var pane = {
    start: '<span class="prompt">$</span> claude\n\n<span class="prompt">></span> tighten the retry loop in lib.sh',
    read: '\n\n<span class="dim">⏺ Read scripts/core/lib.sh</span>',
    edit: '\n<span class="dim">⏺ Edit scripts/core/lib.sh</span>',
    ask: '\n\n<span class="ask">Allow edit to scripts/core/lib.sh?</span>\n<span class="dim">  y / n</span>',
    yes: '\n<span class="prompt">></span> y',
    test: '\n\n<span class="dim">⏺ Bash tests/run.sh tests/core/lib_test.sh</span>\n<span class="dim">  12 passed</span>',
    done: '\n\n<span class="ok">✔</span> Retry backs off 50 → 400 ms. One file changed.',
  };

  var steps = [
    { at: 0, sel: 2, badge: "", pane: pane.start },
    { at: 1400, badge: "⏳", pane: pane.start + pane.read },
    { at: 2600, pane: pane.start + pane.read + pane.edit },
    { at: 3800, badge: "❓", pane: pane.start + pane.read + pane.edit + pane.ask },
    { at: 6200, badge: "⏳", pane: pane.start + pane.read + pane.edit + pane.ask + pane.yes },
    { at: 7400, pane: pane.start + pane.read + pane.edit + pane.ask + pane.yes + pane.test },
    { at: 8800, badge: "✅", pane: pane.start + pane.read + pane.edit + pane.ask + pane.yes + pane.test + pane.done },
    { at: 10400, sel: 3 },
    { at: 10900, sel: 5 },
    { at: 11400, sel: 6 },
    { at: 12200, sel: 2 },
  ];
  var LOOP = 13600;

  var state = { sel: 2, badge: "", pane: pane.start };

  function apply(step) {
    if (step.sel !== undefined) state.sel = step.sel;
    if (step.badge !== undefined) state.badge = step.badge;
    if (step.pane !== undefined) state.pane = step.pane;
    treeEl.innerHTML = renderTree(state.sel, state.badge);
    paneEl.innerHTML = state.pane + ' <span class="caret"></span>';
  }

  var still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (still) {
    apply({ sel: 2, badge: "⏳", pane: pane.start + pane.read + pane.edit });
    return;
  }

  function run() {
    steps.forEach(function (s) {
      setTimeout(function () {
        apply(s);
      }, s.at);
    });
    setTimeout(run, LOOP);
  }
  run();
})();
