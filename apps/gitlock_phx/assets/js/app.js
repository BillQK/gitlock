// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

let Hooks = {};

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs()

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true,
      );

      window.liveReloader = reloader;
    },
  );
}

Hooks.AnimateNumber = {
  mounted() {
    // Parse number data and extract components
    this.parseNumberData();

    // Initialize animation configuration
    this.config = {
      duration: parseInt(this.el.dataset.duration || 2000),
      delay: parseInt(this.el.dataset.delay || 0),
      easing: this.el.dataset.easing || "easeOutQuad",
      once: this.el.dataset.once !== "false",
    };

    // Set up intersection observer to animate on scroll
    this.setupIntersectionObserver();
  },

  // Parse the number data to handle special formats
  parseNumberData() {
    const targetValue = this.el.dataset.number;

    // Handle special case for time format like "3 min"
    if (targetValue.includes("min")) {
      this.isTimeFormat = true;
      this.timeUnit = "min";
      this.targetNumber = parseFloat(targetValue.replace(/[^0-9.]/g, ""));
      return;
    }

    // Determine if we're dealing with a number with suffix
    this.hasPlus = targetValue.includes("+");
    this.hasSuffix = /[A-Za-z]/.test(targetValue);

    // Extract just the numeric part and the suffix if any
    this.numericPart = parseFloat(targetValue.replace(/[^0-9.]/g, ""));
    this.suffix = targetValue.replace(/[0-9.+]/g, "");

    // Determine the multiplier based on K or M suffix
    if (targetValue.includes("K")) {
      this.multiplier = 1000;
      this.displayDivider = 1000;
      this.displaySuffix = "K";
    } else if (targetValue.includes("M")) {
      this.multiplier = 1000000;
      this.displayDivider = 1000000;
      this.displaySuffix = "M";
    } else {
      this.multiplier = 1;
      this.displayDivider = 1;
      this.displaySuffix = "";
    }

    // Target value for animation
    this.targetNumber = this.numericPart * this.multiplier;
  },

  // Set up intersection observer
  setupIntersectionObserver() {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (
            entry.isIntersecting &&
            (this.animated !== true || !this.config.once)
          ) {
            setTimeout(() => {
              this.animateValue();
            }, this.config.delay);
          }
        });
      },
      { threshold: 0.1 },
    );

    observer.observe(this.el);
  },

  // Easing functions for smoother animations
  easingFunctions: {
    // Linear
    linear: (t) => t,
    // Quadratic
    easeInQuad: (t) => t * t,
    easeOutQuad: (t) => t * (2 - t),
    easeInOutQuad: (t) => (t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t),
    // Cubic
    easeInCubic: (t) => t * t * t,
    easeOutCubic: (t) => --t * t * t + 1,
    easeInOutCubic: (t) =>
      t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1,
    // Elastic-like
    easeOutBack: (t) => {
      const c1 = 1.70158;
      const c3 = c1 + 1;
      return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
    },
  },

  // Format the current number for display
  formatNumber(value) {
    // Handle time format special case
    if (this.isTimeFormat) {
      return `${Math.floor(value)} ${this.timeUnit}`;
    }

    if (this.displayDivider > 1) {
      // Format as K or M
      let formattedValue = (value / this.displayDivider).toFixed(
        this.suffix ? 0 : 1,
      );
      // Remove trailing zeros and decimal point if not needed
      formattedValue = formattedValue.replace(/\.0$/, "");
      return `${formattedValue}${this.displaySuffix}${this.hasPlus ? "+" : ""}`;
    } else {
      // Regular number format
      const formattedValue = Math.floor(value).toLocaleString();
      return `${formattedValue}${this.hasPlus ? "+" : ""}${this.suffix}`;
    }
  },

  // Main animation function
  animateValue() {
    // Prevent multiple animations
    if (this.animating) return;
    this.animating = true;

    // Animation variables
    const startValue = 0;
    const endValue = this.targetNumber;
    const duration = this.config.duration;
    const startTime = performance.now();

    // Use the specified easing function
    const easingFunction =
      this.easingFunctions[this.config.easing] ||
      this.easingFunctions.easeOutQuad;

    // Animation frame
    const animate = (currentTime) => {
      // Calculate progress (0 to 1)
      let progress = Math.min((currentTime - startTime) / duration, 1);

      // Apply easing
      progress = easingFunction(progress);

      // Calculate current value
      const currentValue = startValue + progress * (endValue - startValue);

      // Update the displayed text
      this.el.textContent = this.formatNumber(currentValue);

      // Continue animation if not finished
      if (progress < 1) {
        this.animationFrame = requestAnimationFrame(animate);
      } else {
        this.animating = false;
        this.animated = true;
      }
    };

    // Start animation
    this.animationFrame = requestAnimationFrame(animate);
  },

  destroyed() {
    // Clean up animation frame if component is removed
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
  },
};
