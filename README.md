# SDHCI_driver_for_Kolibrios

Driver for SD host controller on Kolibri OS

## WARNING!!!
The driver is being developed and tested for the controller version 2.0 (integrated into the FCH Bolton D3). On controllers of another version or another manufacturer, it may work unstable and may lead to equipment failure.

## Information

Version controller:
- 1.0 - no supported
- 2.0 - Supported 
- 3.0 - no supported
- 4.0 - no supported

DMA modes:
- no-DMA - not supported
- SDMA   - Supported
- ADMA1  - not supported
- ADMA2 32bit - not supported
- ADMA2 64bit - not supported


Version OS: 
* rev 9897

Bus protocol:
- SD Bus protocol - Supported
- UHS-II Bus protocol - no supported
- PCIe/NVMe Bus protocol - no supported

## TODO:
- ~~инициализация контроллера, вывод информации об контроллере~~
- ~~Установка изначальных значений для работы контроллера~~
- ~~регистрация обработчика прерываний~~
- ~~документирование и реализация команд контроллера~~
- ~~написание алгоритма инициализации SD карт~~
- ~~переписать обнаружение карт при инициализации контроллера~~
- написание алгоритма инициализации SDIO карт
- написание алгоритма инициализации MMC карт
- написание функций передачи блоков через SDMA и ADMA и без применения DMA
- ~~реализация функций card_init и card_destryct~~
- ~~Получение базовых данных о карте(CID, CSD, RCA)~~
- ~~реализовать функции смены частоты~~
- ~~реализовать функции переключения шины SD в 4bit режим и обратно в 1bit режим~~
- реализовать функции смены питания на 1.8V
- ~~реализация функций обработки сообщений контроллера~~
- реализация функций SDIO и их экспорт для драйверов и прикладного ПО
- ~~реализация встроенного драйвера на SD карты памяти~~
- ~~получение объёма карты в секторах(512 байт)~~
