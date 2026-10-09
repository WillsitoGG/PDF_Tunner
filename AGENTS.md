# AGENTS.md

This file provides guidance to AI Agents when working with code in this repository.

## Taskfile (Recommended)

This project uses [Task](https://taskfile.dev/) as a unified command runner. All build, dev, test, lint, and docker commands can be run from the repo root via `task <command>`. Run `task --list` to see all available commands.

Task `desc:` fields should describe **what** the task does, not **how** it does it. Keep them generic and stable: don't reference implementation details like aliases, internal helpers, mode flags, or which other task delegates to which. The description is for users picking a command from `task --list`, not a changelog of refactors.

### Quick Reference
- `task install` — install all dependencies
- `task dev` — start backend + frontend concurrently
- `task dev:all` — start backend + frontend + engine concurrently
- `task build` — build all components
- `task test` — run all tests (backend + frontend + engine)
- `task lint` — run all linters
- `task format` — auto-fix formatting across all components
- `task check` — full quality gate (lint + typecheck + test)
- `task clean` — clean all build artifacts
- `task docker:build` — build standard Docker image
- `task docker:up` — start Docker compose stack

## Comments

A comment must carry information the code cannot. If a reader could derive it from the code in front of them, delete it.

Comment the current state. Not what the code used to do, not what changed, not why it changed: git holds that. Where history explains the shape, state the reason instead, so "this used to reimplement the modal internals" becomes "thin wrapper over the shared Modal: duplicating its portal and focus trap is how dialogs drift apart". Future state goes in a TODO with an issue.

Write a comment when it does one of these four jobs:

- **Contract.** What a caller must know that the signature cannot say: preconditions, invariants, units, ownership and lifetime, thread-safety, error semantics, side effects. Document the contract of everything a caller outside the file can reach, and nothing else. Goes on the type/method/module as Javadoc, JSDoc, or a docstring.
- **Why.** The constraint the code satisfies, the bug it avoids, the alternative rejected and the reason.
- **Hazard.** "Must stay in sync with X", "order matters because Y", "do not remove, it prevents Z".
- **Map.** A short orientation at the top of a genuinely complex file: what it owns, and what it deliberately does not.

Never write:

- A comment that restates the next line. `// Handle drag start` above `handleDragStart` is noise.
- Section banners or position markers: `// --- Types ---`, `// Helpers`, `// =====`.
- Step narration in a function body (`// Step 1:`, `// Then we`). If the steps need labels they need names: extract functions. Numbering a genuinely numbered thing, like a wizard step, is fine.
- Commented-out code. Delete it.
- Doc tags that restate the signature. `@param blob - The blob` says nothing; omit the tag rather than pad it.
- Docs on self-explanatory members with no constraint to state.

Two tests before keeping a comment:

- **Delete it.** Is any information lost? If not, it stays deleted.
- **Could a name carry it instead?** A better identifier, an extracted function, or a named constant beats a comment. Prefer the code change.

A comment at the end of a line usually decodes that line, and that is worth keeping: `{0x25, 0x50} // "%PDF"`, `50L * 1024 * 1024 // 50 MB`. The rules that compare a comment against the code below it do not apply there, but a trailing TODO or a trailing bit of history is judged like any other.

A reference is supplementary, never load-bearing: the comment must survive deleting it. `// See #1234` is a dead end; `// saving first loses every annotation (#6865)` is not. Prefer a spec (`RFC 3161`) or CVE where one applies.

A TODO needs an issue, not an owner: `// TODO(#1234): re-enable the gate once account syncing lands`. If it is not worth an issue, it is not worth a TODO. A question is not a TODO.

A comment block over ~12 lines outside a file or type header usually means the code needs restructuring, or that the prose is product documentation and belongs in the docs repo.

`task comment-lint` checks the mechanical part of this on the lines you add, and runs inside `task pre-commit`. Reasoning, worked examples and the linter's own rules: @devGuide/CODE_COMMENTS.md

## Common Development Commands

### Build and Test
- **Build project**: `task build`
- **Run backend locally**: `task backend:dev`
- **Run all tests**: `task test` (or individually: `task backend:test`, `task frontend:test`, `task engine:test`)
- **Docker integration tests**: `./test.sh` (builds all Docker variants and runs comprehensive tests)
- **Code formatting**: `task format` (or `task backend:format` for Java only)
- **Full quality gate**: `task check` (runs lint + typecheck + test across all components)

After modifying any files in the project, you must run the relevant `task check` command that covers that area of the code. For example, when editing frontend files run `task frontend:check`; for Python engine files run `task engine:check`; for Java backend files run `task backend:check`.

### Docker Development
- **Build standard**: `task docker:build` (or `docker build -t stirling-pdf -f docker/embedded/Dockerfile .`)
- **Build fat version**: `task docker:build:fat`
- **Build ultra-lite**: `task docker:build:ultra-lite`
- **Start compose stack**: `task docker:up` (or `task docker:up:fat`, `task docker:up:ultra-lite`)
- **Stop compose stack**: `task docker:down`
- **View logs**: `task docker:logs`
- **Example compose files**: Located in `exampleYmlFiles/` directory

### Security Mode Development
Set `DOCKER_ENABLE_SECURITY=true` environment variable to enable security features during development. This is required for testing the full version locally.

### Python Development (AI Engine)

The engine is a Python reasoning service for Stirling: it plans and interprets work, but it does not own durable state, and it does not execute Stirling PDF operations directly. Keep the service narrow: typed contracts in, typed contracts out, with AI only where it adds reasoning value. The frontend calls the Python engine via Java as a proxy.

#### Python Commands
All engine commands run from the repo root using Task:
- `task engine:check` — run all checks (typecheck + lint + format-check + test)
- `task engine:fix` — auto-fix lint + formatting
- `task engine:install` — install Python dependencies via uv
- `task engine:dev` — start FastAPI with hot reload (localhost:5001)
- `task engine:test` — run pytest
- `task engine:lint` — run ruff linting
- `task engine:typecheck` — run pyright
- `task engine:format` — format code with ruff
- `task engine:tool-models` — generate `tool_models.py` from the Java OpenAPI spec

The project structure is defined in `engine/pyproject.toml`. Any new dependencies should be listed there, followed by running `task engine:install`.

#### Python Code Style
- Keep `task engine:check` passing.
- Use modern Python when it improves clarity.
- Prefer explicit names to cleverness.
- Avoid nested functions and nested classes unless the language construct requires them.
- Prefer composition to inheritance when combining concepts.
- Avoid speculative abstractions. Add a layer only when it removes real duplication or clarifies lifecycle.
- Comments follow the repo-wide rules in the "Comments" section above.

#### Python Typing and Models
- Deserialize into Pydantic models as early as possible.
- Serialize from Pydantic models as late as possible.
- Do not pass raw `dict[str, Any]` or `dict[str, object]` across important boundaries when a typed model can exist instead.
- Avoid `Any` wherever possible.
- Avoid `cast()` wherever possible (reconsider the structure first).
- All shared models should subclass `stirling.models.ApiModel` so the service behaves consistently.
- Do not use string literals for any type annotations, including `cast()`.

#### Python Configuration
- Keep application-owned configuration in `stirling.config`.
- Only add `STIRLING_*` environment variables that the engine itself truly owns.
- Do not mirror third-party provider environment variables unless the engine is actually interpreting them.
- Let `pydantic-ai` own provider authentication configuration when possible.

#### Python Architecture

**Package roles:**
- `stirling.contracts`: request/response models and shared typed workflow contracts. If a shape crosses a module or service boundary, it probably belongs here.
- `stirling.models`: shared model primitives and generated tool models.
- `stirling.agents`: reasoning modules for individual capabilities.
- `stirling.api`: HTTP layer, dependency access, and app startup wiring.
- `stirling.services`: shared runtime and non-AI infrastructure.
- `stirling.config`: application-owned settings.

**Source of truth:**
- `stirling.models.tool_models` is the source of truth for operation IDs and parameter models.
- Do not duplicate operation lists if they can be derived from `tool_models.OPERATIONS`.
- Do not hand-maintain parallel parameter schemas when the generated tool models already define them.
- If a tool ID must match a parameter model, validate that relationship explicitly in code.

**Boundaries:**
- Keep the API layer thin. Route modules should bind requests, resolve dependencies, and call agents or services. They should not contain business logic.
- Keep agents focused on one reasoning domain. They should not own FastAPI routing, persistence, or execution of Stirling operations.
- Build long-lived runtime objects centrally at startup when possible rather than reconstructing heavy AI objects per request.
- If an agent delegates to another agent, the delegated agent should remain the source of truth for its own domain output.

#### Python AI Usage
- The system must work with any AI, including self-hosted models. We require that the models support structured outputs, but should minimise model-specific code beyond that.
- Use AI for reasoning-heavy outputs, not deterministic glue.
- Do not ask the model to invent data that Python can derive safely.
- Do not fabricate fallback user-facing copy in code to hide incomplete model output.
- AI output schemas should be impossible to instantiate incorrectly.
  - Do not require the model to keep separate structures in sync. For example, instead of generating two lists which must be the same length, generate one list of a model containing the same data.
  - Prefer Python to derive deterministic follow-up structure from a valid AI result.
- Use `NativeOutput(...)` for structured model outputs.
- Use `ToolOutput(...)` when the model should select and call delegate functions.

#### Python Testing
- Test contracts directly.
- Test agents directly where behaviour matters.
- Test API routes as thin integration points.
- Prefer dependency overrides or startup-state seams to monkeypatching random globals.

### Frontend Development
- **Frontend dev server**: `task frontend:dev` — requires backend on localhost:8080
- **Tech Stack**: Vite + React + TypeScript + Mantine UI + TailwindCSS
- **Proxy Configuration**: Vite proxies `/api/*` calls to backend (localhost:8080)
- **Build Process**: DO NOT run build scripts manually - builds are handled by CI/CD pipelines
- **Package Installation**: `task frontend:install`
- **Deployment Options**:
  - **Desktop App**: `task desktop:build`
  - **Web Server**: `task frontend:build` then serve dist/ folder
  - **Development**: `task desktop:dev` for desktop dev mode

#### Environment Variables
- All `VITE_*` variables must be declared in the appropriate committed env file:
  - `frontend/editor/.env` — core and shared vars (base, loaded in every mode)
  - `frontend/editor/.env.proprietary` — proprietary-only vars, e.g. the admin portal's SaaS/account-link keys (layered on top of `.env` in proprietary mode)
  - `frontend/editor/.env.saas` — SaaS-only vars (layered on top of `.env` in SaaS mode)
  - `frontend/editor/.env.desktop` — desktop (Tauri)-only vars (layered on top of `.env` in desktop mode)
- These files are committed to Git and must not contain private keys
- Local overrides (API keys, machine-specific settings) go in uncommitted sibling `.env.local` / `.env.saas.local` / `.env.desktop.local` files — Vite automatically layers them on top
- Never use `|| 'hardcoded-fallback'` inline — put defaults in the committed env files
- `task frontend:prepare` creates empty `.local` override files on first run; pass `MODE=saas` or `MODE=desktop` to also create the mode-specific `.local` file
- Prepare runs automatically as a dependency of all `dev*`, `build*`, and `desktop*` tasks
- See `frontend/README.md#environment-variables` for full documentation

#### Import Paths - CRITICAL
**ALWAYS use `@app/*` for imports.** Do not use `@core/*` or `@proprietary/*` unless explicitly wrapping/extending a lower layer implementation.

For a broader explanation of the frontend layering and override architecture, read @frontend/editor/DeveloperGuide.md

Before touching colours or theming (tokens, dark mode, accent colours), read @frontend/editor/src/core/theme/README.md — it explains the palette/`--c-*` token system and the rule that literal colours live only in `primitives.css`.

Before adding or styling an icon, read @frontend/editor/src/core/icons/README.md — `<Icon name="…" />` comes from `@app/ui/Icon`, icon sources live as `.svg` files in `core/icons/svg/`, and inline `<svg>` in TS/TSX is linted out.

```typescript
// ✅ CORRECT - Use @app/* for all imports
import { AppLayout } from "@app/components/AppLayout";
import { useFileContext } from "@app/contexts/FileContext";
import { FileContext } from "@app/contexts/FileContext";

// ❌ WRONG - Do not use @core/* or @proprietary/* in normal code
import { AppLayout } from "@core/components/AppLayout";
import { useFileContext } from "@proprietary/contexts/FileContext";
```

**Only use explicit aliases when:**
- Building layer-specific override that wraps a lower layer's component
- Example: `import { AppProviders as CoreAppProviders } from "@core/components/AppProviders"` when creating proprietary/AppProviders.tsx that extends the core version

The `@app/*` alias automatically resolves to the correct layer based on build target (core/proprietary/saas/desktop/cloud) and handles the fallback cascade — see "Frontend `cloud/` Layer" below for the full per-flavor order.

#### Frontend `cloud/` Layer

`@app/*` resolves through a per-flavor cascade — first existing file wins (shadow/override):

- **core** → core
- **proprietary** → proprietary → core
- **saas** → saas → cloud → proprietary → core
- **desktop** → desktop → cloud → proprietary → core
- **cloud** → cloud → proprietary → core

What goes where:

- **core** — OSS base.
- **proprietary** — licensed / offline features.
- **cloud** — the SHARED hosted/SaaS experience used by BOTH saas + desktop: PAYG, wallet, plan, billing, usage meters, cloud config/team/onboarding.
- **saas** — web-only: Supabase web auth, AuthCallback, avatar canvas, `window.location`.
- **desktop** — Tauri-only: keyring authService, tauriHttpClient, native files/windows, backend routing.

`cloud/` MUST NOT import `@supabase/*`, `@tauri-apps/*`, raw `fetch`, `window.location`, `localStorage`, `sessionStorage`, or `import.meta.env.VITE_*` (all enforced by the linter). It reaches platform-specific things only via `@app/*` seams: `services/apiClient`, `auth/session.getAccessToken`, `auth/supabase`, `platform/openExternal`, `services/billing`, `hooks/useSaaSMode` — each provided per-platform in `saas/` and `desktop/`.

Rule of thumb — **move, don't copy**: share via `cloud/`, override by shadowing the same `@app/*` path in a leaf (`saas/` or `desktop/`).

**Cloud feature flags on desktop.** The local `AppConfigContext` reads `/api/v1/config/app-config` from the LOCAL bundled backend, so cloud-only flags (`aiEngineEnabled`, `premiumEnabled`, …) are never seen on desktop. To read the cloud's view, use `useSaasAppConfig()` (`desktop/hooks/useSaasAppConfig.ts`, backed by the general `saasAppConfigService` — SaaS-mode-only, public endpoint, native HTTP, 5-min cache). It returns `null` outside SaaS mode, so cloud features stay off in local mode and the server keeps the on/off switch (no desktop release needed to flip a flag). In self-hosted mode the connected server's own `AppConfigContext` is the authority instead. Gate a feature behind a per-platform seam - e.g. `useAiEngineEnabled()` (core reads `useAppConfig()`, desktop reads `useAppConfig()` when signed in to a self-hosted server and `useSaasAppConfig()` otherwise) - rather than hardcoding the flag on.

#### Component Override Pattern (Stub/Shadow)
Use this pattern for desktop-specific or proprietary-specific features WITHOUT runtime checks or conditionals.

**How it works:**
1. Core defines stub component (returns null or no-op)
2. Desktop/proprietary overrides with same path/name
3. Core imports via `@app/*` - higher layer "shadows" core in those builds
4. No `@ts-ignore`, no `isTauri()` checks, no runtime conditionals!

**Example - Desktop-specific footer:**

```typescript
// core/components/workbenchBar/WorkbenchBarFooterExtensions.tsx (stub)
interface WorkbenchBarFooterExtensionsProps {
  className?: string;
}

export function WorkbenchBarFooterExtensions(_props: WorkbenchBarFooterExtensionsProps) {
  return null; // Stub - does nothing in web builds
}
```

```tsx
// desktop/components/workbenchBar/WorkbenchBarFooterExtensions.tsx (real implementation)
import { Box } from '@mantine/core';
import { BackendHealthIndicator } from '@app/components/BackendHealthIndicator';

interface WorkbenchBarFooterExtensionsProps {
  className?: string;
}

export function WorkbenchBarFooterExtensions({ className }: WorkbenchBarFooterExtensionsProps) {
  return (
    <Box className={className}>
      <BackendHealthIndicator />
    </Box>
  );
}
```

```tsx
// core/components/shared/WorkbenchBar.tsx (usage - works in ALL builds)
import { WorkbenchBarFooterExtensions } from '@app/components/workbenchBar/WorkbenchBarFooterExtensions';

export function WorkbenchBar() {
  return (
    <div>
      {/* In web builds: renders nothing (stub returns null) */}
      {/* In desktop builds: renders BackendHealthIndicator */}
      <WorkbenchBarFooterExtensions className="workbench-bar-footer" />
    </div>
  );
}
```

**Build resolution:**
- **Core build**: `@app/*` → `core/*` → Gets stub (returns null)
- **Desktop build**: `@app/*` → `desktop/*` → Gets real implementation (shadows core)

**Benefits:**
- No runtime checks or feature flags
- Type-safe across all builds
- Clean, readable code
- Build-time optimization (dead code elimination)

#### Multi-Tool Workflow Architecture
Frontend designed for **stateful document processing**:
- Users upload PDFs once, then chain tools (split → merge → compress → view)
- File state and processing results persist across tool switches
- No file reloading between tools - performance critical for large PDFs (up to 100GB+)

#### FileContext - Central State Management
**Location**: `frontend/editor/src/core/contexts/FileContext.tsx`
- **Active files**: Currently loaded PDFs and their variants
- **Tool navigation**: Current mode (viewer/pageEditor/fileEditor/toolName)
- **Memory management**: PDF document cleanup, blob URL lifecycle, Web Worker management
- **IndexedDB persistence**: File storage with thumbnail caching
- **Preview system**: Tools can preview results (e.g., Split → Viewer → back to Split) without context pollution

**Critical**: All file operations go through FileContext. Don't bypass with direct file handling.

#### Processing Services
- **enhancedPDFProcessingService**: Background PDF parsing and manipulation
- **thumbnailGenerationService**: Web Worker-based with main-thread fallback
- **fileStorage**: IndexedDB with LRU cache management

#### Memory Management Strategy
**Why manual cleanup exists**: Large PDFs (up to 100GB+) through multiple tools accumulate:
- PDF.js documents that need explicit .destroy() calls
- Blob URLs from tool outputs that need revocation
- Web Workers that need termination
Without cleanup: browser crashes with memory leaks.

#### Tool Development

**Architecture**: Modular hook-based system with clear separation of concerns:

- **useToolOperation** (`frontend/editor/src/core/hooks/tools/shared/useToolOperation.ts`): Main orchestrator hook
  - Coordinates all tool operations with consistent interface
  - Integrates with FileContext for operation tracking
  - Handles validation, error handling, and UI state management

- **Supporting Hooks**:
  - **useToolState**: UI state management (loading, progress, error, files)
  - **useToolApiCalls**: HTTP requests and file processing
  - **useToolResources**: Blob URLs, thumbnails, ZIP downloads

- **Utilities**:
  - **toolErrorHandler**: Standardized error extraction and i18n support
  - **toolResponseProcessor**: API response handling (single/zip/custom)
  - **toolOperationTracker**: FileContext integration utilities

**Three Tool Patterns**:

**Pattern 1: Single-File Tools** (Individual processing)
- Backend processes one file per API call
- Set `multiFileEndpoint: false`
- Examples: Compress, Rotate
```typescript
return useToolOperation({
  operationType: 'compress',
  endpoint: '/api/v1/misc/compress-pdf',
  buildFormData: (params, file: File) => { /* single file */ },
  multiFileEndpoint: false,
});
```

**Pattern 2: Multi-File Tools** (Batch processing)
- Backend accepts `MultipartFile[]` arrays in single API call
- Set `multiFileEndpoint: true`
- Examples: Split, Merge, Overlay
```typescript
return useToolOperation({
  operationType: 'split',
  endpoint: '/api/v1/general/split-pages',
  buildFormData: (params, files: File[]) => { /* all files */ },
  multiFileEndpoint: true,
  filePrefix: 'split_',
});
```

**Pattern 3: Complex Tools** (Custom processing)
- Tools with complex routing logic or non-standard processing
- Provide `customProcessor` for full control
- Examples: Convert, OCR
```typescript
return useToolOperation({
  operationType: 'convert',
  customProcessor: async (params, files) => { /* custom logic */ },
});
```

**Benefits**:
- **No Timeouts**: Operations run until completion (supports 100GB+ files)
- **Consistent**: All tools follow same pattern and interface
- **Maintainable**: Single responsibility hooks, easy to test and modify
- **i18n Ready**: Built-in internationalization support
- **Type Safe**: Full TypeScript support with generic interfaces
- **Memory Safe**: Automatic resource cleanup and blob URL management

## Architecture Overview

### Project Structure
- **Backend**: Spring Boot application
- **Frontend**: React-based SPA in `/frontend` directory
  - **File Storage**: IndexedDB for client-side file persistence and thumbnails
  - **Internationalization**: JSON-based translations (converted from backend .properties)
- **PDF Processing**: PDFBox for core PDF operations, LibreOffice for conversions, PDF.js for client-side rendering
- **Security**: Spring Security with optional authentication (controlled by `DOCKER_ENABLE_SECURITY`)
- **Configuration**: YAML-based configuration with environment variable overrides

### Controller Architecture
- **API Controllers** (`src/main/java/.../controller/api/`): REST endpoints for PDF operations
  - Organized by function: converters, security, misc, pipeline
  - Follow pattern: `@RestController` + `@RequestMapping("/api/v1/...")`

### Key Components
- **SPDFApplication.java**: Main application class with desktop UI and browser launching logic
- **ConfigInitializer**: Handles runtime configuration and settings files
- **Pipeline System**: Automated PDF processing workflows via `PipelineController`
- **Security Layer**: Authentication, authorization, and user management (when enabled)

### Frontend Directory Structure
The frontend is organized with a clear separation of concerns:

- **`frontend/editor/src/core/`**: Main application code (shared, production-ready components)
  - **`core/components/`**: React components organized by feature
    - `core/components/tools/`: Individual PDF tool implementations
    - `core/components/viewer/`: PDF viewer components
    - `core/components/pageEditor/`: Page manipulation UI
    - `core/components/tooltips/`: Help tooltips for tools
    - `core/components/shared/`: Reusable UI components
  - **`core/contexts/`**: React Context providers
    - `FileContext.tsx`: Central file state management
    - `file/`: File reducer and selectors
    - `toolWorkflow/`: Tool workflow state
  - **`core/hooks/`**: Custom React hooks
    - `hooks/tools/`: Tool-specific operation hooks (one directory per tool)
    - `hooks/tools/shared/`: Shared hook utilities (useToolOperation, etc.)
  - **`core/constants/`**: Application constants and configuration
  - **`core/data/`**: Static data (tool taxonomy, etc.)
  - **`core/services/`**: Business logic services (PDF processing, storage, etc.)

- **`frontend/editor/src/desktop/`**: Desktop-specific (Tauri) code
- **`frontend/editor/src/proprietary/`**: Proprietary/licensed features
- **`frontend/editor/src-tauri/`**: Tauri (Rust) native desktop application code
- **`frontend/editor/public/`**: Static assets served directly
  - `public/locales/`: Translation JSON files

### Component Architecture
- **Static Assets**: CSS, JS, and resources in `src/main/resources/static/` (legacy) + `frontend/editor/public/` (modern)
- **Internationalization**:
  - Backend: `messages_*.properties` files
  - Frontend: JSON files in `frontend/editor/public/locales/` (converted from .properties)
  - Conversion Script: `scripts/convert_properties_to_json.py`

### Configuration Modes
- **Ultra-lite**: Basic PDF operations only
- **Standard**: Full feature set
- **Fat**: Pre-downloaded dependencies for air-gapped environments
- **Security Mode**: Adds authentication, user management, and enterprise features

### Testing Strategy
- **Integration Tests**: Cucumber tests in `testing/cucumber/`
- **Docker Testing**: `test.sh` validates all Docker variants
- **Manual Testing**: No unit tests currently - relies on UI and API testing

## Development Workflow

1. **Local Development** (using Taskfile):
   - Backend + frontend: `task dev`
   - All services (including AI engine): `task dev:all`
   - Or individually: `task backend:dev` (localhost:8080), `task frontend:dev` (localhost:5173), `task engine:dev` (localhost:5001)
2. **Quality Gate**: Run `task check` before submitting PRs
3. **Docker Testing**: Use `./test.sh` for full Docker integration tests
4. **Code Style**: Spotless enforces Google Java Format automatically (`task backend:format`)
5. **Translations**:
   - Backend: Use helper scripts in `/scripts` for multi-language updates
   - Frontend: Update JSON files in `frontend/editor/public/locales/` or use conversion script
6. **Documentation**: API docs auto-generated and available at `/swagger-ui/index.html`

## Frontend Architecture Status

- **Core Status**: React SPA architecture complete with multi-tool workflow support
- **State Management**: FileContext handles all file operations and tool navigation
- **File Processing**: Production-ready with memory management for large PDF workflows (up to 100GB+)
- **Tool Integration**: Modular hook architecture with `useToolOperation` orchestrator
  - Individual hooks: `useToolState`, `useToolApiCalls`, `useToolResources`
  - Utilities: `toolErrorHandler`, `toolResponseProcessor`, `toolOperationTracker`
  - Pattern: Each tool creates focused operation hook, UI consumes state/actions
- **Preview System**: Tool results can be previewed without polluting file context (Split tool example)
- **Performance**: Web Worker thumbnails, IndexedDB persistence, background processing

## Translation Rules

- **CRITICAL**: Always update translations in `en-US` only - all other languages (including `en-GB`) are handled separately
- Translation files are located in `frontend/editor/public/locales/`
- After changing any translation file, run `task pre-commit:fix`

## Important Notes

- **Java Version**: Requires JDK 25.
- **Lombok**: Used extensively - ensure IDE plugin is installed
- **File Persistence**:
  - **Backend**: Designed to be stateless - files are processed in memory/temp locations only
  - **Frontend**: Uses IndexedDB for client-side file storage and caching (with thumbnails)
- **Security**: When `DOCKER_ENABLE_SECURITY=false`, security-related classes are excluded from compilation
- **Import Paths**: ALWAYS use `@app/*` for imports - never use `@core/*` or `@proprietary/*` unless explicitly wrapping/extending a lower layer
- **FileContext**: All file operations MUST go through FileContext - never bypass with direct File handling
- **Memory Management**: Manual cleanup required for PDF.js documents and blob URLs - don't remove cleanup code
- **Tool Development**: New tools should follow `useToolOperation` hook pattern (see `useCompressOperation.ts`)
- **Performance Target**: Must handle PDFs up to 100GB+ without browser crashes
- **Preview System**: Tools can preview results without polluting main file context (see Split tool implementation)
- **Adding Tools**: See `ADDING_TOOLS.md` for complete guide to creating new PDF tools

## Communication Style
- Be direct and to the point
- No apologies or conversational filler
- Answer questions directly without preamble
- Explain reasoning concisely when asked
- Avoid unnecessary elaboration

## Decision Making
- Ask clarifying questions before making assumptions
- Stop and ask when uncertain about project-specific details
- Confirm approach before making structural changes
- Request guidance on preferences (cross-platform vs specific tools, etc.)
- Verify understanding of requirements before proceeding


## Stack reality check (don't trust LLM training data) <!-- bleeding-edge-stack-note -->

This codebase is on bleeding-edge versions of its core JVM stack: **Spring Boot 4.1.1**,
**Jackson 3 (`tools.jackson`)**, **JDK 21/25 source/target with JDK 25 toolchain**.
All three are *post*-2024 releases and your training corpus is overwhelmingly Spring Boot 2/3 and
Jackson 2 patterns — those patterns will compile, run differently, or hallucinate APIs that no
longer exist.

Before writing or editing Spring / Jackson / JDK code:

1. Open an existing module in `app/core/` or `app/common/` and grep for the actual imports being
   used — `import tools.jackson...` not `import com.fasterxml.jackson...`, and the new
   `org.springframework.boot` 4.x package layout.
2. If you're not sure whether an API exists in this stack version, **check the source on disk
   first** (the dependency JARs are downloaded under `~/.gradle/caches/modules-2/`).
3. Do not silently downgrade a Spring Boot 4 pattern to a Spring Boot 3 equivalent. If something
   doesn't work, surface it to the human — don't guess.

Same goes for Jackson 3's API surface (renamed `ObjectMapper` builder methods, new
`tools.jackson.databind` namespace) and JDK 25 preview features. Ground your code in this repo's
actual imports, not what worked three years ago.

