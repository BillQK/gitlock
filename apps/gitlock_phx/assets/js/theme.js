(() => {
  const initTheme = () => {
    if (!localStorage.getItem("theme")) {
      const prefersDark = window.matchMedia(
        "(prefers-color-scheme: dark)",
      ).matches;
      const initialTheme = prefersDark ? "dark" : "light";

      document.documentElement.setAttribute("data-theme", initialTheme);
      localStorage.setItem("theme", initialTheme);
    } else {
      const userTheme = localStorage.getItem("theme");
      document.documentElement.setAttribute("data-theme", userTheme);
    }
  };

  const setTheme = (theme) => {
    localStorage.setItem("theme", theme);
    document.documentElement.setAttribute("data-theme", theme);
  };

  initTheme();

  window.addEventListener("phx:set-theme", ({ detail: { theme } }) =>
    setTheme(theme),
  );

  window.addEventListener("storage", (e) => {
    if (e.key === "theme" && e.newValue) {
      document.documentElement.setAttribute("data-theme", e.newValue);
    }
  });

  window
    .matchMedia("(prefers-color-scheme: dark)")
    .addEventListener("change", (e) => {
      const isDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
      document.documentElement.setAttribute(
        "data-theme",
        isDark ? "dark" : "light",
      );
      localStorage.setItem("theme", isDark ? "dark" : "light");
    });
})();
