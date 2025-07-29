package com.speedtest.monitor

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import okhttp3.ResponseBody
import retrofit2.Call
import retrofit2.Callback
import retrofit2.Response

class SpeedtestViewModel : ViewModel() {
    private val _speedtestData = MutableLiveData<SpeedtestData>()
    val speedtestData: LiveData<SpeedtestData> = _speedtestData

    private val _isLoading = MutableLiveData<Boolean>()
    val isLoading: LiveData<Boolean> = _isLoading

    private val _error = MutableLiveData<String?>()
    val error: LiveData<String?> = _error

    private val _autoUpdateOutput = MutableLiveData<String?>()
    val autoUpdateOutput: LiveData<String?> = _autoUpdateOutput

    fun loadSpeedtestData(apiService: SpeedtestApiService) {
        _isLoading.value = true
        _error.value = null
        apiService.getLatestSpeedtest().enqueue(object : Callback<ApiResponse> {
            override fun onResponse(call: Call<ApiResponse>, response: Response<ApiResponse>) {
                _isLoading.value = false
                if (response.isSuccessful) {
                    val apiResponse = response.body()
                    if (apiResponse?.success == true) {
                        val data = apiResponse.data
                        _speedtestData.value = SpeedtestData(
                            download = data.download,
                            upload = data.upload,
                            ping = data.ping,
                            timestamp = data.timestamp
                        )
                    } else {
                        _error.value = "No data available"
                    }
                } else {
                    _error.value = "Server error: ${response.code()}"
                }
            }
            override fun onFailure(call: Call<ApiResponse>, t: Throwable) {
                _isLoading.value = false
                _error.value = "Connection failed: ${t.message}"
            }
        })
    }

    fun runTestNow(apiService: SpeedtestApiService, onComplete: (Boolean, String?) -> Unit) {
        _isLoading.value = true
        apiService.runTestNow().enqueue(object : Callback<RunTestResponse> {
            override fun onResponse(call: Call<RunTestResponse>, response: Response<RunTestResponse>) {
                _isLoading.value = false
                if (response.isSuccessful && response.body()?.success == true) {
                    response.body()?.data?.let { _speedtestData.value = it }
                    onComplete(true, null)
                } else {
                    onComplete(false, response.body()?.error ?: "Failed to run test")
                }
            }
            override fun onFailure(call: Call<RunTestResponse>, t: Throwable) {
                _isLoading.value = false
                onComplete(false, t.message)
            }
        })
    }

    fun exportPdf(apiService: SpeedtestApiService, onComplete: (ResponseBody?) -> Unit) {
        apiService.exportPdf().enqueue(object : Callback<ResponseBody> {
            override fun onResponse(call: Call<ResponseBody>, response: Response<ResponseBody>) {
                if (response.isSuccessful) {
                    onComplete(response.body())
                } else {
                    onComplete(null)
                }
            }
            override fun onFailure(call: Call<ResponseBody>, t: Throwable) {
                onComplete(null)
            }
        })
    }

    fun autoUpdate(apiService: SpeedtestApiService, onComplete: (Boolean, String?) -> Unit) {
        _autoUpdateOutput.value = null
        apiService.autoUpdate().enqueue(object : Callback<AutoUpdateResponse> {
            override fun onResponse(call: Call<AutoUpdateResponse>, response: Response<AutoUpdateResponse>) {
                if (response.isSuccessful && response.body()?.success == true) {
                    _autoUpdateOutput.value = response.body()?.output
                    onComplete(true, response.body()?.output)
                } else {
                    onComplete(false, response.body()?.error ?: "Auto-update failed")
                }
            }
            override fun onFailure(call: Call<AutoUpdateResponse>, t: Throwable) {
                onComplete(false, t.message)
            }
        })
    }
} 