## PDF_Tunner v3.1.0 — Portable migration A1 (NOT BUILT)

**Exact upstream source:** Stirling-PDF v3.1.0 tag `b99fa929e365760c863956bf23c127b098c288e5`. This integration branch descends directly from the upstream commit, not a guessed version bump. Its sibling branch `pdf-tunner/upstream-v3.1.0-base` preserves the unmodified official tree.

**Previous working reference:** `pdf-tunner/windows-portable-v1`, last passing Windows CI Run #134, build source `1a61b6412414dc3b6b1d2ae007b5cef5477c08fa`. Do not alter this validated branch or main while v3 migration is incomplete.

**Migrated now (source-side only):** Windows 10/11 portable marker bootstrap, package-first pinned dependency path setup, fixed WebView2 bootstrap, portable app-data/provisioning path mapping, branded Tauri overlay, native `is_pdf_tunner_portable` flag for frontend, disable system deep-link registration in portable, and adapt Java loopback/temp/HotSpot flags to the new v3.1 backend while preserving its new shutdown-file handling. Upstream Rust Cargo feature set is preserved with one additional Windows file-storage feature used by the imported bootstrap.

**Not migrated / not validated:** portable window-state/log plugin storage, frontend account/mobile/branding policy, converter packaging scripts and CI workflow, new v3.1 Java/React test compatibility, UI/ProcMon tests, full Windows ZIP. The current branch MUST NOT be distributed as PDF_Tunner.

