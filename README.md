# FlowRouter

<p align="center">
  <img src="Sources/Resources/icon-active.png" width="128" height="128" alt="FlowRouter Icon">
</p>

**FlowRouter** is the advanced successor to VibeProxy, designed to be the ultimate local AI router for macOS.

It unifies **Managed Providers** (Gemini, Claude, Codex, Qwen, Antigravity, iFlow) with **External API Providers** (OpenRouter, Minimax, Moonshot/Kimi, Grok, Z.ai) into a single local OpenAI-compatible endpoint.

## Features

-   **Universal Routing**: Point any AI client to `http://localhost:8327/v1`.
-   **Hybrid Engine**:
    -   **Managed**: Uses `cli-proxy-api` for OAuth-based zero-key access to major providers.
    -   **External**: Direct proxying to OpenRouter, Minimax, Kimi, Grok, and Z.ai using your own API keys.
-   **Conflict-Free**: Runs on port **8327** (Universal) and **8328** (Internal), allowing it to run alongside VibeProxy (8318).
-   **Native UI**: Beautiful SwiftUI interface with tabs for easy management.
-   **Model Aggregation**: Fetches and lists models from all enabled providers.

## Supported Providers

### Managed (OAuth / No Key)
-   Google Gemini
-   Anthropic Claude
-   OpenAI Codex
-   Alibaba Qwen
-   Antigravity
-   **New:** iFlow

### External (API Key)
-   **OpenRouter**: Access 100+ models.
-   **Minimax**: `MiniMax-M2` and more.
-   **Moonshot AI (Kimi)**: `kimi-k2` series.
-   **xAI Grok**: `grok-4` series.
-   **Z.ai**: `glm-4` and more.

## Installation

1.  Clone the repo.
2.  Run `swift build -c release`.
3.  Run `.build/release/FlowRouter`.

## Configuration

Access the Settings window from the menu bar icon.
-   **General**: Start/Stop server, view logs.
-   **Managed**: Connect your accounts.
-   **External**: Toggle providers and enter API keys.

## Usage in Clients

-   **Base URL**: `http://localhost:8327/v1`
-   **API Key**: `sk-dummy` (or any string)

FlowRouter will automatically route requests based on the `model` name.

## Development

Built with Swift and SwiftUI. Uses `cli-proxy-api` for managed services.

License: MIT