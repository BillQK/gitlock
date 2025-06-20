defmodule GitlockPhxWeb.HotspotsPreviewLive do
  use GitlockPhxWeb, :live_view

  @filtered_repos [
    %{
      name: "facebook/react",
      url: "https://github.com/facebook/react",
      description: "The library for web and native user interfaces",
      stars: 228_000,
      language: "JavaScript",
      platform: "github",
      depth: 300
    },
    %{
      name: "microsoft/vscode",
      url: "https://github.com/microsoft/vscode",
      description: "Visual Studio Code",
      stars: 163_000,
      language: "TypeScript",
      platform: "github",
      depth: 300
    },
    %{
      name: "vercel/next.js",
      url: "https://github.com/vercel/next.js",
      description: "The React Framework",
      stars: 125_000,
      language: "JavaScript",
      platform: "github",
      depth: 300
    },
    %{
      name: "nodejs/node",
      url: "https://github.com/nodejs/node",
      description: "Node.js JavaScript runtime",
      stars: 107_000,
      language: "JavaScript",
      platform: "github",
      depth: 300
    },
    %{
      name: "phoenixframework/phoenix",
      url: "https://github.com/phoenixframework/phoenix",
      description: "Phoenix Framework",
      stars: 22_000,
      language: "Elixir",
      platform: "github",
      depth: 0
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:github_url, "")
     |> assign(:loading, false)
     |> assign(:results, nil)
     |> assign(:error, nil)
     |> assign(:show_suggestions, false)
     |> assign(:filtered_repos, @filtered_repos)}
  end

  @impl true
  def handle_event("update_url", %{"url" => url}, socket) do
    {:noreply, assign(socket, :github_url, url)}
  end

  @impl true
  def handle_event("analyze", _params, socket) do
    url = socket.assigns.github_url

    case validate_github_url(url) do
      :ok ->
        {:noreply,
         socket
         |> assign(:loading, true)
         |> assign(:error, nil)
         |> start_async(:analyze_repo, fn -> analyze_repository(url) end)}

      {:error, message} ->
        {:noreply, assign(socket, :error, message)}
    end
  end

  @impl true
  def handle_async(:analyze_repo, {:ok, results}, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:results, results)}
  end

  @impl true
  def handle_async(:analyze_repo, {:exit, reason}, socket) do
    error_message =
      case reason do
        {:error, msg} when is_binary(msg) -> msg
        {:badarg, _} -> "Failed to parse analysis results"
        _ -> "Analysis failed. Please try again."
      end

    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:error, error_message)}
  end

  defp analyze_repository(url) do
    limit = 100_000

    repo = Enum.find(@filtered_repos, fn repo -> repo.url == url end)

    depth =
      if repo do
        repo.depth
      else
        0
      end

    options = %{
      url: url,
      format: "csv",
      limit: limit,
      min_revs: 1,
      depth: depth
    }

    case GitlockCore.investigate(:hotspots, url, options) do
      {:ok, csv_results} ->
        parse_csv_results(url, csv_results, limit)

      {:error, reason} ->
        raise format_error(reason)
    end
  end

  defp parse_csv_results(url, csv_string, limit) do
    repo_name = url |> String.split("/") |> Enum.take(-2) |> Enum.join("/")

    try do
      lines = String.split(csv_string, "\n", trim: true)

      case lines do
        [header | data_lines] when length(data_lines) > 0 ->
          headers = String.split(header, ",")

          # Parse CSV data into hotspot maps
          hotspots =
            data_lines
            |> Enum.map(fn line -> parse_hotspot_line(line, headers) end)
            |> Enum.filter(& &1)
            # Limit for preview
            |> Enum.take(limit)

          format_analysis_results(repo_name, hotspots)

        _ ->
          # No data - return empty results
          empty_results(repo_name)
      end
    rescue
      e ->
        IO.inspect(e, label: "CSV parsing error")
        raise format_error(:csv_parse_error)
    end
  end

  defp parse_hotspot_line(line, headers) do
    values = String.split(line, ",")

    if length(values) >= length(headers) do
      # Create a map with header names as keys
      data = Enum.zip(headers, values) |> Map.new()

      %{
        "entity" => Map.get(data, "entity", ""),
        "revisions" => safe_to_integer(Map.get(data, "revisions", "0")),
        "complexity" => safe_to_integer(Map.get(data, "complexity", "0")),
        "loc" => safe_to_integer(Map.get(data, "loc", "0")),
        "risk_score" => safe_to_float(Map.get(data, "risk_score", "0")),
        "risk_factor" => Map.get(data, "risk_factor", "low")
      }
    else
      nil
    end
  end

  defp safe_to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp safe_to_integer(value), do: 0

  defp safe_to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end

  defp safe_to_float(value), do: 0.0

  defp format_analysis_results(repo_name, hotspots) do
    # Calculate accurate statistics from the hotspot data
    total_files = length(hotspots)

    critical_files =
      hotspots
      |> Enum.count(fn h ->
        risk = Map.get(h, "risk_factor", "low")
        risk == "critical" || risk == :critical
      end)

    high_risk_files =
      hotspots
      |> Enum.count(fn h ->
        risk = Map.get(h, "risk_factor", "low")
        risk == "high" || risk == :high
      end)

    # Calculate average complexity properly
    avg_complexity =
      case hotspots do
        [] ->
          0

        _ ->
          total_complexity =
            hotspots
            |> Enum.map(fn h -> Map.get(h, "complexity", 0) end)
            |> Enum.sum()

          if total_complexity > 0 do
            div(total_complexity, total_files)
          else
            0
          end
      end

    # Sum total revisions
    total_revisions =
      hotspots
      |> Enum.map(fn h -> Map.get(h, "revisions", 0) end)
      |> Enum.sum()

    # Calculate health score based on risk distribution
    health_score = calculate_health_score(hotspots)

    # Format top hotspots for display - show top risk files
    top_hotspots_formatted =
      hotspots
      |> Enum.sort_by(
        fn h ->
          {risk_to_number(Map.get(h, "risk_factor", "low")), Map.get(h, "risk_score", 0)}
        end,
        :desc
      )
      |> Enum.take(4)
      |> Enum.map(fn hotspot ->
        %{
          file: Path.basename(Map.get(hotspot, "entity", "")),
          risk: Map.get(hotspot, "risk_factor", "low"),
          score: format_score(Map.get(hotspot, "risk_score", 0)),
          changes: Map.get(hotspot, "revisions", 0)
        }
      end)

    %{
      repo_name: repo_name,
      total_files: total_files,
      critical_files: critical_files,
      high_risk_files: high_risk_files,
      hotspots: total_files,
      health: health_score,
      avg_complexity: avg_complexity,
      total_revisions: total_revisions,
      top_hotspots: top_hotspots_formatted
    }
  end

  defp risk_to_number("high"), do: 4
  defp risk_to_number("medium"), do: 3
  defp risk_to_number("low"), do: 2
  defp risk_to_number(_), do: 1

  defp empty_results(repo_name) do
    %{
      repo_name: repo_name,
      total_files: 0,
      critical_files: 0,
      high_risk_files: 0,
      hotspots: 0,
      health: 100,
      avg_complexity: 0,
      total_revisions: 0,
      top_hotspots: []
    }
  end

  defp calculate_health_score(hotspots) do
    case hotspots do
      [] ->
        100

      _ ->
        # Weight different risk levels
        risk_weights = %{
          "high" => 5,
          "medium" => 2,
          "low" => 0.5
        }

        total_risk_weight =
          hotspots
          |> Enum.map(fn h ->
            risk = Map.get(h, "risk_factor", "low")
            Map.get(risk_weights, risk, 0.5)
          end)
          |> Enum.sum()

        # Normalize to 0-100 scale
        max_possible_risk = length(hotspots) * 10
        risk_percentage = total_risk_weight / max_possible_risk * 100
        health = 100 - risk_percentage

        round(max(0, min(100, health)))
    end
  end

  defp format_score(score) when is_float(score) do
    :erlang.float_to_binary(score, decimals: 1)
  end

  defp format_score(score) when is_integer(score) do
    "#{score}.0"
  end

  defp format_score(score) when is_binary(score) do
    case Float.parse(score) do
      {float, _} -> format_score(float)
      :error -> "0.0"
    end
  end

  @impl true
  def handle_event("show_suggestions", _params, socket) do
    {:noreply, assign(socket, :show_suggestions, true)}
  end

  @impl true
  def handle_event("hide_suggestions", _params, socket) do
    # Delay hiding to allow click events to register
    Process.send_after(self(), :hide_suggestions, 200)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_repo", %{"url" => url}, socket) do
    {:noreply,
     socket
     |> assign(:github_url, url)
     |> assign(:show_suggestions, false)}
  end

  @impl true
  def handle_info(:hide_suggestions, socket) do
    {:noreply, assign(socket, :show_suggestions, false)}
  end

  # Helper functions:

  defp get_platform_icon("github") do
    ~s"""
    <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
    </svg>
    """
    |> raw()
  end

  defp get_platform_icon("gitlab") do
    ~s"""
    <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
      <path d="M22.65 14.39L12 22.13 1.35 14.39a.84.84 0 0 1-.3-.94l1.22-3.78 2.44-7.51A.42.42 0 0 1 4.82 2a.43.43 0 0 1 .58 0 .42.42 0 0 1 .11.18l2.44 7.49h8.1l2.44-7.51A.42.42 0 0 1 18.6 2a.43.43 0 0 1 .58 0 .42.42 0 0 1 .11.18l2.44 7.51L23 13.45a.84.84 0 0 1-.35.94z"/>
    </svg>
    """
    |> raw()
  end

  defp get_platform_icon(_), do: get_platform_icon("github")

  defp get_language_color("JavaScript"), do: "bg-yellow-500"
  defp get_language_color("TypeScript"), do: "bg-blue-500"
  defp get_language_color("Python"), do: "bg-green-500"
  defp get_language_color("Java"), do: "bg-orange-500"
  defp get_language_color("Elixir"), do: "bg-purple-500"
  defp get_language_color(_), do: "bg-gray-500"

  defp format_stars(stars) when stars >= 1000 do
    "#{div(stars, 1000)}k"
  end

  defp format_stars(stars), do: to_string(stars)

  defp format_score(_), do: "0.0"

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error({:validation, msg}), do: msg
  defp format_error({:io, _path, :enoent}), do: "Repository not found"
  defp format_error(:csv_parse_error), do: "Failed to parse analysis results"
  defp format_error(_), do: "Analysis failed. Please check the repository URL."

  defp validate_github_url(""), do: {:error, "Please enter a GitHub repository URL"}

  defp validate_github_url(url) do
    if Regex.match?(~r/^https?:\/\/(www\.)?github\.com\/[\w-]+\/[\w.-]+\/?$/, url) do
      :ok
    else
      {:error, "Please enter a valid GitHub repository URL"}
    end
  end

  defp risk_color("high"), do: "bg-error"
  defp risk_color("medium"), do: "bg-warning"
  defp risk_color(_), do: "bg-success"

  defp risk_badge_class("high"), do: "badge-error"
  defp risk_badge_class("medium"), do: "badge-warning"
  defp risk_badge_class(_), do: "badge-success"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative overflow-hidden rounded-2xl glass-card backdrop-blur-xl p-8">
      <!-- Background decoration -->
      <div class="absolute top-0 right-0 w-64 h-64 bg-gradient-to-br from-primary/10 to-secondary/10 rounded-full filter blur-3xl">
      </div>
      <div class="absolute bottom-0 left-0 w-48 h-48 bg-gradient-to-tr from-secondary/10 to-accent/10 rounded-full filter blur-3xl">
      </div>

      <div class="relative z-10">
        <!-- Input Section -->
        <div class="mb-6">
          <form phx-submit="analyze">
            <div class="flex gap-3">
              <div class="relative flex-grow w-3/4">
                <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 text-base-content/50"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
                    />
                  </svg>
                </div>
                <input
                  type="text"
                  name="url"
                  value={@github_url}
                  phx-change="update_url"
                  phx-focus="show_suggestions"
                  phx-blur="hide_suggestions"
                  placeholder="Enter GitHub repository URL (e.g., github.com/facebook/react)"
                  class="input input-bordered w-full pl-12 glass-card"
                  disabled={@loading}
                  autocomplete="off"
                  autocorrect="off"
                  autocapitalize="off"
                  spellcheck="false"
                />
                
    <!-- Dropdown Suggestions -->
                <%= if @show_suggestions do %>
                  <div class="absolute top-full left-0 right-0 mt-2 glass-card backdrop-blur-md rounded-xl border border-base-content/10 overflow-hidden z-50 dropdown-content shadow-lg">
                    <div class="p-2 border-b border-base-content/10">
                      <div class="text-xs text-base-content/60 flex items-center gap-2">
                        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M13 10V3L4 14h7v7l9-11h-7z"
                          >
                          </path>
                        </svg>
                        Popular repositories
                      </div>
                    </div>
                    <div class="max-h-48 overflow-y-auto">
                      <%= for repo <- @filtered_repos do %>
                        <button
                          type="button"
                          phx-click="select_repo"
                          phx-value-url={repo.url}
                          class="w-full p-3 text-left hover:bg-base-content/10 transition-all duration-200 border-b border-base-content/5 last:border-b-0"
                        >
                          <div class="flex items-center justify-between gap-3">
                            <div class="flex-1 min-w-0">
                              <div class="flex items-center gap-2 mb-1">
                                {get_platform_icon(repo.platform)}
                                <span class="font-medium text-base-content text-sm truncate">
                                  {repo.name}
                                </span>
                                <div class={"w-2 h-2 rounded-full #{get_language_color(repo.language)}"}>
                                </div>
                              </div>
                              <div class="flex items-center gap-3 text-xs text-base-content/60">
                                <div class="flex items-center gap-1">
                                  <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
                                    <path d="M12 .587l3.668 7.568 8.332 1.151-6.064 5.828 1.48 8.279-7.416-3.967-7.417 3.967 1.481-8.279-6.064-5.828 8.332-1.151z" />
                                  </svg>
                                  {format_stars(repo.stars)}
                                </div>
                                <span>{repo.language}</span>
                              </div>
                            </div>
                            <svg
                              class="w-3 h-3 text-base-content/40"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
                              >
                              </path>
                            </svg>
                          </div>
                        </button>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
              <button
                type="submit"
                disabled={@loading || @github_url == ""}
                class="btn btn-primary w-1/4"
              >
                <%= if @loading do %>
                  <span class="loading loading-spinner loading-sm"></span>
                  <span class="hidden sm:inline ml-2">Analyzing</span>
                <% else %>
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
                      d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                    />
                  </svg>
                  <span class="hidden sm:inline ml-2">Analyze</span>
                <% end %>
              </button>
            </div>
          </form>

          <%= if @error do %>
            <div class="text-error text-sm mt-2 flex items-center gap-1">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              {@error}
            </div>
          <% end %>
        </div>
        
    <!-- Results Section -->
        <%= if @results do %>
          <div class="space-y-6 animate-fade-in">
            <!-- Quick Stats -->
            <div class="grid grid-cols-3 gap-4">
              <div class="stat glass-card p-4 text-center rounded-2xl">
                <div class="stat-value text-3xl text-primary">{@results.total_files}</div>
                <div class="stat-desc">Files Analyzed</div>
              </div>
              <div class="stat glass-card p-4 text-center rounded-2xl">
                <div class="stat-value text-3xl text-error">
                  {@results.critical_files + @results.high_risk_files}
                </div>
                <div class="stat-desc">Risk Files</div>
              </div>
              <div class="stat glass-card p-4 text-center rounded-2xl">
                <div class="stat-value text-3xl text-success">{@results.health}%</div>
                <div class="stat-desc">Health Score</div>
              </div>
            </div>
            
    <!-- Top Hotspots Preview -->
            <%= if length(@results.top_hotspots) > 0 do %>
              <div>
                <div class="flex items-center justify-between mb-4">
                  <h4 class="text-lg font-semibold flex items-center gap-2">
                    <span class="text-[var(--hotspot-color)]">🔥</span> Top Hotspots Found
                  </h4>
                  <span class="text-sm text-base-content/50">
                    Showing {length(@results.top_hotspots)} of {@results.hotspots}
                  </span>
                </div>

                <div class="space-y-3">
                  <%= for hotspot <- @results.top_hotspots do %>
                    <div class="flex items-center justify-between p-4 rounded-lg glass-card hover:scale-[1.02] transition-all">
                      <div class="flex items-center gap-3 flex-1 min-w-0">
                        <div class={"w-2 h-2 rounded-full #{risk_color(hotspot.risk)}"}></div>
                        <span class="font-mono text-sm text-primary truncate">{hotspot.file}</span>
                      </div>
                      <div class="flex items-center gap-4">
                        <span class="text-sm text-base-content/50">{hotspot.changes} changes</span>
                        <div class={"badge badge-sm #{risk_badge_class(hotspot.risk)}"}>
                          {hotspot.risk}
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <div class="text-center py-8 text-base-content/50">
                <p>No significant hotspots found in this repository. Great job! 🎉</p>
              </div>
            <% end %>
            
    <!-- Additional Stats -->
            <div class="grid grid-cols-2 gap-4 text-sm">
              <div class="glass-card p-3 text-center">
                <div class="text-base-content/60">Total Revisions</div>
                <div class="font-semibold">{@results.total_revisions}</div>
              </div>
              <div class="glass-card p-3 text-center">
                <div class="text-base-content/60">Avg Complexity</div>
                <div class="font-semibold">{@results.avg_complexity}</div>
              </div>
            </div>
            
    <!-- CTA -->
            <div class="pt-4">
              <button class="btn btn-block btn-outline btn-primary">
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
                    d="M13 10V3L4 14h7v7l9-11h-7z"
                  />
                </svg>
                View Full Analysis Report
              </button>
            </div>
          </div>
        <% else %>
          <!-- Demo prompt when not loading and no results -->
          <div class="text-center py-12 text-base-content/50">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-12 w-12 mx-auto mb-4 opacity-50"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"
              />
            </svg>
            <p class="text-lg mb-2">Try with any GitHub repository URL</p>
            <p class="text-sm">Example: https://github.com/phoenixframework/phoenix</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