**Next gates:** port native window-state and log isolation against v3.1 lifecycle, then adapt package pipeline and frontend/backend local-only constraints. Run cheap native/frontend/Java checks before one expensive Windows packaged CI. Keep all non-Enterprise PDF features except explicitly requested mobile upload, login/cloud/account and admin navigation. Keep legal attribution intact. Document every code change in README and AGENTS and do not publish a Release or edit main.

### v3.1.0 migration slice A2 — isolate native window state/logs (unverified code)

Port the previously accepted package-local window-state cache into the upstream v3.1 Tauri plugin lifecycle. For marked portable runs write geometry under `data/tauri/window-state` and Tauri logs under `data/logs/tauri`, not the host profile. Preserve the upstream new main-window creation, watcher shutdown, Java shutdown-file path and default native plugin outside portable mode. On CloseRequested capture window geometry before destruction; on ExitRequested persist it before backend cleanup and native exit. Source-only integration commit; no Rust compilation, GUI or Windows 10 VM validation yet. Remaining: adapt full converter/packaging CI, local-only frontend/backend policy and approved branding.

### Cheap v3.1.0 migration validation (source-level; workflow branch only)

Added an isolated branch-specific lightweight workflow `pdf-tunner-v3-migration-preflight.yml` and executable Python checks `validate-v3-migration.py`. It parses all changed Rust portable sources with rustfmt, verifies pinned upstream 3.1.0 Tauri base metadata, portable overlay identity, native mode detection, local Java shutdown/TEMP/loopback, WebView2 location and window-state/log isolation wiring. It does not download or build LibreOffice/Java/OCR, perform native linking or GUI tests, or retain large binaries. This temporary migration workflow is scoped exclusively to the v3 integration branch (concurrency cancels obsolete runs) and must be reviewed/removed on final cleanup. A green source preflight is only a preparatory milestone; the product is not buildable/accepted until later gates pass.

