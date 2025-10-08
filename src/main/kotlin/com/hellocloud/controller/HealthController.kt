package com.hellocloud.controller

import com.hellocloud.model.HealthResponse
import com.hellocloud.service.CloudMetadataService
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.time.Instant

@RestController
@RequestMapping("/api")
class HealthController(
    private val cloudMetadataService: CloudMetadataService
) {

    @GetMapping("/health")
    fun health(): ResponseEntity<HealthResponse> {
        val cloudInfo = cloudMetadataService.getCloudInfo()
        return ResponseEntity.ok(
            HealthResponse(
                status = "UP",
                timestamp = Instant.now(),
                cloudProvider = cloudInfo.provider,
                region = cloudInfo.region,
                instanceId = cloudInfo.instanceId
            )
        )
    }

    @GetMapping("/hello")
    fun hello(): Map<String, String> {
        val cloudInfo = cloudMetadataService.getCloudInfo()
        return mapOf(
            "message" to "Hello from ${cloudInfo.provider}!",
            "provider" to cloudInfo.provider,
            "region" to (cloudInfo.region ?: "unknown"),
            "version" to "1.0.0"
        )
    }
}

