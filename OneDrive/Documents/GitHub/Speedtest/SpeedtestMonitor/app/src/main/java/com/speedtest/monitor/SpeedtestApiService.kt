package com.speedtest.monitor

import okhttp3.ResponseBody
import retrofit2.Call
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Query
import retrofit2.http.Streaming

interface SpeedtestApiService {
    @GET("speedtest/api/latest")
    fun getLatestSpeedtest(): Call<ApiResponse>

    @GET("speedtest/api/history")
    fun getSpeedtestHistory(@Query("limit") limit: Int = 100): Call<HistoryResponse>

    @GET("speedtest/api/summary")
    fun getSummary(): Call<SummaryResponse>

    @GET("speedtest/api/metrics")
    fun getSystemMetrics(): Call<MetricsResponse>

    @GET("speedtest/api/network")
    fun getNetworkQuality(): Call<NetworkResponse>

    @GET("speedtest/api/health")
    fun getHealth(): Call<HealthResponse>

    @POST("speedtest/api/run-test")
    fun runTestNow(): Call<RunTestResponse>

    @Streaming
    @GET("speedtest/api/export-pdf")
    fun exportPdf(): Call<ResponseBody>

    @POST("speedtest/api/auto-update")
    fun autoUpdate(): Call<AutoUpdateResponse>
}

data class RunTestResponse(
    val success: Boolean,
    val data: SpeedtestData?,
    val error: String? = null
)

data class AutoUpdateResponse(
    val success: Boolean,
    val output: String?,
    val error: String? = null
)
// Data classes for API responses
data class ApiResponse(
    val success: Boolean,
    val data: SpeedtestData,
    val timestamp: String
)

data class SpeedtestData(
    val timestamp: String,
    val ping: Double,
    val download: Double,
    val upload: Double
)

data class HistoryResponse(
    val success: Boolean,
    val data: List<SpeedtestData>,
    val count: Int,
    val timestamp: String
)

data class SummaryResponse(
    val success: Boolean,
    val data: SummaryData,
    val timestamp: String
)

data class SummaryData(
    val total_tests: Int,
    val latest_test: SpeedtestData,
    val averages: Averages,
    val best: BestWorst,
    val worst: BestWorst
)

data class Averages(
    val download: Double,
    val upload: Double,
    val ping: Double
)

data class BestWorst(
    val download: Double,
    val upload: Double,
    val ping: Double
)

data class MetricsResponse(
    val success: Boolean,
    val data: MetricsData,
    val timestamp: String
)

data class MetricsData(
    val timestamp: String,
    val system: SystemMetrics
)

data class SystemMetrics(
    val cpu_usage: Double,
    val memory_usage: Double,
    val disk_usage: Double,
    val temperature: String,
    val uptime: String
)

data class NetworkResponse(
    val success: Boolean,
    val data: NetworkData,
    val timestamp: String
)

data class NetworkData(
    val timestamp: String,
    val dns_response_time: Double,
    val http_response_time: Double,
    val network_quality: String
)

data class HealthResponse(
    val status: String,
    val timestamp: String,
    val uptime: Double
) 