### v3.1.0 migration slice A3 — stage verified former portable toolchain scripts (NOT YET RETESTED)

Added the previously validated v2.14.3 Windows portable dependency preparation/verification scripts as byte-identical source Git blobs, without rewriting download URLs, security pins or provenance. This includes qpdf, Poppler, LibreOffice, Calibre, ImageMagick, Ghostscript, Tesseract, OCRmyPDF/Python, conversion fonts, WeasyPrint, WebView2 and auxiliary image/OCR/ebook/CBR toolchains. Retained the four purpose-built launchers in scripts. These are now migration INPUTS, not an approved v3.1 package. The full Windows CI workflow was intentionally not imported because it pins old upstream 2.14.3 and old Java/frontend output paths; it must be reconciled to v3.1 before being enabled. No 1.9GB portable build or new Release. Do not treat old converter tests as v3 runtime acceptance until verified against v3.1 endpoints/dependency usage.

**Next:** reconcile actual upstream v3.1 backend Jar build and frontend packaging; adapt the strict Windows CI with identical SHA pins and all original functional gates; then update the branding scripts for the user-supplied blue mark. Run targeted tests first. No changes to the stable old branch or main.

### v3.1.0 migration slice A4 — restore pinned Windows acceptance inputs (source-only)

Nine missing v2.14.3 support inputs are staged from the last passing `pdf-tunner/windows-portable-v1` tree as the original Git blobs: two Python dependency locks (`ocrmypdf-py312-windows-x64.lock.txt`, `opencv-py312-windows-x64.lock.txt`) and the Windows host-boundary audit, startup diagnostics, previous branding preparation/validation, CI-status helper, RAR probe and window-state verification. These files complement A3 and are **migration inputs only, not validated v3.1.0 runtime tools**. The former Windows workflow is deliberately not active or imported wholesale: it pins Stirling 2.14.3 and must be reconciled to the v3.1.0 build and frontend layout. The previous branding script is only a reference until the approved blue identity is applied.

