document.addEventListener("DOMContentLoaded", () => {
  const widgets = Array.from(document.querySelectorAll("[data-admin-search]"));

  widgets.forEach((input, widgetIndex) => {
    const results = document.getElementById(input.getAttribute("aria-controls"));
    const status = input.parentElement.querySelector("[data-search-status]");
    // Widgets are wired in a loop; a field missing its status span would otherwise
    // throw and take autocomplete down on every other field too.
    const setStatus = (text) => { if (status) status.textContent = text; };
    let timer;
    let request;
    let activeIndex = -1;

    if (!results) return;

    const close = () => {
      results.hidden = true;
      input.setAttribute("aria-expanded", "false");
      input.removeAttribute("aria-activedescendant");
      activeIndex = -1;
    };

    const setActive = (index) => {
      const options = Array.from(results.querySelectorAll("[role='option']"));
      if (!options.length) return;

      activeIndex = (index + options.length) % options.length;
      options.forEach((option, optionIndex) => {
        const selected = optionIndex === activeIndex;
        option.setAttribute("aria-selected", String(selected));
        if (selected) {
          input.setAttribute("aria-activedescendant", option.id);
          option.scrollIntoView({ block: "nearest" });
        }
      });
    };

    const showMessage = (message) => {
      results.replaceChildren();
      const item = document.createElement("li");
      item.className = "admin-search-status";
      item.textContent = message;
      item.setAttribute("role", "option");
      item.setAttribute("aria-disabled", "true");
      results.append(item);
      results.hidden = false;
      input.setAttribute("aria-expanded", "true");
    };

    const render = (items) => {
      results.replaceChildren();
      activeIndex = -1;

      if (!items.length) {
        showMessage("لا توجد نتائج مطابقة");
        return;
      }

      items.forEach((item, itemIndex) => {
        const option = document.createElement("li");
        option.id = `admin-search-${widgetIndex}-${itemIndex}`;
        option.setAttribute("role", "option");
        option.setAttribute("aria-selected", "false");

        const link = document.createElement("a");
        link.className = "admin-search-result";
        link.href = item.url;

        const kind = document.createElement("span");
        kind.className = "admin-search-kind";
        kind.textContent = item.type;

        const copy = document.createElement("span");
        copy.className = "admin-search-copy";
        const title = document.createElement("span");
        title.className = "admin-search-title";
        title.textContent = item.title;
        const subtitle = document.createElement("span");
        subtitle.className = "admin-search-subtitle";
        subtitle.textContent = item.subtitle || "";

        copy.append(title, subtitle);
        link.append(kind, copy);
        option.append(link);
        results.append(option);
      });

      results.hidden = false;
      input.setAttribute("aria-expanded", "true");
      setStatus(`${items.length} نتائج`);
    };

    input.addEventListener("input", () => {
      window.clearTimeout(timer);
      request?.abort();
      const query = input.value.trim();
      results.replaceChildren();
      close();
      setStatus("");

      if (query.length < 3) {
        if (query.length > 0) setStatus("أدخل ٣ أحرف على الأقل");
        return;
      }

      timer = window.setTimeout(async () => {
        request = new AbortController();
        const params = new URLSearchParams({ q: query, scope: input.dataset.searchScope || "all" });
        setStatus("جارٍ البحث…");

        try {
          const response = await fetch(`${input.dataset.searchUrl}?${params}`, {
            headers: { Accept: "application/json" },
            credentials: "same-origin",
            signal: request.signal
          });
          if (!response.ok) throw new Error("search failed");
          render(await response.json());
        } catch (error) {
          if (error.name !== "AbortError") {
            results.replaceChildren();
            close();
            setStatus("تعذر البحث الآن");
          }
        }
      }, 220);
    });

    input.addEventListener("keydown", (event) => {
      const options = results.querySelectorAll("[role='option']:not([aria-disabled='true'])");
      if (event.key === "ArrowDown" && !results.hidden) {
        event.preventDefault();
        setActive(activeIndex + 1);
      } else if (event.key === "ArrowUp" && !results.hidden) {
        event.preventDefault();
        setActive(activeIndex < 0 ? options.length - 1 : activeIndex - 1);
      } else if (event.key === "Enter" && activeIndex >= 0 && options[activeIndex]) {
        event.preventDefault();
        options[activeIndex].querySelector("a").click();
      } else if (event.key === "Escape") {
        close();
      }
    });

    input.addEventListener("focus", () => {
      if (results.childElementCount) {
        results.hidden = false;
        input.setAttribute("aria-expanded", "true");
      }
    });
  });

  document.addEventListener("click", (event) => {
    widgets.forEach((input) => {
      if (!input.parentElement.contains(event.target)) {
        input.setAttribute("aria-expanded", "false");
        input.removeAttribute("aria-activedescendant");
        const results = document.getElementById(input.getAttribute("aria-controls"));
        if (results) results.hidden = true;
      }
    });
  });
});
