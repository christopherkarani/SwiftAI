# SwiftAI Cleanup Plan: Removing Unused Stub Files

## Objective

Remove unused stub files from removed phases (Foundation Models provider and Macros) while ensuring no breaking changes to the codebase.

## Executive Summary

After analysis, the following cleanup actions are required:

| File/Directory | Action | Reason |
|----------------|--------|--------|
| `Sources/SwiftAIMacros/` (entire directory) | DELETE | Not in Package.swift, only stubs |
| `Sources/SwiftAI/Providers/FoundationModels/FoundationModelsProvider.swift` | DELETE | 9-line stub, no references |
| `Sources/SwiftAI/Providers/FoundationModels/FMSessionManager.swift` | DELETE | 9-line stub, no references |
| `Sources/SwiftAI/Providers/FoundationModels/FMConfiguration.swift` | KEEP | Well-documented, may be useful for future FM support |
| `Sources/SwiftAI/Core/Streaming/StreamBuffer.swift` | DELETE | 9-line stub, no references |
| `ModelIdentifier.foundationModels` | KEEP | Used in ModelManager for validation |
| `ProviderType.foundationModels` | KEEP | Part of public API enum |

## Prerequisites

- [ ] Ensure `swift build` passes before cleanup
- [ ] Create git commit of current state (safety checkpoint)
- [ ] Run `swift test` to establish baseline

---

## Phase 1: Verification (Read-Only Analysis)

### Task 1.1: Confirm Package.swift State
**Status**: VERIFIED

Package.swift does NOT contain:
- SwiftAIMacros target
- swift-syntax dependency reference in SwiftAI target
- Any macro-related dependencies

Package.swift contains swift-syntax as a dependency but it is NOT used by the SwiftAI target.

**Decision**: The macro directory can be safely deleted.

### Task 1.2: Check Foundation Models References
**Status**: VERIFIED

References to `foundationModels` in source code:
1. `ModelIdentifier.swift` - Enum case `.foundationModels` (KEEP - public API)
2. `ForwardDeclarations.swift` - `ProviderType.foundationModels` (KEEP - public API)
3. `ModelManager.swift` - Validation check for Foundation Models (KEEP - needed for validation)

References to stub files:
- `FoundationModelsProvider.swift` - Only self-reference (DELETE)
- `FMSessionManager.swift` - Only self-reference (DELETE)
- `FMConfiguration.swift` - Self-contained with full implementation (EVALUATE)

### Task 1.3: Check Macro References
**Status**: VERIFIED

No references to macros in `Sources/SwiftAI/`:
- No `import SwiftAIMacros`
- No `@Generable` usage
- No `@Guide` usage
- No `GenerableMacro` or `GuideMacro` references

**Decision**: The entire `Sources/SwiftAIMacros/` directory can be safely deleted.

### Task 1.4: Check StreamBuffer References
**Status**: VERIFIED

References to `StreamBuffer`:
- `SwiftAI.swift` line 37 - Comment only (TODO list)
- `StreamBuffer.swift` - Only self-reference (stub file)

**Decision**: The `StreamBuffer.swift` stub can be safely deleted.

---

## Phase 2: File Deletions

### Task 2.1: Delete SwiftAIMacros Directory
**Files to delete**:
```
Sources/SwiftAIMacros/
  SwiftAIMacrosPlugin.swift (15 lines - stub)
  GenerableMacro.swift (11 lines - stub)
  GuideMacro.swift (11 lines - stub)
```

**Command**:
```bash
rm -rf /Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAIMacros
```

**Verification**:
- [ ] Directory no longer exists
- [ ] `swift build` passes

### Task 2.2: Delete Foundation Models Stub Files
**Files to delete**:
```
Sources/SwiftAI/Providers/FoundationModels/FoundationModelsProvider.swift (9 lines - stub)
Sources/SwiftAI/Providers/FoundationModels/FMSessionManager.swift (9 lines - stub)
```

**Files to KEEP**:
```
Sources/SwiftAI/Providers/FoundationModels/FMConfiguration.swift (276 lines - FULL IMPLEMENTATION)
```

**Rationale for keeping FMConfiguration.swift**:
- Contains 276 lines of well-documented, fully implemented code
- Provides `FMConfiguration` struct with fluent API
- Uses `#if canImport(FoundationModels)` for platform safety
- Will be useful when Foundation Models support is added (iOS 26+)
- Has no compile-time cost on platforms without Foundation Models

**Commands**:
```bash
rm /Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAI/Providers/FoundationModels/FoundationModelsProvider.swift
rm /Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAI/Providers/FoundationModels/FMSessionManager.swift
```

**Verification**:
- [ ] Stub files deleted
- [ ] FMConfiguration.swift still exists
- [ ] `swift build` passes

### Task 2.3: Delete StreamBuffer Stub
**File to delete**:
```
Sources/SwiftAI/Core/Streaming/StreamBuffer.swift (9 lines - stub)
```

**Command**:
```bash
rm /Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAI/Core/Streaming/StreamBuffer.swift
```

**Verification**:
- [ ] File deleted
- [ ] `swift build` passes

---

## Phase 3: Code Updates

### Task 3.1: Update SwiftAI.swift Comments
**File**: `Sources/SwiftAI/SwiftAI.swift`

Update the TODO comments to remove references to deleted files:

**Line 37** - Remove StreamBuffer reference:
```swift
// Before:
// - StreamBuffer

// After:
// (delete this line entirely)
```

**Line 48** - Remove FoundationModelsProvider reference:
```swift
// Before:
// - FoundationModelsProvider

// After:
// - FoundationModelsProvider (iOS 26+ - not yet implemented)
```

**Verification**:
- [ ] Comments updated
- [ ] `swift build` passes

### Task 3.2: Evaluate swift-syntax Dependency
**File**: `Package.swift`

The swift-syntax dependency is currently declared but not used by the SwiftAI target.

**Analysis**:
```swift
// Current state - dependency declared but not used in SwiftAI target
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "509.0.0"),
],
targets: [
    .target(
        name: "SwiftAI",
        dependencies: [
            // swift-syntax NOT listed here
        ]
    ),
]
```

**Decision**: REMOVE the swift-syntax dependency since macros are removed.

**Change**:
```swift
// Remove this line from dependencies array:
.package(url: "https://github.com/swiftlang/swift-syntax.git", from: "509.0.0"),
```

**Verification**:
- [ ] Dependency removed from Package.swift
- [ ] `swift package resolve` succeeds
- [ ] `swift build` passes

---

## Phase 4: Documentation Updates

### Task 4.1: Update Implementation Plan
**File**: `.claude/artifacts/planning/implementation-plan.md`

Add note that Foundation Models provider phase is deferred to post-iOS 26 release.

### Task 4.2: Update Provider-Implementer Agent
**File**: `.claude/agents/provider-implementer.md`

Update references to indicate Foundation Models provider is planned but not implemented.

---

## Verification Checklist

After all cleanup tasks:

- [ ] `swift build` passes without errors
- [ ] `swift build` passes without warnings
- [ ] `swift test` passes
- [ ] No orphaned file references in codebase
- [ ] Git status shows expected deletions

### Files Expected to be Deleted (5 files)
1. `Sources/SwiftAIMacros/SwiftAIMacrosPlugin.swift`
2. `Sources/SwiftAIMacros/GenerableMacro.swift`
3. `Sources/SwiftAIMacros/GuideMacro.swift`
4. `Sources/SwiftAI/Providers/FoundationModels/FoundationModelsProvider.swift`
5. `Sources/SwiftAI/Providers/FoundationModels/FMSessionManager.swift`
6. `Sources/SwiftAI/Core/Streaming/StreamBuffer.swift`

### Files Expected to be Modified (2 files)
1. `Sources/SwiftAI/SwiftAI.swift` - Comment updates
2. `Package.swift` - Remove swift-syntax dependency

### Files Expected to be KEPT
1. `Sources/SwiftAI/Providers/FoundationModels/FMConfiguration.swift` - Full implementation, useful for future
2. `Sources/SwiftAI/Core/Types/ModelIdentifier.swift` - Keep `.foundationModels` case
3. `Sources/SwiftAI/Core/Types/ForwardDeclarations.swift` - Keep `ProviderType.foundationModels`

---

## Risks and Mitigations

### Risk 1: Breaking Changes to Public API
**Mitigation**:
- Keep `ModelIdentifier.foundationModels` enum case (part of public API)
- Keep `ProviderType.foundationModels` enum case (part of public API)
- Keep `FMConfiguration` for future use

### Risk 2: Future Foundation Models Implementation
**Mitigation**:
- Keep FMConfiguration.swift which has full implementation
- Keep enum cases for future extensibility
- Document that FM provider is deferred, not abandoned

### Risk 3: Accidental Deletion of Working Code
**Mitigation**:
- Create git commit before cleanup
- Verify each deletion individually
- Run build after each phase

---

## Execution Order

1. **Pre-flight**: Run `swift build` and `swift test`, create git checkpoint
2. **Phase 2.1**: Delete SwiftAIMacros directory
3. **Phase 2.2**: Delete FM stub files (keep FMConfiguration.swift)
4. **Phase 2.3**: Delete StreamBuffer.swift stub
5. **Phase 3.1**: Update SwiftAI.swift comments
6. **Phase 3.2**: Remove swift-syntax dependency from Package.swift
7. **Post-flight**: Run `swift build` and `swift test`
8. **Commit**: Create cleanup commit with descriptive message

---

## Post-Cleanup Directory Structure

After cleanup, the FoundationModels directory will contain only:
```
Sources/SwiftAI/Providers/FoundationModels/
  FMConfiguration.swift  (KEPT - full implementation)
```

The Streaming directory will contain:
```
Sources/SwiftAI/Core/Streaming/
  GenerationChunk.swift
  GenerationStream.swift
  (StreamBuffer.swift DELETED)
```

The SwiftAIMacros directory will be completely removed.

---

## Notes for Implementers

1. **FMConfiguration Decision**: The FMConfiguration.swift file contains 276 lines of fully implemented, well-documented code. It uses `#if canImport(FoundationModels)` to compile safely on all platforms. This is valuable infrastructure for when iOS 26 Foundation Models support is added.

2. **Public API Stability**: The `ModelIdentifier.foundationModels` and `ProviderType.foundationModels` enum cases are part of the public API. Removing them would be a breaking change. Keep them as placeholders for future implementation.

3. **ModelManager Integration**: The ModelManager already handles `.foundationModels` by throwing an appropriate error ("Foundation Models are system-managed and cannot be downloaded"). This is correct behavior that should remain.