The lightweight source gate checks the staged inputs plus the official v3.1.0/JDK 25 desktop JLink/JAR task contracts; it does not download external runtimes or claim executable functionality. Keep `main` and the v2 branch untouched, do not launch a large build prematurely, and publish no Release without authorization.

**Next:** port the full Windows CI/packaging workflow to v3.1.0, retaining exact dependency SHA pins and the backend, OCR, LibreOffice, frontend, lifecycle, GUI, host-boundary, ZIP and SHA-256 gates; run cheap compatibility checks before one controlled Windows build.

### v3.1.0 migration slice A5 — block official auto-update in marked portable Windows mode (source-only)

Adapted three existing v3.1 React/TypeScript files (without replacing the upstream components): the desktop startup update popup, the shared upstream release/update service, and desktop Preferences. They now call the existing native `is_pdf_tunner_portable` command and, for package-marked portable runs, avoid fetching Stirling updater metadata, displaying update controls, and probing the Tauri updater. Detection failure is handled conservatively (no external update), while non-portable upstream behavior is preserved. The branch preflight now checks these contracts for regressions. This is source integration **only**, not a TypeScript build, live network test, or acceptance of the frontend branding/account UI.

**Next:** independently verify the new frontend component tree (onboarding/sign-in/cloud/wallet and branding) against the approved local-only policy, then reconcile full Windows v3.1 CI and packaging with pinned dependencies. Do not publish or change `main`.

