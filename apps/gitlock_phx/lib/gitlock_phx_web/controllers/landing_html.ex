defmodule GitlockPhxWeb.LandingHTML do
  use GitlockPhxWeb, :html

  embed_templates "landing_html/*"

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

  # Feature Card Component
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icon, :string, required: true
  attr :class, :string, default: ""
  attr :delay, :string, default: "0"

  def feature_card(assigns) do
    assigns = assign_new(assigns, :id, fn -> "feature-#{:rand.uniform(10000)}" end)

    ~H"""
    <div
      id={@id}
      phx-hook="ScrollAnimation"
      data-delay={@delay}
      data-once="true"
      class={[
        "card glass-card p-6 lg:p-8 hover:scale-105 hover:shadow-2xl transition-all duration-300 cursor-pointer group rounded-xl backdrop-opacity-0.3",
        @class
      ]}
    >
      <div class="mb-6">
        <.feature_icon type={@icon} />
      </div>
      <h3 class="text-xl lg:text-2xl font-bold mb-4">{@title}</h3>
      <p class="text-base-content/70 leading-relaxed">{@description}</p>
    </div>
    """
  end

  # Feature Icons
  attr :type, :string, required: true

  def feature_icon(%{type: "hotspot"} = assigns) do
    ~H"""
    <div class="w-16 h-16 bg-error/10 rounded-2xl flex items-center justify-center border border-error/30 group-hover:scale-110 transition-transform">
      <div class="relative w-10 h-10">
        <div class="absolute inset-0 rounded-full border-2 border-error animate-radar"></div>
        <div
          class="absolute inset-0 rounded-full border-2 border-error animate-radar"
          style="animation-delay: 1s;"
        >
        </div>
        <div
          class="absolute inset-0 rounded-full border-2 border-error animate-radar"
          style="animation-delay: 2s;"
        >
        </div>
        <div class="absolute top-1/2 left-1/2 w-3 h-3 bg-error rounded-full -translate-x-1/2 -translate-y-1/2">
        </div>
      </div>
    </div>
    """
  end

  def feature_icon(%{type: "knowledge"} = assigns) do
    ~H"""
    <div class="w-16 h-16 bg-knowledge/10 rounded-2xl flex items-center justify-center border border-knowledge/30 group-hover:scale-110 transition-transform">
      <svg class="w-10 h-10" viewBox="0 0 24 24" fill="none">
        <path
          d="M12 3C16.97 3 21 7.03 21 12C21 16.97 16.97 21 12 21C7.03 21 3 16.97 3 12C3 7.03 7.03 3 12 3ZM12 19C15.86 19 19 15.86 19 12C19 8.14 15.86 5 12 5C8.14 5 5 8.14 5 12C5 15.86 8.14 19 12 19Z"
          fill="currentColor"
          class="text-knowledge animate-pulse-custom"
        />
        <path
          d="M15 9C15 7.34 13.66 6 12 6C10.34 6 9 7.34 9 9C9 10.66 10.34 12 12 12C13.66 12 15 10.66 15 9Z"
          fill="currentColor"
          class="text-knowledge"
        />
        <path
          d="M12 13C9.33 13 7 15.33 7 18H9C9 16.34 10.34 15 12 15C13.66 15 15 16.34 15 18H17C17 15.33 14.67 13 12 13Z"
          fill="currentColor"
          class="text-knowledge"
        />
      </svg>
    </div>
    """
  end

  def feature_icon(%{type: "coupling"} = assigns) do
    ~H"""
    <div class="w-16 h-16 bg-coupling/10 rounded-2xl flex items-center justify-center border border-coupling/30 group-hover:scale-110 transition-transform">
      <div class="relative w-10 h-10">
        <div class="absolute w-3 h-3 bg-coupling rounded-full top-2 left-2 animate-node-pulse"></div>
        <div
          class="absolute w-3 h-3 bg-coupling rounded-full top-8 right-2 animate-node-pulse"
          style="animation-delay: 0.3s;"
        >
        </div>
        <div
          class="absolute w-3 h-3 bg-coupling rounded-full bottom-1 left-5 animate-node-pulse"
          style="animation-delay: 0.6s;"
        >
        </div>
        <svg class="absolute inset-0 w-full h-full">
          <line
            x1="10"
            y1="10"
            x2="30"
            y2="30"
            stroke="currentColor"
            stroke-width="2"
            class="text-coupling animate-edge-pulse"
          />
          <line
            x1="10"
            y1="10"
            x2="20"
            y2="35"
            stroke="currentColor"
            stroke-width="2"
            class="text-coupling animate-edge-pulse"
            style="animation-delay: 0.3s;"
          />
          <line
            x1="30"
            y1="30"
            x2="20"
            y2="35"
            stroke="currentColor"
            stroke-width="2"
            class="text-coupling animate-edge-pulse"
            style="animation-delay: 0.6s;"
          />
        </svg>
      </div>
    </div>
    """
  end

  def feature_icon(%{type: "blast"} = assigns) do
    ~H"""
    <div class="w-16 h-16 bg-blast/10 rounded-2xl flex items-center justify-center border border-blast/30 group-hover:scale-110 transition-transform">
      <div class="relative w-10 h-10">
        <div class="absolute inset-0 rounded-full border-2 border-dashed border-blast animate-blast-wave">
        </div>
        <div
          class="absolute inset-0 rounded-full border-2 border-dashed border-blast animate-blast-wave"
          style="animation-delay: 0.5s;"
        >
        </div>
        <div
          class="absolute inset-0 rounded-full border-2 border-dashed border-blast animate-blast-wave"
          style="animation-delay: 1s;"
        >
        </div>
        <div class="absolute top-1/2 left-1/2 w-3 h-3 bg-blast rounded-full -translate-x-1/2 -translate-y-1/2">
        </div>
      </div>
    </div>
    """
  end

  def feature_icon(%{type: "output"} = assigns) do
    ~H"""
    <div class="w-16 h-16 bg-output/10 rounded-2xl flex items-center justify-center border border-output/30 group-hover:scale-110 transition-transform">
      <div class="flex items-end justify-around w-10 h-10 gap-1">
        <div class="w-1.5 bg-output rounded-t animate-bar-grow" style="height: 60%;"></div>
        <div
          class="w-1.5 bg-output rounded-t animate-bar-grow"
          style="height: 80%; animation-delay: 0.2s;"
        >
        </div>
        <div
          class="w-1.5 bg-output rounded-t animate-bar-grow"
          style="height: 40%; animation-delay: 0.4s;"
        >
        </div>
        <div
          class="w-1.5 bg-output rounded-t animate-bar-grow"
          style="height: 70%; animation-delay: 0.6s;"
        >
        </div>
      </div>
    </div>
    """
  end

  def feature_icon(%{type: "speed"} = assigns) do
    ~H"""
    <div class="w-16 h-16 bg-speed/10 rounded-2xl flex items-center justify-center border border-speed/30 group-hover:scale-110 transition-transform overflow-visible">
      <div class="relative w-10 h-10">
        <svg
          class="w-8 h-9 absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
          viewBox="0 0 24 24"
          fill="none"
        >
          <path
            d="M13 2L3 14H12L11 22L21 10H12L13 2Z"
            fill="currentColor"
            class="text-speed drop-shadow-glow"
          />
        </svg>
        <div
          class="absolute w-1 h-1 bg-speed rounded-full top-2 right-0 animate-spark-fly"
          style="animation-delay: 0.3s;"
        >
        </div>
        <div
          class="absolute w-1 h-1 bg-speed rounded-full top-6 -right-1 animate-spark-fly"
          style="animation-delay: 0.6s;"
        >
        </div>
        <div
          class="absolute w-1 h-1 bg-speed rounded-full bottom-2 right-1 animate-spark-fly"
          style="animation-delay: 0.9s;"
        >
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a stat card with animated number, title and description.

  ## Examples

      <.stat_card 
        number="10K+" 
        title="Repositories Analyzed" 
        description="Over ten thousand open-source and private codebases scanned to date."
        duration="2000"
        delay="0"
        easing="easeOutCubic" 
      />
  """
  attr :id, :string, required: true
  attr :number, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :duration, :string, default: "2000"
  attr :delay, :string, default: "0"
  attr :easing, :string, default: "easeOutQuad"
  attr :once, :string, default: "true"
  attr :class, :string, default: ""

  def stat_card(assigns) do
    ~H"""
    <div class={"card glass-card p-6 transition-all hover:-translate-y-1 hover:shadow-xl #{@class}"}>
      <p class="text-3xl md:text-4xl font-extrabold mb-2">
        <span
          id={@id}
          phx-hook="AnimateNumber"
          data-number={@number}
          data-duration={@duration}
          data-delay={@delay}
          data-easing={@easing}
          data-once={@once}
        >
          0
        </span>
      </p>
      <h3 class="text-lg font-bold mb-2">{@title}</h3>
      <p class="text-sm text-base-content/70">{@description}</p>
    </div>
    """
  end

  # Step Card Component
  attr :number, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  def step_card(assigns) do
    ~H"""
    <div class="card glass-card p-8 flex flex-col md:flex-row items-center gap-6 hover:translate-x-2 hover:shadow-xl transition-all duration-300">
      <div class="flex-shrink-0 w-16 h-16 bg-primary/10 border-2 border-primary rounded-2xl flex items-center justify-center text-2xl font-bold text-primary">
        {@number}
      </div>
      <div class="text-center md:text-left">
        <h3 class="text-2xl font-semibold mb-2">{@title}</h3>
        <p class="text-base-content/70">{@description}</p>
      </div>
    </div>
    """
  end
end
