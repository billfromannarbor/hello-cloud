package com.hellocloud.service

import com.hellocloud.model.CloudInfo
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.net.HttpURLConnection
import java.net.URL

@Service
class CloudMetadataService {
    
    private val logger = LoggerFactory.getLogger(CloudMetadataService::class.java)
    private var cachedCloudInfo: CloudInfo? = null
    
    fun getCloudInfo(): CloudInfo {
        if (cachedCloudInfo != null) {
            return cachedCloudInfo!!
        }
        
        val cloudInfo = detectCloudProvider()
        cachedCloudInfo = cloudInfo
        return cloudInfo
    }
    
    private fun detectCloudProvider(): CloudInfo {
        // Try AWS first
        try {
            val awsInfo = tryAWS()
            if (awsInfo != null) {
                logger.info("Detected AWS cloud environment")
                return awsInfo
            }
        } catch (e: Exception) {
            logger.debug("Not running on AWS: ${e.message}")
        }
        
        // Try GCP
        try {
            val gcpInfo = tryGCP()
            if (gcpInfo != null) {
                logger.info("Detected GCP cloud environment")
                return gcpInfo
            }
        } catch (e: Exception) {
            logger.debug("Not running on GCP: ${e.message}")
        }
        
        // Default to local/unknown
        logger.info("Running in local/unknown environment")
        return CloudInfo(
            provider = "LOCAL",
            region = System.getenv("REGION"),
            instanceId = null,
            availabilityZone = null
        )
    }
    
    private fun tryAWS(): CloudInfo? {
        val metadataUrl = "http://169.254.169.254/latest/meta-data/"
        val tokenUrl = "http://169.254.169.254/latest/api/token"
        
        try {
            // Get IMDSv2 token
            val token = getMetadata(tokenUrl, "PUT", mapOf("X-aws-ec2-metadata-token-ttl-seconds" to "21600"))
            
            val headers = if (token != null) {
                mapOf("X-aws-ec2-metadata-token" to token)
            } else {
                emptyMap()
            }
            
            val instanceId = getMetadata("${metadataUrl}instance-id", headers = headers)
            val region = getMetadata("${metadataUrl}placement/region", headers = headers)
            val az = getMetadata("${metadataUrl}placement/availability-zone", headers = headers)
            
            if (instanceId != null || region != null) {
                return CloudInfo(
                    provider = "AWS",
                    region = region,
                    instanceId = instanceId,
                    availabilityZone = az
                )
            }
        } catch (e: Exception) {
            logger.debug("Failed to retrieve AWS metadata: ${e.message}")
        }
        
        return null
    }
    
    private fun tryGCP(): CloudInfo? {
        val metadataUrl = "http://metadata.google.internal/computeMetadata/v1/"
        val headers = mapOf("Metadata-Flavor" to "Google")
        
        try {
            val instanceId = getMetadata("${metadataUrl}instance/id", headers = headers)
            val zone = getMetadata("${metadataUrl}instance/zone", headers = headers)
            
            // Extract region from zone (format: projects/PROJECT_NUMBER/zones/ZONE)
            val region = zone?.split("/")?.lastOrNull()?.substringBeforeLast("-")
            
            if (instanceId != null || zone != null) {
                return CloudInfo(
                    provider = "GCP",
                    region = region,
                    instanceId = instanceId,
                    availabilityZone = zone?.split("/")?.lastOrNull()
                )
            }
        } catch (e: Exception) {
            logger.debug("Failed to retrieve GCP metadata: ${e.message}")
        }
        
        return null
    }
    
    private fun getMetadata(
        urlString: String,
        method: String = "GET",
        headers: Map<String, String> = emptyMap()
    ): String? {
        return try {
            val url = URL(urlString)
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = method
            connection.connectTimeout = 2000
            connection.readTimeout = 2000
            
            headers.forEach { (key, value) ->
                connection.setRequestProperty(key, value)
            }
            
            if (connection.responseCode == 200) {
                connection.inputStream.bufferedReader().use { it.readText() }
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }
}

