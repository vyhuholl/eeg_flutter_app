# eeg_flutter_app
An interface for the [EasyEEG BCI](https://labdata.ru/news/easyeeg-bci) device. Shows your focus and relaxation levels. Currently works only on Windows.
## Cloning
```bash
git lfs install
git clone https://github.com/vyhuholl/eeg_flutter_app.git
```
## Build
### Debug mode
```bash
flutter build windows --debug
```
In debug mode app saves the data received from device to CSV files. Original data from device is stored in the "C:\Users\username\AppData\Local\eeg_flutter_app" folder, processed data from the app --- in the Documents folder.
### Release mode
```
flutter build windows
```