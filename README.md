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
In debug mode data received from device during meditation training are saved to the file `EEG_samples.csv` in the Documents folder.
### Release mode
```
flutter build windows
```