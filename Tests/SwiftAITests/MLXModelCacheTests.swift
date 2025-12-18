// MLXModelCacheTests.swift
// SwiftAITests

import Testing
@testable import SwiftAI

#if arch(arm64)
import MLX
import MLXLMCommon
import MLXLLM

@Suite("MLXModelCache Tests")
struct MLXModelCacheTests {

    @Test("Cache stores and retrieves models")
    func testCacheStoreAndRetrieve() async {
        let cache = MLXModelCache()

        // Create a mock cached model
        let mockContainer = createMockModelContainer()
        let capabilities = ModelCapabilities(
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            supportsVision: false,
            contextWindowSize: 2048
        )
        let model = MLXModelCache.CachedModel(
            container: mockContainer,
            capabilities: capabilities,
            weightsSize: .megabytes(500)
        )

        // Store the model
        await cache.set(model, forKey: "test-model")

        // Retrieve the model
        let retrieved = await cache.get("test-model")
        #expect(retrieved != nil)
        #expect(retrieved?.capabilities.supportsTextGeneration == true)
        #expect(retrieved?.weightsSize.megabytes == 500)
    }

    @Test("Cache contains check works correctly")
    func testCacheContains() async {
        let cache = MLXModelCache()

        let mockContainer = createMockModelContainer()
        let capabilities = ModelCapabilities(
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            supportsVision: false,
            contextWindowSize: 2048
        )
        let model = MLXModelCache.CachedModel(
            container: mockContainer,
            capabilities: capabilities,
            weightsSize: .megabytes(500)
        )

        // Initially not cached
        #expect(await cache.contains("test-model") == false)

        // Store the model
        await cache.set(model, forKey: "test-model")

        // Now it should be cached
        #expect(await cache.contains("test-model") == true)
    }

    @Test("Cache remove works correctly")
    func testCacheRemove() async {
        let cache = MLXModelCache()

        let mockContainer = createMockModelContainer()
        let capabilities = ModelCapabilities(
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            supportsVision: false,
            contextWindowSize: 2048
        )
        let model = MLXModelCache.CachedModel(
            container: mockContainer,
            capabilities: capabilities,
            weightsSize: .megabytes(500)
        )

        // Store the model
        await cache.set(model, forKey: "test-model")
        #expect(await cache.contains("test-model") == true)

        // Remove the model
        await cache.remove("test-model")
        #expect(await cache.contains("test-model") == false)
    }

    @Test("Cache removeAll clears all models")
    func testCacheRemoveAll() async {
        let cache = MLXModelCache()

        let mockContainer = createMockModelContainer()
        let capabilities = ModelCapabilities(
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            supportsVision: false,
            contextWindowSize: 2048
        )

        // Store multiple models
        for i in 1...3 {
            let model = MLXModelCache.CachedModel(
                container: mockContainer,
                capabilities: capabilities,
                weightsSize: .megabytes(500)
            )
            await cache.set(model, forKey: "test-model-\(i)")
        }

        let statsBefore = await cache.cacheStats()
        #expect(statsBefore.cachedModelCount == 3)

        // Remove all
        await cache.removeAll()

        let statsAfter = await cache.cacheStats()
        #expect(statsAfter.cachedModelCount == 0)
        #expect(statsAfter.totalMemoryUsage.bytes == 0)
    }

    @Test("Cache stats reflect current state")
    func testCacheStats() async {
        let cache = MLXModelCache()

        let mockContainer = createMockModelContainer()
        let capabilities = ModelCapabilities(
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            supportsVision: false,
            contextWindowSize: 2048
        )

        // Store models with different sizes
        let model1 = MLXModelCache.CachedModel(
            container: mockContainer,
            capabilities: capabilities,
            weightsSize: .megabytes(500)
        )
        let model2 = MLXModelCache.CachedModel(
            container: mockContainer,
            capabilities: capabilities,
            weightsSize: .gigabytes(1)
        )

        await cache.set(model1, forKey: "model-1")
        await cache.set(model2, forKey: "model-2")

        let stats = await cache.cacheStats()
        #expect(stats.cachedModelCount == 2)
        #expect(stats.totalMemoryUsage.megabytes >= 1500) // 500MB + 1GB
        #expect(stats.modelIds.contains("model-1"))
        #expect(stats.modelIds.contains("model-2"))
    }

    @Test("Current model tracking works")
    func testCurrentModelTracking() async {
        let cache = MLXModelCache()

        // Initially no current model
        #expect(await cache.getCurrentModelId() == nil)

        // Set current model
        await cache.setCurrentModel("test-model")
        #expect(await cache.getCurrentModelId() == "test-model")

        // Clear current model
        await cache.setCurrentModel(nil)
        #expect(await cache.getCurrentModelId() == nil)
    }

    // MARK: - Helpers

    private func createMockModelContainer() -> ModelContainer {
        // Create a minimal mock container
        // In practice, this would need actual MLX model initialization
        // For unit tests, we can use a placeholder
        let configuration = ModelConfiguration.llama3_2_1B
        // Note: This is a simplified mock. In production tests, you'd need
        // proper model initialization or mocking frameworks
        return ModelContainer(configuration: configuration)
    }
}

#else
// Non-ARM64 platforms - provide empty test suite
@Suite("MLXModelCache Tests (Skipped on non-ARM64)")
struct MLXModelCacheTests {
    @Test("MLX tests skipped on non-ARM64 platforms")
    func testSkipped() {
        // This test always passes but indicates tests were skipped
        #expect(true)
    }
}
#endif
