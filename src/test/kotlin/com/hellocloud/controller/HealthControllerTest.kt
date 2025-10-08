package com.hellocloud.controller

import com.hellocloud.model.CloudInfo
import com.hellocloud.service.CloudMetadataService
import io.mockk.every
import io.mockk.mockk
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*

@WebMvcTest(HealthController::class)
class HealthControllerTest {

    @Autowired
    private lateinit var mockMvc: MockMvc

    @TestConfiguration
    class TestConfig {
        @Bean
        fun cloudMetadataService(): CloudMetadataService {
            val service = mockk<CloudMetadataService>()
            every { service.getCloudInfo() } returns CloudInfo(
                provider = "LOCAL",
                region = "local",
                instanceId = "test-instance",
                availabilityZone = "local-az"
            )
            return service
        }
    }

    @Test
    fun `health endpoint should return OK`() {
        mockMvc.perform(get("/api/health"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("UP"))
            .andExpect(jsonPath("$.cloudProvider").value("LOCAL"))
    }

    @Test
    fun `hello endpoint should return greeting`() {
        mockMvc.perform(get("/api/hello"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.message").value("Hello from LOCAL!"))
            .andExpect(jsonPath("$.provider").value("LOCAL"))
            .andExpect(jsonPath("$.version").exists())
    }
}

