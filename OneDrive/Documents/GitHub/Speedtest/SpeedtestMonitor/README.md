# Speedtest Monitor Android App

A modern Android app to monitor your Raspberry Pi Speedtest system in real-time.

## Features

✅ **Real-time Speed Monitoring** - Live download, upload, and ping data  
✅ **Performance Indicators** - Color-coded cards based on speed performance  
✅ **Modern Material Design** - Clean, intuitive interface  
✅ **Auto-refresh** - Automatic data updates  
✅ **Offline Support** - Graceful error handling  
✅ **Network Status** - Connection status indicators  

## Screenshots

The app features:
- **Download Speed Card** - Shows current download speed with color coding
- **Upload Speed Card** - Shows current upload speed with color coding  
- **Ping Card** - Shows current ping with color coding
- **Last Test Card** - Shows timestamp of last speed test
- **Status Indicator** - Shows connection status
- **Refresh Button** - Manual refresh of data

## Performance Color Coding

- 🟢 **Green (Excellent)**: Download ≥100 Mbps, Upload ≥10 Mbps, Ping ≤20 ms
- 🟡 **Light Green (Good)**: Download ≥50 Mbps, Upload ≥5 Mbps, Ping ≤50 ms  
- 🟠 **Orange (Warning)**: Download ≥25 Mbps, Upload ≥2 Mbps, Ping ≤100 ms
- 🔴 **Red (Poor)**: Download <25 Mbps, Upload <2 Mbps, Ping >100 ms

## Setup Instructions

### Prerequisites

1. **Raspberry Pi Setup Complete**
   - Run `./setup-pi.sh` on your Pi
   - Run `./api-setup.sh` to enable the API server
   - Ensure the API is running on port 3000

2. **Android Development Environment**
   - Android Studio (latest version)
   - Android SDK 24+ (API level 24)
   - Kotlin support

### Configuration

1. **Update API URL**
   - Open `RetrofitClient.kt`
   - Change `BASE_URL` to your Pi's IP address:
   ```kotlin
   private const val BASE_URL = "http://YOUR_PI_IP:3000/"
   ```

2. **Network Permissions**
   - The app requires internet access to connect to your Pi
   - Ensure your phone and Pi are on the same network

### Building the App

1. **Open in Android Studio**
   ```bash
   # Open the SpeedtestMonitor folder in Android Studio
   ```

2. **Sync Dependencies**
   - Android Studio will automatically sync Gradle dependencies
   - Wait for all dependencies to download

3. **Build and Run**
   - Connect your Android device or start an emulator
   - Click "Run" in Android Studio
   - The app will install and launch

### Manual Build (Command Line)

```bash
cd SpeedtestMonitor
./gradlew assembleDebug
```

The APK will be created at: `app/build/outputs/apk/debug/app-debug.apk`

## API Endpoints Used

The app connects to these Raspberry Pi API endpoints:

- `GET /api/latest` - Latest speed test results
- `GET /api/history` - Historical speed test data
- `GET /api/summary` - Summary statistics
- `GET /api/metrics` - System metrics
- `GET /api/network` - Network quality data
- `GET /api/health` - API health check

## Troubleshooting

### Connection Issues

1. **Check Pi IP Address**
   ```bash
   # On your Pi
   hostname -I
   ```

2. **Verify API is Running**
   ```bash
   # On your Pi
   sudo systemctl status speedtest-api
   ```

3. **Test API Manually**
   ```bash
   # From your phone or computer
   curl http://YOUR_PI_IP:3000/api/health
   ```

4. **Check Firewall**
   - Ensure port 3000 is open on your Pi
   - Check your router's firewall settings

### App Issues

1. **Clear App Data** - If the app shows old data
2. **Check Network** - Ensure phone and Pi are on same network
3. **Restart API** - Restart the API service on your Pi:
   ```bash
   sudo systemctl restart speedtest-api
   ```

## Customization

### Changing Performance Thresholds

Edit the color thresholds in `MainActivity.kt`:

```kotlin
// Download speed colors
val downloadColor = when {
    data.download >= 100 -> R.color.excellent  // Change this
    data.download >= 50 -> R.color.good        // Change this
    data.download >= 25 -> R.color.warning     // Change this
    else -> R.color.poor
}
```

### Adding New Features

The app is built with:
- **MVVM Architecture** - Clean separation of concerns
- **Retrofit** - HTTP API client
- **LiveData** - Reactive data binding
- **Material Design** - Modern UI components

## Security Notes

- The app connects over HTTP (not HTTPS) for simplicity
- For production use, consider:
  - Setting up HTTPS on your Pi
  - Adding API authentication
  - Using a VPN for remote access

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Verify your Pi setup is complete
3. Test the API endpoints manually
4. Check the app logs in Android Studio

## License

This app is part of the Speedtest Monitor project and follows the same license terms. 