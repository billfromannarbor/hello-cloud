package com.hellocloud.model

import java.time.Instant

data class HealthResponse(
    val status: String,
    val timestamp: Instant,
    val cloudProvider: String,
    val region: String?,
    val instanceId: String?
)

data class CloudInfo(
    val provider: String,
    val region: String?,
    val instanceId: String?,
    val availabilityZone: String?
)