### v3.1.0 migration slice A6 — isolated upstream desktop TypeScript acceptance gate

The branch-specific `pdf-tunner-v3-migration-preflight.yml` now also installs the v3.1.0 frontend from its existing `frontend/package-lock.json` and invokes the upstream desktop typecheck command (`npx tsc --noEmit --project editor/src/desktop/tsconfig.json`) on a clean Ubuntu runner using Node 22. This separate job checks TypeScript integration without compiling or uploading a Windows ZIP. The earlier source preflight remains separate for rapid diagnosis. A green typecheck does **not** prove Tauri/Rust linking, backend runtime behavior, branding completeness, or Windows portability. Preserve all full Windows acceptance gates for the later packaging workflow.

### v3.1.0 migration slice A7 — preserve account-free native portable onboarding

Adapted the new v3.1 DesktopOnboardingModal and ConnectionSettings without replacing their upstream components. For native marker-selected PDF_Tunner, no sign-in/welcome/classification modal is mounted, and Settings does not show the local-mode account sign-in button. Until the native mode flag is known, these controls remain hidden; outside portable mode the upstream UI is unchanged. Source guards run in the preflight and the separate upstream desktop TypeScript gate verifies that the React code typechecks. **Remaining:** review other account/cloud/mobile/admin entry points and conditional feature routes; verify behavior in a running Windows GUI. Never infer that the whole v3 frontend is account-free from these two safeguards.

