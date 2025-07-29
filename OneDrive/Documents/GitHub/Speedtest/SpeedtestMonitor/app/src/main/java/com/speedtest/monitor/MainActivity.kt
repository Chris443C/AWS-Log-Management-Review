package com.speedtest.monitor

import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.ViewModelProvider
import com.google.android.material.card.MaterialCardView
import com.google.android.material.floatingactionbutton.FloatingActionButton
import com.google.android.material.progressindicator.CircularProgressIndicator
import com.google.android.material.textview.MaterialTextView
import retrofit2.Call
import retrofit2.Callback
import retrofit2.Response
import android.os.Environment
import android.content.Intent
import android.net.Uri
import java.io.File
import java.io.FileOutputStream

class MainActivity : AppCompatActivity() {
    
    private lateinit var viewModel: SpeedtestViewModel
    private lateinit var apiService: SpeedtestApiService
    
    // UI Components
    private lateinit var downloadSpeedCard: MaterialCardView
    private lateinit var uploadSpeedCard: MaterialCardView
    private lateinit var pingCard: MaterialCardView
    private lateinit var lastTestCard: MaterialCardView
    
    private lateinit var downloadSpeedText: MaterialTextView
    private lateinit var uploadSpeedText: MaterialTextView
    private lateinit var pingText: MaterialTextView
    private lateinit var lastTestText: MaterialTextView
    private lateinit var statusText: MaterialTextView
    
    private lateinit var progressIndicator: CircularProgressIndicator
    private lateinit var refreshButton: FloatingActionButton
    private lateinit var testNowButton: FloatingActionButton
    private lateinit var pdfButton: FloatingActionButton
    private lateinit var updateButton: FloatingActionButton
    private lateinit var darkModeButton: FloatingActionButton
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        initializeViews()
        setupViewModel()
        setupApiService()
        setupRefreshButton()
        setupNewButtons()
        
        // Load initial data
        loadSpeedtestData()
    }
    
    private fun initializeViews() {
        downloadSpeedCard = findViewById(R.id.downloadSpeedCard)
        uploadSpeedCard = findViewById(R.id.uploadSpeedCard)
        pingCard = findViewById(R.id.pingCard)
        lastTestCard = findViewById(R.id.lastTestCard)
        
        downloadSpeedText = findViewById(R.id.downloadSpeedText)
        uploadSpeedText = findViewById(R.id.uploadSpeedText)
        pingText = findViewById(R.id.pingText)
        lastTestText = findViewById(R.id.lastTestText)
        statusText = findViewById(R.id.statusText)
        
        progressIndicator = findViewById(R.id.progressIndicator)
        refreshButton = findViewById(R.id.refreshButton)
        testNowButton = findViewById(R.id.testNowButton)
        pdfButton = findViewById(R.id.pdfButton)
        updateButton = findViewById(R.id.updateButton)
        darkModeButton = findViewById(R.id.darkModeButton)
    }
    
    private fun setupViewModel() {
        viewModel = ViewModelProvider(this)[SpeedtestViewModel::class.java]
        
        viewModel.speedtestData.observe(this) { data ->
            updateUI(data)
        }
        
        viewModel.isLoading.observe(this) { isLoading ->
            progressIndicator.visibility = if (isLoading) View.VISIBLE else View.GONE
        }
        
        viewModel.error.observe(this) { error ->
            error?.let {
                Toast.makeText(this, "Error: $it", Toast.LENGTH_LONG).show()
                statusText.text = "Connection Error"
                statusText.setTextColor(getColor(R.color.error))
            }
        }
    }
    
    private fun setupApiService() {
        apiService = RetrofitClient.createService()
    }
    
    private fun setupRefreshButton() {
        refreshButton.setOnClickListener {
            loadSpeedtestData()
        }
    }

    private fun setupNewButtons() {
        testNowButton.setOnClickListener {
            viewModel.runTestNow(apiService) { success, error ->
                if (success) Toast.makeText(this, "Speedtest complete!", Toast.LENGTH_SHORT).show()
                else Toast.makeText(this, "Test failed: $error", Toast.LENGTH_LONG).show()
            }
        }
        pdfButton.setOnClickListener {
            viewModel.exportPdf(apiService) { body ->
                if (body != null) {
                    val file = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "speedtest.pdf")
                    val fos = FileOutputStream(file)
                    fos.write(body.bytes())
                    fos.close()
                    val intent = Intent(Intent.ACTION_VIEW)
                    intent.setDataAndType(Uri.fromFile(file), "application/pdf")
                    intent.flags = Intent.FLAG_ACTIVITY_NO_HISTORY
                    startActivity(intent)
                } else {
                    Toast.makeText(this, "PDF export failed!", Toast.LENGTH_LONG).show()
                }
            }
        }
        updateButton.setOnClickListener {
            viewModel.autoUpdate(apiService) { success, output ->
                if (success) Toast.makeText(this, "Update complete!\n$output", Toast.LENGTH_LONG).show()
                else Toast.makeText(this, "Update failed: $output", Toast.LENGTH_LONG).show()
            }
        }
        darkModeButton.setOnClickListener {
            // Toggle dark mode (implement as needed)
        }
    }
    
    private fun loadSpeedtestData() {
        viewModel.loadSpeedtestData(apiService)
    }
    
    private fun updateUI(data: SpeedtestData?) {
        data?.let {
            // Update speed values
            downloadSpeedText.text = "${it.download} Mbps"
            uploadSpeedText.text = "${it.upload} Mbps"
            pingText.text = "${it.ping} ms"
            
            // Update last test time
            val timestamp = it.timestamp
            lastTestText.text = timestamp
            
            // Update status
            statusText.text = "Connected"
            statusText.setTextColor(getColor(R.color.success))
            
            // Update card colors based on performance
            updateCardColors(it)
        }
    }
    
    private fun updateCardColors(data: SpeedtestData) {
        // Download speed colors
        val downloadColor = when {
            data.download >= 100 -> R.color.excellent
            data.download >= 50 -> R.color.good
            data.download >= 25 -> R.color.warning
            else -> R.color.poor
        }
        downloadSpeedCard.setCardBackgroundColor(getColor(downloadColor))
        
        // Upload speed colors
        val uploadColor = when {
            data.upload >= 10 -> R.color.excellent
            data.upload >= 5 -> R.color.good
            data.upload >= 2 -> R.color.warning
            else -> R.color.poor
        }
        uploadSpeedCard.setCardBackgroundColor(getColor(uploadColor))
        
        // Ping colors
        val pingColor = when {
            data.ping <= 20 -> R.color.excellent
            data.ping <= 50 -> R.color.good
            data.ping <= 100 -> R.color.warning
            else -> R.color.poor
        }
        pingCard.setCardBackgroundColor(getColor(pingColor))
    }
} 