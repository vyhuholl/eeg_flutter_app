# eeg_flutter_app
An interface for the [EasyEEG BCI](https://labdata.ru/news/easyeeg-bci) device. Shows your focus and relaxation levels. Currently works only on Windows.
## Build
### Debug mode
```bash
flutter build windows --debug
```
During each meditation training, all data received from device is saved as CSV in the Documents/eeg_samples folder.
### Release mode
```
flutter build windows
```