### v3.1.0 migration slice A8 — real Windows native Rust compilation probe

Added an isolated branch-only `pdf-tunner-v3-windows-compile.yml` workflow. It invokes `cargo check --locked` on a fresh `windows-latest` runner to detect real Rust/Windows type, feature and Tauri integration problems that `rustfmt` cannot find. It preserves the exact upstream v3.1.0 commit ancestry, downloads no PDF conversion runtime packages, and publishes no binaries or large artifacts. It runs automatically only when its workflow file changes, otherwise only by deliberate manual dispatch; do not turn it into a repeated trigger for unrelated commits. **Not equivalent to:** Windows executable build, backend JAR/JLink build, full ZIP, or GUI acceptance. Full portable workflow remains a required later gate.

### v3.1.0 A8 native probe checkout correction

The initial Windows native probe failed **before Cargo**: default checkout depth 1 omitted the pinned v3.1.0 ancestor (`fatal: Not a valid commit name b99fa929...`). This is a CI checkout error, not evidence of a Rust compilation failure. Pinned a bounded checkout history (`fetch-depth: 20`) to include the upstream base and replay the same compile probe; no runtime dependency download or release occurs.

### v3.1.0 migration slice A9 — full Windows acceptance pipeline source port (draft, NOT RUN)

Reused the **full 1,135-line last-passing v2.14.3 Windows portable workflow** as a v3.1.0 candidate under `.github/config/pdf-tunner-v3-windows-portable.candidate.yml`, not as an active workflow. Pinned the new upstream commit/version, kept all former downloader SHA-256 pins, Windows build/package steps, external dependency checks, backend, OCR, office, WebView2, process containment, window-state and SHA/ZIP gates intact, and removed the automatic v2 push trigger and old push-only ZIP retention clause. The branch preflight now checks the draft's key contracts and presence of its major gates; this does not mean those gates pass on v3.1.0. **Do not run/promote the expensive workflow yet:** the v3 React/backend branding and native policy and the v3 endpoints/gates require reconciliation. Preserve the old stable pipeline. Later migrate this draft to `.github/workflows/`, keep deliberate trigger control and run one full CI only after those checks.

