defmodule GitlockPhxWeb.LandingHTML do
  use GitlockPhxWeb, :html

  embed_templates "landing_html/*"

  # Background Effects Component
  def background_effects(assigns) do
    ~H"""
    <!-- Grid Background -->
    <div class="fixed inset-0 pointer-events-none z-0">
      <div
        class="absolute inset-0 animate-grid-pulse transition-all duration-300"
        style="
          background-image: radial-gradient(
            circle,
            rgba(96, 165, 250, 0.4) 2px,
            transparent 2px
          );
          background-size: 20px 20px;
          background-position: 0 0;
        "
      >
      </div>
    </div>
    <!-- Gradient Overlay -->
    <div class="fixed inset-0 pointer-events-none z-[1]">
      <!-- Primary gradient -->
      <div
        class="absolute inset-0 animate-gradient-shift"
        style="
          background: radial-gradient(
            circle at 20% 50%,
            rgba(96, 165, 250, 0.15) 0%,
            transparent 40%
          );
          transform-origin: center;
        "
      >
      </div>
      <!-- Secondary gradient -->
      <div
        class="absolute inset-0 animate-gradient-shift"
        style="
          background: radial-gradient(
            circle at 80% 80%,
            rgba(167, 139, 250, 0.1) 0%,
            transparent 40%
          );
          animation-delay: 6.67s;
          transform-origin: center;
        "
      >
      </div>
      <!-- Accent gradient -->
      <div
        class="absolute inset-0 animate-gradient-shift"
        style="
          background: radial-gradient(
            circle at 40% 20%,
            rgba(52, 211, 153, 0.1) 0%,
            transparent 40%
          );
          animation-delay: 13.33s;
          transform-origin: center;
        "
      >
      </div>
    </div>
    """
  end

  @doc "Renders the Gitlock logo SVG, inheriting color from the parent"
  attr :class, :string, default: "h-6", doc: "Tailwind utility classes"

  def logo_svg(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height="100"
      viewBox="0 0 369.895 88.497"
      class={["logo-svg", @class]}
    >
      <path
        xmlns="http://www.w3.org/2000/svg"
        d="M43.78 88.498c-9.655 0-18.969-4.202-25.33-12.04A652 652 0 0 0 5.277 60.784C1.073 56.014-.744 49.767.278 43.52S4.935 31.822 10.5 28.641L54.796 2.86c6.02-3.521 13.29-3.748 19.536-.909 6.247 2.953 10.677 8.746 11.812 15.56l5.68 34.529a20.965 20.965 0 0 1-11.018 22.034c-5.792 3.067-13.63 6.815-23.17 11.245a31.7 31.7 0 0 1-13.857 3.18M12.66 32.503c-4.317 2.499-7.156 6.701-7.951 11.585s.681 9.882 3.975 13.516c3.862 4.316 8.291 9.655 13.289 15.788 8.178 9.995 22.034 13.175 33.733 7.723 9.427-4.43 17.15-8.177 22.943-11.244 6.36-3.294 9.768-10.222 8.632-17.264l-5.679-34.529c-.908-5.451-4.316-9.881-9.2-12.153-4.997-2.385-10.563-2.044-15.333.682z"
        fill="currentColor"
      />
      <path
        d="m167.81 26.962-4.298 4.076q-4.632-4.563-10.148-6.917t-10.79-2.354q-6.504 0-12.391 3.216t-9.137 8.666-3.254 10.393q0 6.277 3.368 11.904t9.287 8.824 12.953 3.196q8.525 0 14.45-4.823t7.044-12.487h-17.681v-5.344h23.848q-.073 12.862-7.606 20.41t-20.242 7.553q-15.327 0-24.296-10.47Q112 54.73 112 44.154q0-7.886 3.943-14.056t10.86-10.014 15.625-3.851q7.028 0 13.233 2.565t12.15 8.165m14.726-11.963q1.795 0 3.085 1.271t1.29 3.063-1.29 3.085-3.085 1.29-3.063-1.29-1.274-3.082 1.274-3.066 3.063-1.27m-2.615 16.857h5.271v41.008h-5.27zm30.952 35.217q-3.889 2.094-7.629.337-4.559-3.48-4.333-9.907V40.156h9.72v-4.52h-9.762V15.819h-5.305v42.577q-.077 4.486 2.055 8.222 3.514 5.945 9.57 6.282 3.215.115 7.327-1.455-.636-1.573-1.646-4.375m9.232-51.064h5.31v56.86h-5.31zm35.588 13.83q9.455 0 15.698 6.84 5.646 6.278 5.646 14.841t-5.982 14.971T255.69 72.9q-9.42 0-15.384-6.412t-5.964-14.967q0-8.528 5.646-14.806 6.24-6.879 15.702-6.879m0 5.16q-6.545 0-11.254 4.862t-4.708 11.736q0 4.448 2.147 8.318t5.815 5.94 8 2.076q4.41 0 8.054-2.075t5.776-5.941 2.132-8.318q0-6.879-4.708-11.74t-11.254-4.858m70.839 4.41-4.188 2.618q-5.42-7.254-14.802-7.254-7.514 0-12.468 4.824T290.12 51.33q0 4.486 2.282 8.467t6.239 6.151 8.9 2.167q9.083 0 14.802-7.177l4.188 2.73q-2.955 4.409-7.908 6.82T307.314 72.9q-9.685 0-16.092-6.167t-6.412-14.99q0-5.983 3.009-11.085t8.226-7.962 11.717-2.86q4.038 0 7.832 1.233t6.45 3.234 4.486 5.103m10.018-23.4h5.305V48.38l18.956-16.522h7.77l-17.152 15.588 18.465 25.417h-7.476l-16.153-22.053-4.406 3.625v18.431h-5.31z"
        fill="currentColor"
      />
    </svg>
    """
  end

  # Navigation Component
  def navigation(assigns) do
    ~H"""
    <nav
      id="main-nav"
      class="fixed top-8 left-1/2 transform -translate-x-1/2 w-[90%] max-w-4xl z-50 transition-all duration-300"
      style="
        background: rgba(255, 255, 255, 0.05);
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 16px;
        box-shadow: 0 8px 32px 0 rgba(96, 165, 250, 0.1);
      "
      phx-hook="MobileMenu"
    >
      <div class="flex justify-between items-center px-6 py-2">
        <!-- Logo -->
        <div class="flex-1">
          <.logo_svg class="h-5" />
        </div>
        
    <!-- Mobile Controls: Theme Toggle + Menu Button -->
        <div class="flex items-center md:hidden">
          <!-- Theme Toggle (Always Visible) -->
          <div class="mr-2">
            <Layouts.theme_toggle />
          </div>
          
    <!-- Hamburger Button -->
          <button
            id="mobile-menu-button"
            class="rounded-lg text-base-content/70 hover:text-base-content hover:bg-white/5 p-2"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 6h16M4 12h16M4 18h16"
              />
            </svg>
          </button>
        </div>
        
    <!-- Desktop Navigation -->
        <ul class="hidden md:flex items-center gap-2">
          <li>
            <a
              href="#features"
              class="px-4 py-2 rounded-lg text-base-content/70 hover:text-base-content hover:bg-white/5 transition-all duration-300"
            >
              Features
            </a>
          </li>
          <li>
            <a
              href="#docs"
              class="px-4 py-2 rounded-lg text-base-content/70 hover:text-base-content hover:bg-white/5 transition-all duration-300"
            >
              Documentation
            </a>
          </li>
          <li>
            <a
              href="https://github.com/BillQK/gitlock"
              class="px-4 py-2 rounded-lg text-base-content/70 hover:text-base-content hover:bg-white/5 transition-all duration-300"
            >
              GitHub
            </a>
          </li>
          <li class="ml-4">
            <Layouts.theme_toggle />
          </li>
        </ul>
      </div>
      
    <!-- Mobile Menu with Tailwind Animation -->
      <div
        id="mobile-menu"
        class="md:hidden max-h-0 opacity-0 overflow-hidden transition-all duration-500 ease-out border-t border-white/10 border-opacity-0"
      >
        <ul class="flex flex-col px-4 py-3 space-y-2">
          <li>
            <a
              href="#features"
              class="block px-4 py-2 rounded-lg text-base-content/70 hover:text-base-content hover:bg-white/5 transition-all duration-300"
            >
              Features
            </a>
          </li>
          <li>
            <a
              href="#docs"
              class="block px-4 py-2 rounded-lg text-base-content/70 hover:text-base-content hover:bg-white/5 transition-all duration-300"
            >
              Documentation
            </a>
          </li>
          <li>
            <a
              href="https://github.com/BillQK/gitlock"
              class="block px-4 py-2 rounded-lg text-base-content/70 hover:text-base-content hover:bg-white/5 transition-all duration-300"
            >
              GitHub
            </a>
          </li>
        </ul>
      </div>
    </nav>
    """
  end

  # Hero Section Component
  def hero_section(assigns) do
    ~H"""
    <section class="hero min-h-screen relative z-10">
      <div class="hero-content text-center max-w-4xl mx-auto px-4 pt-36">
        <div class="w-full">
          <div class="indicator">
            <span class="indicator-item badge badge-sm bg-red-500/90 border border-red-400/50 text-white font-medium text-xs tracking-wider backdrop-blur-sm animate-pulse">
              BETA
            </span>
            <div class="badge badge-lg bg-base-200/10 border border-base-300/20 text-base-content backdrop-blur-lg mb-12 animate-fade-in-up rounded-2xl px-8 py-3 tracking-wide hover:bg-base-200/20 hover:border-base-300/30 hover:-translate-y-1 hover:shadow-2xl transition-all duration-500">
              <span class="gradient-text animate-gradient-text">Terminal Friendly</span>
            </div>
          </div>

          <h1 class="text-5xl md:text-7xl font-black mb-8 animate-fade-in animation-delay-200">
            Uncover the <span class="gradient-text animate-gradient-text">Hidden Stories</span>
            <br /> in Your Codebase
          </h1>

          <p class="text-xl md:text-2xl text-base-content/70 mb-12 max-w-3xl mx-auto animate-fade-in animation-delay-400">
            Transform your Git history into actionable insights.<br />
            Identify hotspots, knowledge silos, and risky dependencies.
          </p>

          <div class="flex flex-col sm:flex-row gap-4 justify-center mb-16 animate-fade-in animation-delay-600">
            <a
              href="#"
              class="btn btn-primary btn-lg shadow-xl hover:shadow-2xl hover:-translate-y-1 transition-all"
            >
              Get Started
            </a>
            <a href="#" class="btn btn-ghost btn-lg glass-card">
              View Documentation
            </a>
          </div>

          <.terminal_preview />
        </div>
      </div>
    </section>
    """
  end

  # Terminal Preview Component
  def terminal_preview(assigns) do
    ~H"""
    <div class="terminal-preview max-w-3xl mx-auto animate-fade-in animation-delay-800">
      <div class="terminal-header flex items-center p-3 bg-[rgba(255,255,255,0.05)] border border-[rgba(255,255,255,0.1)] rounded-t-lg">
        <div class="terminal-dots flex gap-1">
          <span class="w-3 h-3 rounded-full bg-[#ff5f56]"></span>
          <span class="w-3 h-3 rounded-full bg-[#ffbd2e]"></span>
          <span class="w-3 h-3 rounded-full bg-[#27c93f]"></span>
        </div>
      </div>

      <div class="terminal-body p-6 font-mono text-sm  border border-[rgba(255,255,255,0.1)] rounded-b-lg">
        <div class="terminal-line mb-2 opacity-0 animate-typeIn" style="animation-delay: 1s">
          <span class="terminal-prompt text-[var(--primary)]">$</span>
          gitlock hotspots --repo ./my-project
        </div>
        <div class="terminal-line mb-2 opacity-0 animate-typeIn" style="animation-delay: 1.2s">
          <span class="terminal-success text-[var(--accent)]">✓</span>
          Analyzing 847 commits across 234 files...
        </div>
        <div class="terminal-line mb-2 opacity-0 animate-typeIn" style="animation-delay: 1.4s">
          <span class="terminal-info text-[var(--secondary)]">→</span>
          lib/auth/session.ex – <span class="terminal-error text-[#ef4444]">Risk: 8.5 [HIGH]</span>
        </div>
        <div class="terminal-line mb-2 opacity-0 animate-typeIn" style="animation-delay: 1.6s">
          <span class="terminal-info text-[var(--secondary)]">→</span>
          lib/core/parser.ex – <span class="terminal-warning text-[#f59e0b]">Risk: 6.2 [MEDIUM]</span>
        </div>
        <div class="terminal-line mb-2 opacity-0 animate-typeIn" style="animation-delay: 1.8s">
          <span class="terminal-success text-[var(--accent)]">✓</span>
          Report saved to output/hotspots_20240604.csv
        </div>
      </div>
    </div>
    """
  end

  # Features Section Component
  def features_section(assigns) do
    ~H"""
    <section id="features" class="py-24 px-4 relative z-10">
      <div class="max-w-7xl mx-auto">
        <div class="text-center mb-16">
          <h2 class="text-4xl md:text-5xl font-bold mb-4">
            <span class="gradient-text">Forensic Analysis</span> for Modern
            Codebases
          </h2>
          <p class="text-xl text-base-content/70">
            Inspired by Adam Tornhill's "Your Code as a Crime Scene" methodology
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-6 gap-6 auto-rows-[300px]">
          <.feature_card
            title="Hotspot Detection"
            description="Identify files that are both complex and frequently changed. These hotspots are statistically more likely to contain bugs and require immediate attention."
            icon="hotspot"
            class="lg:col-span-3 lg:row-span-2 animate-float-odd"
            delay="0"
          />

          <.feature_card
            title="Knowledge Silos"
            description="Discover files owned primarily by one developer. Reduce team risk by identifying knowledge bottlenecks."
            icon="knowledge"
            class="lg:col-span-3 animate-float-even animation-delay-500"
            delay="0"
          />

          <.feature_card
            title="Temporal Coupling"
            description="Find hidden dependencies between files that consistently change together."
            icon="coupling"
            class="lg:col-span-2 animate-float-odd animation-delay-1000"
            delay="0"
          />

          <.feature_card
            title="Blast Radius Analysis"
            description="Assess the potential impact of changing specific files. Make informed decisions about refactoring and understand ripple effects."
            icon="blast"
            class="lg:col-span-2 lg:row-span-2 animate-float-even animation-delay-1500"
            delay="0"
          />

          <.feature_card
            title="Flexible Output"
            description="Export results in CSV, JSON, or view directly in terminal."
            icon="output"
            class="lg:col-span-2 animate-float-odd animation-delay-2000"
            delay="0"
          />

          <.feature_card
            title="Lightning Fast"
            description="Analyze thousands of commits in minutes. Efficient algorithms ensure you get insights quickly, even for large enterprise repositories."
            icon="speed"
            class="lg:col-span-3 animate-float-even animation-delay-2500"
            delay="0"
          />
        </div>
      </div>
    </section>
    """
  end

  # Feature Card Component
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icon, :string, required: true
  attr :class, :string, default: ""
  attr :delay, :string, default: "0"

  def feature_card(assigns) do
    ~H"""
    <div class={"feature-card #{@class}"}>
      <div class={"feature-icon-wrapper feature-icon-#{@icon}"}>
        <.feature_icon type={@icon} />
      </div>
      <h3 class="text-xl font-semibold mb-3">{@title}</h3>
      <p class="text-base-content/70 leading-relaxed">{@description}</p>
    </div>
    """
  end

  # Feature Icon Component
  # Updated Feature Icon Component with Animations

  attr :type, :string, required: true

  def feature_icon(assigns) do
    ~H"""
    <%= case @type do %>
      <% "hotspot" -> %>
        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <!-- Radar screen -->
          <circle cx="12" cy="12" r="10" stroke-width="2" />
          <circle cx="12" cy="12" r="7" stroke-width="1" opacity="0.6" />
          <circle cx="12" cy="12" r="4" stroke-width="1" opacity="0.7" />
          
    <!-- Crosshair grid -->
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1"
            opacity="0.4"
            d="M12 2v20M2 12h20"
          />
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="0.5"
            opacity="0.3"
            d="M5.76 5.76l12.48 12.48M5.76 18.24L18.24 5.76"
          />
          
    <!-- Scanning sweep -->
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2.5"
            opacity="0.8"
            d="M12 12L19 5"
            stroke-dasharray="2,1"
          >
            <animateTransform
              attributeName="transform"
              type="rotate"
              values="0 12 12;360 12 12"
              dur="3s"
              repeatCount="indefinite"
            />
          </path>
          
    <!-- Target blips with heat -->
          <g>
            <g transform="translate(16,8)">
              <circle r="1.5" fill="none" stroke="currentColor" stroke-width="1.5" />
              <circle r="0.5" fill="currentColor">
                <animate attributeName="opacity" values="0.5;1;0.5" dur="1s" repeatCount="indefinite" />
              </circle>
            </g>
            <g transform="translate(8,16)">
              <circle r="1" fill="none" stroke="currentColor" stroke-width="1" />
              <circle r="0.3" fill="currentColor">
                <animate
                  attributeName="opacity"
                  values="0.3;0.9;0.3"
                  dur="1.5s"
                  repeatCount="indefinite"
                />
              </circle>
            </g>
            <g transform="translate(15,16)">
              <circle r="0.8" fill="currentColor">
                <animate attributeName="opacity" values="0.4;1;0.4" dur="2s" repeatCount="indefinite" />
                <animate attributeName="r" values="0.5;1.2;0.5" dur="2s" repeatCount="indefinite" />
              </circle>
            </g>
          </g>
        </svg>
      <% "coupling" -> %>
        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <!-- Use original single path -->
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"
          >
            <animate
              attributeName="stroke-dasharray"
              values="0,200;100,100;0,200"
              dur="3s"
              repeatCount="indefinite"
            />
          </path>
          
    <!-- Connection pulse -->
          <circle cx="12" cy="12" r="1" fill="currentColor" opacity="0.5">
            <animate attributeName="r" values="0.5;2;0.5" dur="2s" repeatCount="indefinite" />
            <animate attributeName="opacity" values="0.7;0.2;0.7" dur="2s" repeatCount="indefinite" />
          </circle>
          
    <!-- Data flow between linked files -->
          <g opacity="0.4">
            <circle cx="8" cy="16" r="0.5" fill="currentColor">
              <animate attributeName="cx" values="8;16;8" dur="2.5s" repeatCount="indefinite" />
              <animate attributeName="cy" values="16;8;16" dur="2.5s" repeatCount="indefinite" />
              <animate
                attributeName="opacity"
                values="0.8;0.3;0.8"
                dur="2.5s"
                repeatCount="indefinite"
              />
            </circle>
            <circle cx="16" cy="8" r="0.5" fill="currentColor">
              <animate
                attributeName="cx"
                values="16;8;16"
                dur="2.5s"
                begin="1.25s"
                repeatCount="indefinite"
              />
              <animate
                attributeName="cy"
                values="8;16;8"
                dur="2.5s"
                begin="1.25s"
                repeatCount="indefinite"
              />
              <animate
                attributeName="opacity"
                values="0.8;0.3;0.8"
                dur="2.5s"
                begin="1.25s"
                repeatCount="indefinite"
              />
            </circle>
          </g>
        </svg>
      <% "blast" -> %>
        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <!-- Warning triangle -->
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 2L2 20h20L12 2z"
          >
            <animate
              attributeName="stroke-width"
              values="2;2.5;2"
              dur="1.5s"
              repeatCount="indefinite"
            />
          </path>
          
    <!-- Warning symbol -->
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01">
            <animate attributeName="opacity" values="0.7;1;0.7" dur="1s" repeatCount="indefinite" />
          </path>
          
    <!-- Blast radius waves -->
          <circle cx="12" cy="12" r="15" stroke-width="1.5" opacity="0.4">
            <animate attributeName="r" values="12;18;12" dur="2s" repeatCount="indefinite" />
            <animate attributeName="opacity" values="0.4;0.1;0.4" dur="2s" repeatCount="indefinite" />
          </circle>

          <circle cx="12" cy="12" r="12" stroke-width="1" opacity="0.3">
            <animate
              attributeName="r"
              values="10;15;10"
              dur="1.8s"
              begin="0.2s"
              repeatCount="indefinite"
            />
            <animate
              attributeName="opacity"
              values="0.3;0.05;0.3"
              dur="1.8s"
              begin="0.2s"
              repeatCount="indefinite"
            />
          </circle>
          
    <!-- Impact indicators -->
          <g opacity="0.6">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M12 4L10 8h4l-2-4zM12 20l2-4h-4l2 4zM4 12l4-2v4l-4-2zM20 12l-4 2v-4l4 2"
            >
              <animate
                attributeName="opacity"
                values="0.3;0.8;0.3"
                dur="1.2s"
                repeatCount="indefinite"
              />
            </path>
          </g>
        </svg>
      <% "output" -> %>
        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <!-- Document base -->
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M19 21H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
          />
          
    <!-- Document corner -->
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v6h6" />
          
    <!-- Animated bars growing -->
          <g stroke-width="2" stroke-linecap="round">
            <line x1="9" y1="17" x2="9" y2="15">
              <animate attributeName="y2" values="17;13;15" dur="2s" repeatCount="indefinite" />
            </line>
            <line x1="12" y1="17" x2="12" y2="13">
              <animate attributeName="y2" values="17;11;13" dur="2.2s" repeatCount="indefinite" />
            </line>
            <line x1="15" y1="17" x2="15" y2="11">
              <animate attributeName="y2" values="17;9;11" dur="2.4s" repeatCount="indefinite" />
            </line>
          </g>
          
    <!-- Generating data effect -->
          <g opacity="0.5">
            <circle cx="7" cy="10" r="0.5" fill="currentColor">
              <animate attributeName="cy" values="10;17;10" dur="1.5s" repeatCount="indefinite" />
              <animate
                attributeName="opacity"
                values="0.8;0.2;0.8"
                dur="1.5s"
                repeatCount="indefinite"
              />
            </circle>
            <circle cx="11" cy="12" r="0.5" fill="currentColor">
              <animate
                attributeName="cy"
                values="12;17;12"
                dur="1.8s"
                begin="0.3s"
                repeatCount="indefinite"
              />
              <animate
                attributeName="opacity"
                values="0.8;0.2;0.8"
                dur="1.8s"
                begin="0.3s"
                repeatCount="indefinite"
              />
            </circle>
          </g>
          
    <!-- Export arrow -->
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1"
            opacity="0.6"
            d="M20 12h2m-1-1l1 1-1 1"
          >
            <animate attributeName="opacity" values="0.3;0.9;0.3" dur="1.5s" repeatCount="indefinite" />
          </path>
        </svg>
      <% "speed" -> %>
        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <!-- Main lightning bolt -->
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M13 10V3L4 14h7v7l9-11h-7z"
          >
            <animate attributeName="opacity" values="0.8;1;0.8" dur="0.8s" repeatCount="indefinite" />
          </path>
          
    <!-- Electric energy trails -->
          <g opacity="0.6">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M11 8L9 12l2-1M15 12l2 4-2-1"
            >
              <animate
                attributeName="opacity"
                values="0.3;0.8;0.3"
                dur="0.6s"
                repeatCount="indefinite"
              />
              <animate
                attributeName="stroke-dasharray"
                values="0,10;5,5;0,10"
                dur="0.6s"
                repeatCount="indefinite"
              />
            </path>
          </g>
          
    <!-- Speed lines -->
          <g opacity="0.4">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1"
              d="M2 8h3M1 12h4M2 16h3"
            >
              <animate
                attributeName="opacity"
                values="0.2;0.6;0.2"
                dur="0.4s"
                repeatCount="indefinite"
              />
              <animate
                attributeName="transform"
                values="translateX(0);translateX(2);translateX(0)"
                dur="0.4s"
                repeatCount="indefinite"
              />
            </path>
          </g>
          
    <!-- Energy sparks -->
          <circle cx="8" cy="10" r="0.5" fill="currentColor" opacity="0.7">
            <animate attributeName="opacity" values="0;1;0" dur="0.3s" repeatCount="indefinite" />
            <animate attributeName="r" values="0.2;0.8;0.2" dur="0.3s" repeatCount="indefinite" />
          </circle>

          <circle cx="16" cy="14" r="0.5" fill="currentColor" opacity="0.7">
            <animate
              attributeName="opacity"
              values="0;1;0"
              dur="0.4s"
              begin="0.1s"
              repeatCount="indefinite"
            />
            <animate
              attributeName="r"
              values="0.2;0.6;0.2"
              dur="0.4s"
              begin="0.1s"
              repeatCount="indefinite"
            />
          </circle>
          
    <!-- Motion blur effect -->
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="3"
            opacity="0.2"
            d="M13 10V3L4 14h7v7l9-11h-7z"
          >
            <animate attributeName="opacity" values="0;0.3;0" dur="0.8s" repeatCount="indefinite" />
          </path>
        </svg>
      <% "knowledge" -> %>
        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <!-- Book pages -->
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
          />
          
    <!-- Page turning animation -->
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1"
            opacity="0.6"
            d="M8 8h2M8 10h2M8 12h1.5"
          >
            <animate attributeName="opacity" values="0.6;1;0.6" dur="2s" repeatCount="indefinite" />
          </path>

          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1"
            opacity="0.6"
            d="M14 8h2M14 10h2M14 12h1.5"
          >
            <animate
              attributeName="opacity"
              values="0.6;1;0.6"
              dur="2s"
              begin="0.5s"
              repeatCount="indefinite"
            />
          </path>
          
    <!-- Knowledge flow -->
          <g opacity="0.4">
            <circle cx="7" cy="9" r="0.5" fill="currentColor">
              <animate attributeName="cy" values="9;15;9" dur="3s" repeatCount="indefinite" />
              <animate attributeName="opacity" values="0.8;0.2;0.8" dur="3s" repeatCount="indefinite" />
            </circle>
            <circle cx="17" cy="11" r="0.5" fill="currentColor">
              <animate
                attributeName="cy"
                values="11;17;11"
                dur="3.5s"
                begin="0.5s"
                repeatCount="indefinite"
              />
              <animate
                attributeName="opacity"
                values="0.8;0.2;0.8"
                dur="3.5s"
                begin="0.5s"
                repeatCount="indefinite"
              />
            </circle>
          </g>
          
    <!-- Learning indicator -->
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="0.5"
            opacity="0.3"
            d="M12 4c0-1 1-1 1-1s1 0 1 1"
          >
            <animate attributeName="opacity" values="0.2;0.7;0.2" dur="1.5s" repeatCount="indefinite" />
          </path>
        </svg>
      <% _ -> %>
        <div class="w-8 h-8 bg-primary/20 rounded animate-pulse"></div>
    <% end %>
    """
  end

  # Stats Section Component
  def stats_section(assigns) do
    ~H"""
    <section class="py-24 px-4 relative z-10">
      <div class="max-w-7xl mx-auto">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
          <!-- Left Column -->
          <div class="animate-fade-in">
            <p class="text-sm font-semibold text-base-content/70 mb-2">
              Built for Development Teams
            </p>
            <h2 class="text-4xl md:text-5xl font-bold mb-6">
              Transform Your Git History<br /> Into
              <span class="gradient-text animate-gradient-text">Actionable Insights</span>
            </h2>
            <p class="text-lg text-base-content/70 mb-8">
              Gitlock has already analyzed millions of commits across thousands of repositories.
              Quickly pinpoint hotspots, uncover hidden dependencies, and reduce technical debt—
              all without leaving your terminal or CI pipeline.
            </p>
            <div class="flex flex-col sm:flex-row gap-4">
              <a href="#" class="btn btn-ghost glass-card">Get Started</a>
              <a href="#" class="btn btn-primary">View Docs</a>
            </div>
          </div>
          
    <!-- Right Column: Stats Grid -->
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
            <.stat_card
              id="stat-repos"
              number="10K+"
              title="Repositories Analyzed"
              description="Over ten thousand open-source and private codebases scanned to date."
              duration="2000"
              delay="0"
              easing="easeOutCubic"
              class="animate-fade-in"
            />

            <.stat_card
              id="stat-accuracy"
              number="85%"
              title="Bug Prediction Accuracy"
              description="Proven accuracy in predicting high-risk files before code goes live."
              duration="2200"
              delay="200"
              easing="easeOutQuad"
              class="animate-fade-in animation-delay-200"
            />

            <.stat_card
              id="stat-time"
              number="3min"
              title="Average Analysis Time"
              description="Scan a medium-sized monorepo in under three minutes on a standard laptop."
              duration="1500"
              delay="400"
              easing="easeInOutCubic"
              class="animate-fade-in animation-delay-400"
            />

            <.stat_card
              id="stat-satisfaction"
              number="95%"
              title="Dev Team Satisfaction"
              description="Percent of users who rate Gitlock 'very satisfied' after one month."
              duration="2400"
              delay="600"
              easing="easeOutQuad"
              class="animate-fade-in animation-delay-600"
            />
          </div>
        </div>
      </div>
    </section>
    """
  end

  # Stat Card Component
  attr :id, :string, required: true
  attr :number, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :duration, :string, default: "2000"
  attr :delay, :string, default: "0"
  attr :easing, :string, default: "easeOutCubic"
  attr :class, :string, default: ""
  attr :once, :string, default: "true"

  def stat_card(assigns) do
    ~H"""
    <div class={"card glass-card p-6 text-center hover:scale-105 transition-transform duration-300 #{@class}"}>
      <span
        id={@id}
        phx-hook="AnimateNumber"
        data-number={@number}
        data-duration={@duration}
        data-delay={@delay}
        data-easing={@easing}
        data-once={@once}
        class="text-3xl font-bold mb-2 gradient-text animate-gradient-text"
      >
        0
      </span>
      <h3 class="text-xl font-semibold mb-2">{@title}</h3>
      <p class="text-base-content/70">{@description}</p>
    </div>
    """
  end

  # How It Works Section Component
  def how_it_works_section(assigns) do
    ~H"""
    <section id="how-it-works" class="py-24 px-4 relative z-10">
      <div class="max-w-5xl mx-auto">
        <div class="text-center mb-16">
          <h2 class="text-4xl md:text-5xl font-bold mb-4">
            Simple Yet
            <span class="gradient-text animate-gradient-text">
              Powerful
            </span>
          </h2>
          <p class="text-xl text-base-content/70">
            Get actionable insights in three easy steps
          </p>
        </div>

        <div class="space-y-6">
          <.step_card
            number="1"
            title="Point to Your Repository"
            description="Simply provide the path to your Git repository or a remote URL. Works with any Git-based project, from small libraries to massive monorepos."
          />
          <.step_card
            number="2"
            title="Choose Your Investigation"
            description="Select from hotspots, knowledge silos, coupling analysis, or run a comprehensive suite. Filter by date ranges, authors, or specific paths for targeted insights."
          />
          <.step_card
            number="3"
            title="Act on Insights"
            description="Receive clear, prioritized recommendations. Know exactly which files need refactoring, which team members need backup, and where architectural improvements are needed."
          />
        </div>
      </div>
    </section>
    """
  end

  # Step Card Component
  attr :number, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  def step_card(assigns) do
    ~H"""
    <div class="card glass-card p-8 flex flex-col md:flex-row items-center gap-6 group hover:scale-[1.02] transition-all duration-300">
      <div class="flex-shrink-0">
        <div class="w-16 h-16 rounded-full bg-primary/20 flex items-center justify-center text-2xl font-bold text-primary group-hover:scale-110 transition-transform duration-300">
          {@number}
        </div>
      </div>
      <div class="text-center md:text-left">
        <h3 class="text-2xl font-semibold mb-2">{@title}</h3>
        <p class="text-base-content/70">{@description}</p>
      </div>
    </div>
    """
  end

  # CTA Section Component
  def cta_section(assigns) do
    ~H"""
    <section class="py-24 px-4 relative z-10">
      <div class="max-w-3xl mx-auto">
        <div class="card glass-card p-12 text-center overflow-hidden">
          <div class="absolute inset-0 bg-gradient-radial from-primary/10 to-transparent opacity-50">
          </div>
          <div class="relative z-10">
            <h2 class="text-4xl md:text-5xl font-bold mb-6">
              Ready to Investigate Your Code?
            </h2>
            <p class="text-xl text-base-content/70 mb-8">
              Join hundreds of teams using Gitlock to improve code quality and
              reduce technical debt.
            </p>
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
              <a href="#" class="btn btn-primary btn-lg">Install Gitlock</a>
              <a href="https://github.com/BillQK/gitlock" class="btn btn-ghost btn-lg glass-card">
                Star on GitHub
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # Footer Section Component
  def footer_section(assigns) do
    ~H"""
    <footer class="footer footer-horizontal footer-center p-10 text-base-content/70 border-t border-base-300">
      <nav class="flex flex-wrap gap-4">
        <a href="#" class="link link-hover">Documentation</a>
        <a href="#" class="link link-hover">API Reference</a>
        <a href="#" class="link link-hover">Contributing</a>
        <a href="#" class="link link-hover">License</a>
        <a href="#" class="link link-hover">Privacy Policy</a>
      </nav>
      <aside>
        <p>© 2025 Gitlock. Made with ❤️ by the Gitlock team. MIT Licensed.</p>
      </aside>
    </footer>
    """
  end
end
