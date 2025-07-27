# eeg_flutter_app
An interface for the [EasyEEG BCI](https://labdata.ru/news/easyeeg-bci) device. Shows your focus and relaxation levels. Currently works only on Windows.
## Build
### Debug mode
```bash
flutter build windows --debug
```
### Release mode
```
flutter build windows
```
## Logs
Logs locations:

App logs are stored in the C:\Users\{username}\AppData\Local\eeg_flutter_app\logs.log file.

Raw data received from device are stored in the "EEG.csv" (for EEG values) and "EEG_bands.csv" (for brainwave bands values) files in the application directory.

During meditation training, processed data (EEG bands ratios — alpha/theta, beta/theta and so on) are also recorded and stored as archived CSV files in the "eeg_samples" folder at the Documents directory. For each meditation training, a new file is created.