### v3.1.0 migration slice A10 — provisional PDF_Tunner frontend identity

Brought forward the five last-tested v2 PDF_Tunner SVG Git blobs as interim identity (not the pending new blue logo) into `frontend/editor/public/pdf-tunner/`. Adapted **v3.1.0's existing** Logo, BrandMark, logo-asset hooks, HTML title/favicon and PWA manifest, keeping the new v3 i18n preload and frontend component interfaces. The header retains its menu-chevron cue. The source preflight verifies that branded assets and references exist; the desktop TypeScript check validates React compatibility. This is NOT approval of final artwork and does not yet cover all Java/API routes, dynamic onboarding copy or bundled Windows ICO. Replace the provisional SVG and regenerated ICO coherently with the user's approved blue mark before final Windows acceptance, then validate GUI and signing images manually.

### v3.1 A8 Windows probe — separate native compilation from large package inputs

After checkout correction, the Windows `cargo check --locked` reached Tauri's build script but stopped at `glob pattern libs/*.jar path not found or didn't match any files.` This is expected for a **source-only** probe without the bundled Java backend, not a diagnosed Rust compiler error. The probe now passes a Tauri config override with an empty resource list **only within the smoke check**. No placeholder JAR/JRE files are created and the real full Windows acceptance workflow keeps the exact upstream JAR/JLink resource packaging gates. We still require a green rerun before claiming successful Windows Rust typechecking.

### v3.1.0 migration slice A11 — adapt branding QA to new wallet/onboarding APIs and build actual frontend

Updated the previous strict Windows branding QA source to use **v3.1's existing** `desktop/hooks/useWallet.ts` hook, whose `useConfirmedSaaSMode()` gating blocks PAYG billing requests from local/self-hosted mode. Replaced obsolete old-v2 onboarding/sign-in string checks with assertions covering the v3 native portable flag, initially hidden onboarding and sign-in controls. These are still hard failures in future packaged Windows acceptance, not deleted checks. Added an inexpensive actual Vite desktop frontend build to the branch preflight after clean Node 22/npm lockfile install and TypeScript typecheck; checks built HTML and branded SVG/manifest in dist, without packaging Java, WebView2 or OCR. This validates generated frontend assets, not running GUI behavior. Continue keeping Windows full workflow staged/nonactive until runtime gates and final blue artwork are integrated.

### v3.1.0 migration slice A12 — correct duplicate main-window creation and native titles

The v3.1 upstream `src/commands/window.rs` creates **both primary and secondary windows programmatically** from Rust; its base Tauri config intentionally has `app.windows: []`. The provisional v2-style PDF_Tunner overlay mistakenly reintroduced a default main Tauri window while `lib.rs` would call `build_main_window()` again, risking a duplicate `main` label and failed startup. Fixed the overlay to preserve `windows: []`, and changed only the two native builder titles to `PDF_Tunner` when `PDF_TUNNER_PORTABLE_ROOT` is set; official upstream titles remain unchanged for nonportable execution. Both source preflight and strict packaged Windows branding QA now enforce the v3 dynamic window architecture instead of checking `app.windows[0].title`. **Still required:** Windows linking, GUI startup and multi-window behavioral checks. This fix was not covered by the previous cargo check snapshot and must be checked on a newer head before full acceptance.

### v3.1.0 A13 — diagnose generated frontend asset mismatch precisely

The first true Vite desktop build passed under Node 22 (28s) but its post-build PDF_Tunner asset check exited 1 without identifying which assertion failed. Converted that check to a Python verifier that reports missing output, actual HTML title, or manifest name explicitly. Added v3 Rust `commands/window.rs` to rustfmt syntax coverage after the dynamic main-window fix, and corrected the v2 overlay schema path to the v3 workspace's `../../node_modules`. No large Windows packaging run or Release. Re-run the lightweight frontend/source tests and act on the specific dist result rather than weakening the check.

### v3.1.0 migration slice A14 — native backend/API branding without replacing upstream page logic

Ported only approved legacy PDF_Tunner identity values onto official v3 Java `AppConfig` and `settings.yml.template`: app name/nav/fallback, PDF producer/creator and optional certificate organization. Branded v3's API-only landing HTML and existing mobile-transfer HTML with the five same provisional SVGs as the frontend, retaining all **new v3 page JavaScript, endpoints, layout, and official Stirling attribution links** rather than overwriting them with v2 files. Added source copies of the five small SVGs under `app/core/src/main/resources/static/pdf-tunner/` so even backend-only JARs can resolve branded paths without depending on a frontend build. This does **not** activate or disable mobile transfer: the existing feature gates remain unchanged pending the explicit product policy review. The packaged Java JAR, API endpoints, QR behavior and frontend must still pass integration acceptance. No compiled Java or v3 ZIP is claimed at this point.

### v3.1.0 migration slice A15 — root cause of compiled title regression

The native Vite desktop build completed successfully, but the post-build identity gate found `dist/index.html` still titled `Stirling PDF - 30M+ Downloads` despite a branded source `index.html`. Root cause verified in official v3 `prerenderOgPlugin`: it replaces the compiled title using `public/og-metadata.json` with Stirling's SEO home title. The v3 Vite plugin now receives the `desktop` mode explicitly and overrides **only the in-memory manifest home title** to `PDF_Tunner` before generating desktop dist; other upstream SaaS/web builds and generated source SEO manifests remain untouched. Source guard added. The real Vite artifact check remains mandatory (no relaxed assertion).
